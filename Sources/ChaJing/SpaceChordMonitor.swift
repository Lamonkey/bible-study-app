import AppKit
import CoreGraphics

/// Implements the "hold Space, press P" chord system-wide with a CGEvent tap.
///
/// Space is a normal typing key, so the tap has to decide whether a Space keyDown is
/// the start of the chord or ordinary typing:
///   * Space keyDown is swallowed and held for `holdWindow` seconds.
///   * P pressed while Space is still down  -> chord fires, both keys are swallowed.
///   * Any other key, Space keyUp, or the timer -> the Space is re-posted so the app in
///     front receives it (followed by the other key, in order). Typing feels normal;
///     only a Space held longer than the window is delivered slightly late.
/// Needs Accessibility permission (System Settings > Privacy & Security > Accessibility).
/// The chord is ignored while ChaJing itself is the active app so the search field
/// can be typed into normally.
final class SpaceChordMonitor {
    private static let magic: Int64 = 0x43484A5F5350 // tag for events we post ourselves
    private static let spaceKey: Int64 = 49
    private static let pKey: Int64 = 35

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: DispatchWorkItem?

    private var spaceHeld = false        // physical key is down
    private var pendingSpace = false     // keyDown swallowed, decision not made yet
    private var triggered = false        // chord fired for this Space press
    private var pHeldForChord = false    // P keyDown was swallowed; swallow its keyUp too

    let holdWindow: TimeInterval
    private let action: () -> Void

    private(set) var isRunning = false

    init(holdWindow: TimeInterval = 0.35, action: @escaping () -> Void) {
        self.holdWindow = holdWindow
        self.action = action
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that sends the user to the Accessibility settings pane.
    static func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        guard Self.isTrusted else { return false }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue) | (1 << CGEventType.tapDisabledByUserInput.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo -> Unmanaged<CGEvent>? in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<SpaceChordMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return me.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        guard isRunning else { return }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        runLoopSource = nil
        isRunning = false
        resetState()
    }

    // MARK: - Event handling (runs on the main run loop)

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        // Events we posted ourselves go straight through.
        if event.getIntegerValueField(.eventSourceUserData) == Self.magic { return pass }
        // Don't interfere with our own search field or with modifier shortcuts (⌘Space etc.).
        if NSApp.isActive {
            // Our own panel just came up (or the user is typing in it): deliver anything
            // still held and forget the chord state so a stale keyUp can't be swallowed later.
            if pendingSpace { flushPendingSpace() }
            spaceHeld = false
            triggered = false
            pHeldForChord = false
            return pass
        }
        let mods = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift, .maskSecondaryFn])
        if !mods.isEmpty {
            if pendingSpace { flushPendingSpace() }
            return pass
        }

        let key = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        switch type {
        case .keyDown:
            if key == Self.spaceKey {
                if !spaceHeld || !isRepeat { // a fresh press (repeat events are never a fresh press)
                    spaceHeld = true
                    pendingSpace = true
                    triggered = false
                    scheduleFlush()
                    return nil
                }
                // Auto-repeat while undecided or after the chord fired: swallow.
                if pendingSpace || triggered { return nil }
                return pass
            }
            if key == Self.pKey, spaceHeld, pendingSpace {
                pendingSpace = false
                triggered = true
                pHeldForChord = true
                cancelFlush()
                DispatchQueue.main.async { [action] in action() }
                return nil
            }
            if key == Self.pKey, spaceHeld, triggered {
                return nil // repeats of P while chord is held
            }
            if pendingSpace {
                // Ordinary typing: deliver the Space first, then this key, in order.
                cancelFlush()
                pendingSpace = false
                postSpace(down: true)
                postCopy(of: event)
                return nil
            }
            return pass

        case .keyUp:
            if key == Self.spaceKey {
                spaceHeld = false
                if pendingSpace {
                    // A quick tap of Space: deliver down + up now.
                    cancelFlush()
                    pendingSpace = false
                    postSpace(down: true)
                    postSpace(down: false)
                    return nil
                }
                if triggered {
                    triggered = false
                    return nil
                }
                return pass // matches the synthetic keyDown we already flushed
            }
            if key == Self.pKey, pHeldForChord {
                pHeldForChord = false
                return nil
            }
            return pass

        default:
            return pass
        }
    }

    private func scheduleFlush() {
        cancelFlush()
        let item = DispatchWorkItem { [weak self] in self?.flushPendingSpace() }
        timer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + holdWindow, execute: item)
    }

    private func cancelFlush() {
        timer?.cancel()
        timer = nil
    }

    /// Space held past the window without P: deliver the keyDown; the real keyUp
    /// will pass through later and close the pair.
    private func flushPendingSpace() {
        guard pendingSpace else { return }
        pendingSpace = false
        postSpace(down: true)
    }

    private func postSpace(down: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let e = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(Self.spaceKey), keyDown: down) else { return }
        e.setIntegerValueField(.eventSourceUserData, value: Self.magic)
        e.post(tap: .cghidEventTap)
    }

    private func postCopy(of event: CGEvent) {
        guard let copy = event.copy() else { return }
        copy.setIntegerValueField(.eventSourceUserData, value: Self.magic)
        copy.post(tap: .cghidEventTap)
    }

    private func resetState() {
        cancelFlush()
        spaceHeld = false
        pendingSpace = false
        triggered = false
        pHeldForChord = false
    }
}
