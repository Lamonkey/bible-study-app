import SwiftUI

/// Main window content: search input on top, matching references on the left,
/// the selected passage on the right.
struct SearchView: View {
    @ObservedObject var model: SearchViewModel
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "book.closed")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                TextField("书卷 章:节   例如  yhfy 4:24 · yuehan 3 16 · 约 4:24", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .regular))
                    .focused($inputFocused)
                    .onSubmit { model.openSelected() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .uiRegion("search.input")

            Divider()

            if model.results.isEmpty {
                emptyState
                    .uiRegion(model.query.trimmingCharacters(in: .whitespaces).isEmpty ? "search.emptyState" : "search.noMatch")
            } else {
                HStack(spacing: 0) {
                    resultList
                        .frame(width: 250)
                        .uiRegion("search.resultList")
                    Divider()
                    PassageView(passage: model.selected?.passage, highlight: model.selected?.passage.verseRange)
                        .uiRegion("search.preview")
                }
            }

            Divider()
            // Every hint is also a button: someone new to the app can click their way
            // through and pick up the shortcuts from the labels as they go.
            HStack(spacing: 4) {
                HintButton(keys: "↑", label: nil, help: "上一条结果") { model.moveSelection(by: -1) }
                    .disabled(model.results.count < 2)
                    .uiRegion("search.footer.up")
                HintButton(keys: "↓", label: "选择", help: "下一条结果") { model.moveSelection(by: 1) }
                    .disabled(model.results.count < 2)
                    .uiRegion("search.footer.down")
                HintButton(keys: "⏎", label: "打开", help: "在阅读窗口中打开所选经文") { model.openSelected() }
                    .disabled(model.selected == nil)
                    .uiRegion("search.footer.open")
                HintButton(keys: "⇧⏎", label: "新窗口打开", help: "在新的阅读窗口中打开，方便几处经文对照") {
                    model.openSelected(inNewWindow: true)
                }
                .disabled(model.selected == nil)
                .uiRegion("search.footer.openNew")
                HintButton(keys: "⌘⏎", label: "复制经文", help: "把所选经文和出处复制到剪贴板") { model.copySelected() }
                    .disabled(model.selected == nil)
                    .uiRegion("search.footer.copy")
                // Mirrors the esc key: with text in the field it clears, otherwise it hides.
                HintButton(keys: "esc", label: model.query.isEmpty ? "隐藏" : "清空",
                           help: model.query.isEmpty ? "收起搜索窗口，应用留在后台" : "清空输入；再按一次 esc 收起窗口") {
                    SearchWindowController.shared.escape()
                }
                .uiRegion("search.footer.hide")
                Spacer()
                Text("简体和合本")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .uiRegion("search.footer.version")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .uiRegion("search.footer")
        }
        .frame(minWidth: 640, minHeight: 380)
        .onAppear { inputFocused = true }
        .onChange(of: model.focusToken) { _ in inputFocused = true }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("输入拼音首字母、拼音或中文书名，后面跟 章:节")
                    .foregroundColor(.secondary)
                Text("yhfy 4:24      yhfy 4 24      yuehan 4      约翰福音 4:24      林前 13:4-8      *fy 3:16")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                Text("没有匹配的书卷或章节")
                    .foregroundColor(.secondary)
                Text("拼音只按字首/音节前缀精确匹配（不做模糊匹配），* 匹配任意音节，? 匹配一个音节")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { idx, r in
                        ResultRow(result: r, selected: idx == model.selectedIndex)
                            .uiRegion(idx == model.selectedIndex ? "search.resultRow.selected" : "search.resultRow.\(idx)")
                            .id(r.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if model.selectedIndex == idx {
                                    model.openSelected()
                                } else {
                                    model.selectedIndex = idx
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: model.selectedIndex) { _ in
                if let r = model.selected { proxy.scrollTo(r.id) }
            }
        }
    }
}

/// One entry of the footer bar: a keycap plus what it does. Clicking it performs the same
/// action as the shortcut it shows. Buttons do not take keyboard focus on macOS, so the
/// search field keeps the caret.
struct HintButton: View {
    let keys: String
    let label: String?
    let help: String
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(keys)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.12)))
                if let label {
                    Text(label).font(.system(size: 11))
                }
            }
            .foregroundColor(hovering && isEnabled ? .primary : .secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(hovering && isEnabled ? 0.08 : 0)))
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(label.map { "\($0)，快捷键 \(keys)" } ?? help)
    }
}

struct ResultRow: View {
    let result: SearchResult
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.title)
                .font(.system(size: 14, weight: .semibold))
            Text(result.subtitle)
                .font(.system(size: 11))
                .foregroundColor(selected ? .white.opacity(0.85) : .secondary)
                .lineLimit(1)
        }
        .foregroundColor(selected ? .white : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selected ? Color.accentColor : Color.clear)
                .padding(.horizontal, 4)
        )
    }
}

/// A chapter's verses with an optional highlighted range, scrolled into view.
struct PassageView: View {
    let passage: Passage?
    let highlight: ClosedRange<Int>?

    var body: some View {
        if let p = passage, let book = BibleStore.shared.book(id: p.bookID) {
            let verses = book.verses(chapter: p.chapter)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(book.name) 第 \(p.chapter) 章")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                            .uiRegion("passage.heading")
                        ForEach(Array(verses.enumerated()), id: \.offset) { i, v in
                            VerseLine(number: i + 1, text: v, highlighted: highlight?.contains(i + 1) ?? false)
                                .uiRegion(highlight?.lowerBound == i + 1 ? "passage.verse.highlighted" : "passage.verse.\(i + 1)")
                                .id(i + 1)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onAppear { scroll(proxy) }
                .onChange(of: p) { _ in scroll(proxy) }
            }
        } else {
            Color.clear
        }
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        let target = highlight?.lowerBound ?? 1
        DispatchQueue.main.async {
            proxy.scrollTo(target, anchor: .top)
        }
    }
}

struct VerseLine: View {
    let number: Int
    let text: String
    let highlighted: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 26, alignment: .trailing)
            Text(text)
                .font(.system(size: 15))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(highlighted ? Color.accentColor.opacity(0.18) : Color.clear)
        )
    }
}
