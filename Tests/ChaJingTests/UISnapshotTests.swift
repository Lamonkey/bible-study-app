import AppKit
import SwiftUI
import XCTest
@testable import ChaJing

/// Offscreen screenshot generator for the app's UI states. Not a regression test:
/// it only runs when CHAJING_UI_SHOTS=1 (see `make ui-shots`) and writes PNGs plus a
/// manifest to docs/ui/shots/. Nothing is ever ordered onto the screen: each view is
/// hosted in an NSWindow that is never shown and captured with cacheDisplay(in:to:).
final class UISnapshotTests: XCTestCase {
    private static let scale: CGFloat = 2
    private static let searchSize = NSSize(width: 760, height: 460)
    private static let readerSize = NSSize(width: 640, height: 720)

    private struct Appearance {
        let suffix: String
        let name: NSAppearance.Name
    }

    private static let appearances = [
        Appearance(suffix: "light", name: .aqua),
        Appearance(suffix: "dark", name: .darkAqua),
    ]

    private enum Kind {
        case search(query: String, selectedIndex: Int)
        case reader(Passage)
        case about
    }

    private struct Shot {
        let name: String
        let kind: Kind
        let description: String
    }

    private static let shots: [Shot] = [
        Shot(name: "about", kind: .about,
             description: "「关于好查经」窗口：图标、版本、作者写的「为什么做这个」、GitHub 链接、快捷键与经文来源。"),
        Shot(name: "search-empty", kind: .search(query: "", selectedIndex: 0),
             description: "搜索窗口刚打开、输入框为空时，中间显示输入提示和几个示例写法。"),
        Shot(name: "search-result-verse", kind: .search(query: "lq 13:4-8", selectedIndex: 0),
             description: "输入 lq 13:4-8 只命中哥林多前书 13:4-8 一条结果，右侧预览滚动到第 4 节并高亮第 4-8 节。"),
        Shot(name: "search-result-multi", kind: .search(query: "yh 3:16", selectedIndex: 0),
             description: "输入 yh 3:16 命中多卷书，左侧列出多条结果，默认选中第一条并在右侧预览。"),
        Shot(name: "search-result-multi-second", kind: .search(query: "yh 3:16", selectedIndex: 1),
             description: "同样输入 yh 3:16，用方向键选中第二条结果，右侧预览随选中项切换。"),
        Shot(name: "search-result-books", kind: .search(query: "约", selectedIndex: 0),
             description: "只输入书名片段“约”而不带章节时，结果列表只列出匹配的书卷。"),
        Shot(name: "search-no-match", kind: .search(query: "yhfyx", selectedIndex: 0),
             description: "输入 yhfyx 没有任何书卷匹配，显示“没有匹配的书卷或章节”及匹配规则说明。"),
        Shot(name: "reader-highlight", kind: .reader(Passage(bookID: 46, chapter: 13, verse: 4, verseEnd: 8)),
             description: "阅读窗口打开哥林多前书 13:4-8，滚动到第 4 节并高亮第 4-8 节。"),
        Shot(name: "reader-chapter", kind: .reader(Passage(bookID: 43, chapter: 3, verse: nil, verseEnd: nil)),
             description: "阅读窗口打开约翰福音第 3 章整章，没有高亮，前后翻章按钮都可用。"),
        Shot(name: "reader-first-chapter", kind: .reader(Passage(bookID: 1, chapter: 1, verse: nil, verseEnd: nil)),
             description: "阅读窗口打开创世记第 1 章，已是第一章，所以上一章按钮为禁用状态。"),
    ]

    private static var outputDirectory: URL {
        URL(fileURLWithPath: #filePath)   // <repo>/Tests/ChaJingTests/UISnapshotTests.swift
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/ui/shots", isDirectory: true)
    }

    override func setUpWithError() throws {
        guard ProcessInfo.processInfo.environment["CHAJING_UI_SHOTS"] == "1" else {
            throw XCTSkip("UI snapshots are only rendered when CHAJING_UI_SHOTS=1 (make ui-shots)")
        }
    }

    @MainActor
    func testRenderAllStates() throws {
        // Never become a foreground app: no Dock icon, no activation, no visible window.
        NSApplication.shared.setActivationPolicy(.prohibited)

        let dir = Self.outputDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var manifest: [[String: Any]] = []
        for shot in Self.shots {
            let size: NSSize
            var entry: [String: Any] = ["name": shot.name, "description": shot.description]
            switch shot.kind {
            case .search(let query, _):
                size = Self.searchSize
                entry["view"] = "search"
                entry["query"] = query
            case .reader(let passage):
                size = Self.readerSize
                entry["view"] = "reader"
                entry["passage"] = BibleStore.shared.reference(passage)
            case .about:
                size = AboutView.size
                entry["view"] = "about"
            }
            entry["width"] = Int(size.width)
            entry["height"] = Int(size.height)
            entry["scale"] = Int(Self.scale)
            entry["files"] = Self.appearances.map { "\(shot.name).\($0.suffix).png" }

            for appearance in Self.appearances {
                let url = dir.appendingPathComponent("\(shot.name).\(appearance.suffix).png")
                let rep = try render(shot, size: size, appearance: appearance)
                XCTAssertEqual(rep.pixelsWide, Int(size.width * Self.scale), url.lastPathComponent)
                XCTAssertEqual(rep.pixelsHigh, Int(size.height * Self.scale), url.lastPathComponent)
                XCTAssertGreaterThan(Self.distinctColors(in: rep), 8, "\(url.lastPathComponent) looks blank")
                let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
                try png.write(to: url)
            }
            // Frames of the named UI parts (points, origin top-left), for labelled overlays.
            entry["regions"] = lastRegions
                .filter { $0.value.width > 0 && $0.value.height > 0 }
                .filter { CGRect(origin: .zero, size: size).intersects($0.value) }
                .sorted { $0.key < $1.key }
                .map { id, r -> [String: Any] in
                    let v = r.intersection(CGRect(origin: .zero, size: size))   // visible part
                    return ["id": id, "x": Int(v.minX.rounded()), "y": Int(v.minY.rounded()),
                            "width": Int(v.width.rounded()), "height": Int(v.height.rounded())]
                }
            manifest.append(entry)
        }

        let json = try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try json.write(to: dir.appendingPathComponent("manifest.json"))
    }

    // MARK: - Rendering

    /// Filled by `RegionProbe` while a view is rendered; read after the last settle.
    private var lastRegions: [String: CGRect] = [:]

    @MainActor
    private func render(_ shot: Shot, size: NSSize, appearance: Appearance) throws -> NSBitmapImageRep {
        let nsAppearance = try XCTUnwrap(NSAppearance(named: appearance.name))

        // Parked far away from any display and never ordered in.
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: -30_000, y: -30_000), size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = nsAppearance

        let container = BackdropView(frame: NSRect(origin: .zero, size: size))
        container.appearance = nsAppearance
        window.contentView = container

        var afterFirstLayout: () -> Void = {}
        let hosting: NSView
        switch shot.kind {
        case .search(let query, let selectedIndex):
            let model = SearchViewModel()
            model.query = query
            hosting = NSHostingView(rootView: probe(SearchView(model: model)))
            if selectedIndex != 0 {
                // Change the selection after the view is live, the way ↓ does in the app,
                // so the list's and the preview's onChange handlers run.
                afterFirstLayout = { model.selectedIndex = selectedIndex }
            }
        case .reader(let passage):
            hosting = NSHostingView(rootView: probe(ReaderView(model: ReaderModel(passage: passage))))
        case .about:
            // NSApp has no icon under xctest; show the packaged one.
            let icns = Self.outputDirectory.appendingPathComponent("../../../packaging/AppIcon.icns").standardizedFileURL
            let plist = icns.deletingLastPathComponent().appendingPathComponent("Info.plist")
            let info = NSDictionary(contentsOf: plist)
            let version = info?["CFBundleShortVersionString"] as? String ?? ""
            hosting = NSHostingView(rootView: probe(AboutView(icon: NSImage(contentsOf: icns) ?? NSImage(), version: version)))
        }
        hosting.appearance = nsAppearance
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)
        window.setContentSize(size)

        settle(container)
        afterFirstLayout()
        // SearchView focuses its text field on appear, which selects the whole query; in a
        // window that is not key that paints a grey selection block behind the text.
        // Collapse it to a caret at the end, which is what the user sees after typing.
        if let editor = window.firstResponder as? NSTextView {
            editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        }
        settle(container)

        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * Self.scale),
            pixelsHigh: Int(size.height * Self.scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        rep.size = size   // points; pixels / points = 2x
        container.cacheDisplay(in: container.bounds, to: rep)

        XCTAssertFalse(window.isVisible, "snapshot window must never be on screen")
        window.contentView = nil
        window.close()
        return rep
    }

    /// Lay out, then let the main run loop turn so SwiftUI's async work (onAppear,
    /// ScrollViewReader.scrollTo, lazy stack population) lands before the capture.
    @MainActor
    /// Resolves every `.uiRegion` anchor against the root view and records the frames.
    private func probe<V: View>(_ view: V) -> some View {
        lastRegions = [:]
        return view.backgroundPreferenceValue(UIRegionKey.self) { [weak self] anchors in
            GeometryReader { geo in
                let _ = { self?.lastRegions = anchors.mapValues { geo[$0] } }()
                Color.clear
            }
        }
    }

    private func settle(_ view: NSView) {
        for _ in 0..<3 {
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        }
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
    }

    /// Coarse blank-image detector: number of distinct colours on a sparse sample grid.
    private static func distinctColors(in rep: NSBitmapImageRep) -> Int {
        var seen = Set<UInt32>()
        for y in stride(from: 0, to: rep.pixelsHigh, by: 7) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 5) {
                var px = [Int](repeating: 0, count: 4)
                rep.getPixel(&px, atX: x, y: y)
                seen.insert(UInt32(px[0]) << 16 | UInt32(px[1]) << 8 | UInt32(px[2]))
            }
        }
        return seen.count
    }
}

/// Opaque window-background fill behind the hosting view, resolved in the view's own
/// appearance, so the PNGs are never transparent.
private final class BackdropView: NSView {
    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
    }
}
