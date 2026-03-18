import SwiftUI

/// 沉浸式阅读状态管理器
struct ImmersiveReaderModifier: ViewModifier {
    @Binding var isImmersive: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isImmersive ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isImmersive)
    }
}

extension View {
    func immersiveToolbar(isImmersive: Bool) -> some View {
        modifier(ImmersiveReaderModifier(isImmersive: .constant(isImmersive)))
    }
}

/// 长按文本选择菜单命令
struct TextSelectionCommand: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let action: () -> Void
}

/// 文本选择弹出菜单
struct TextSelectionMenu: View {
    let commands: [TextSelectionCommand]
    @Binding var showMenu: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                ForEach(Array(commands.enumerated()), id: \.element.id) { index, cmd in
                    Button(action: {
                        cmd.action()
                        showMenu = false
                    }) {
                        HStack {
                            Image(systemName: cmd.systemImage)
                                .font(.body)
                            Text(cmd.title)
                                .font(.body)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .foregroundColor(.primary)

                    if index < commands.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showMenu = false
                }
        )
    }
}

/// 高亮/书签/笔记列表视图
struct HighlightsListView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if book.highlights.isEmpty && book.bookmarks.isEmpty {
                    ContentUnavailableView(
                        "暂无标注",
                        systemImage: "highlighter",
                        description: Text("长按书籍内容添加高亮或书签")
                    )
                } else {
                    if !book.highlights.isEmpty {
                        Section("高亮") {
                            ForEach(book.highlights) { highlight in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(highlight.text)
                                        .font(.body)
                                        .lineLimit(3)

                                    HStack {
                                        Text("第 \(highlight.chapterIndex + 1) 章")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        if let note = highlight.note, !note.isEmpty {
                                            Text("• 笔记: \(note)")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Text(highlight.createdAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .onDelete(perform: deleteHighlight)
                        }
                    }

                    if !book.bookmarks.isEmpty {
                        Section("书签") {
                            ForEach(book.bookmarks) { bookmark in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.text.isEmpty ? "书签" : bookmark.text)
                                        .font(.body)
                                        .lineLimit(2)

                                    HStack {
                                        Text("第 \(bookmark.chapterIndex + 1) 章")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Spacer()

                                        Text(bookmark.createdAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .onDelete(perform: deleteBookmark)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("标注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func deleteHighlight(at offsets: IndexSet) {
        var highlights = book.highlights
        highlights.remove(atOffsets: offsets)
        book.highlights = highlights
    }

    private func deleteBookmark(at offsets: IndexSet) {
        var bookmarks = book.bookmarks
        bookmarks.remove(atOffsets: offsets)
        book.bookmarks = bookmarks
    }
}

/// 章节选择命令（用于下滑翻章）
enum ChapterSwipeDirection {
    case previous
    case next
}
