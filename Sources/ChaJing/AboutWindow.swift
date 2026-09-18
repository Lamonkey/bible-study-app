import AppKit
import SwiftUI

/// The About window: what the app is, why it was made, and where to find the author.
/// A plain NSAlert cannot hold a clickable link or comfortable body text, hence a window.
struct AboutView: View {
    static let size = CGSize(width: 440, height: 500)
    static let authorURL = URL(string: "https://github.com/Lamonkey")!

    /// Injected so offscreen snapshots can show the real icon (NSApp has none under xctest).
    var icon: NSImage = NSApp.applicationIconImage

    /// Injected for the same reason; the running app reads its own Info.plist.
    var version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .uiRegion("about.icon")
                .padding(.top, 22)
            Text("好查经")
                .font(.system(size: 22, weight: .semibold))
                .uiRegion("about.name")
                .padding(.top, 6)
            Text("版本 \(version) · 简体和合本经文快速检索")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .uiRegion("about.version")
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 10) {
                Text("为什么做这个")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("在学习主的话语、参加查经小组时，我时常需要翻阅圣经的不同章节。对于圣经书卷名字还不熟悉的我，翻阅起来效率较低，于是按照我心中所想，做了这个方便查阅主话语的软件。")
                Text("希望能帮助到和我一样刚开始仰慕主的弟兄姊妹，愿神与你们同在。")
                    .fontWeight(.medium)
            }
            .font(.system(size: 14))
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
            .uiRegion("about.story")
            .padding(.horizontal, 22)
            .padding(.top, 16)

            HStack(spacing: 6) {
                Text("作者")
                    .foregroundColor(.secondary)
                Link("github.com/Lamonkey", destination: Self.authorURL)
            }
            .font(.system(size: 13))
            .uiRegion("about.author")
            .padding(.top, 14)

            Spacer(minLength: 12)

            VStack(spacing: 3) {
                Text("⌥Space 或按住 Space 再按 P 呼出搜索 · ⏎ 打开 · ⇧⏎ / ⌘D 新窗口 · ⌘⏎ 复制")
                Text("经文：和合本（公共领域），繁转简由 OpenCC 完成")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .uiRegion("about.footer")
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

final class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: AboutView.size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "关于好查经"
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.contentView = NSHostingView(rootView: AboutView())
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        if !(window?.isVisible ?? false) { window?.center() }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
