import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let book: Book
    @State private var showReader = false
    @State private var showDeleteConfirmation = false
    @State private var showCategoryEditor = false
    @State private var isFetchingCover = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 封面
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 200, height: 300)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            if let coverData = book.coverImageData,
                               let uiImage = UIImage(data: coverData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: bookIconName)
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    Text(book.fileExtension?.uppercased() ?? "BOOK")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                    // 联网匹配封面按钮
                    if book.coverImageData == nil {
                        Button {
                            fetchCover()
                        } label: {
                            if isFetchingCover {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "photo.badge.plus")
                            }
                        }
                        .padding(10)
                        .background(Color(UIColor.systemBackground).opacity(0.9))
                        .clipShape(Circle())
                        .padding(8)
                    }
                }
                .padding(.vertical)

                // 标题和作者
                VStack(alignment: .leading, spacing: 8) {
                    Text(book.title)
                        .font(.title)
                        .fontWeight(.bold)

                    if let author = book.author {
                        Text(author)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 阅读按钮
                Button {
                    showReader = true
                } label: {
                    Label("Start Reading", systemImage: "book")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canRead ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!canRead)

                // 状态信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("Book Information")
                        .font(.headline)

                    VStack(spacing: 8) {
                        infoRow(title: "Format", value: book.fileExtension?.uppercased() ?? "Unknown")

                        if let fileSize = book.fileSize {
                            infoRow(title: "Size", value: formattedFileSize(fileSize))
                        }

                        infoRow(title: "Added", value: book.createdAt.formatted(date: .abbreviated, time: .shortened))

                        // 分类行
                        HStack {
                            Text("Category")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                showCategoryEditor = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text(book.category ?? "未分类")
                                        .fontWeight(.medium)
                                        .foregroundColor(book.category == nil ? .secondary : .primary)
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .font(.subheadline)

                        if case .reading = book.status, let position = book.readingPosition {
                            infoRow(title: "Progress", value: "\(Int(position * 100))%")
                        }

                        if case .downloading(let progress) = book.status {
                            infoRow(title: "Download", value: "\(Int(progress * 100))%")
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                // 高亮/书签数量
                if !book.highlights.isEmpty || !book.bookmarks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Annotations")
                            .font(.headline)

                        HStack(spacing: 16) {
                            if !book.highlights.isEmpty {
                                Label("\(book.highlights.count) Highlights", systemImage: "highlighter")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if !book.bookmarks.isEmpty {
                                Label("\(book.bookmarks.count) Bookmarks", systemImage: "bookmark")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }

                // 下载来源
                if let remoteURL = book.remoteURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source")
                            .font(.headline)

                        Text(remoteURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .fullScreenCover(isPresented: $showReader) {
            if #available(iOS 17.0, *) {
                ReaderView(book: book)
            }
        }
        .confirmationDialog(
            "Delete Book",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteBook()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(book.title)\"? This will remove the book from your library.")
        }
        .sheet(isPresented: $showCategoryEditor) {
            CategoryEditorSheet(book: book)
        }
    }

    // MARK: - 辅助视图
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    // MARK: - 辅助属性
    private var canRead: Bool {
        if case .downloaded = book.status {
            return book.localFileName != nil
        }
        return false
    }

    private var bookIconName: String {
        switch book.fileExtension?.lowercased() {
        case "epub": return "book.closed"
        case "pdf": return "doc.text"
        default: return "doc.plaintext"
        }
    }

    private func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - 操作
    private func deleteBook() {
        if let fileName = book.localFileName {
            try? FileManagerService.shared.deleteBook(fileName: fileName)
        }
        modelContext.delete(book)
        dismiss()
    }

    private func fetchCover() {
        isFetchingCover = true
        Task {
            if let coverData = await CoverFetchService.shared.fetchCover(title: book.title, author: book.author) {
                await MainActor.run {
                    book.coverImageData = coverData
                    isFetchingCover = false
                }
            } else {
                await MainActor.run {
                    isFetchingCover = false
                }
            }
        }
    }
}

// MARK: - 分类编辑器
struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let book: Book
    @State private var categoryText: String = ""
    @State private var showDeleteConfirmation = false

    private let suggestedCategories = ["玄幻", "都市", "科幻", "历史", "悬疑", "言情", "完结", "连载中", "技术"]

    var body: some View {
        NavigationStack {
            Form {
                Section("自定义分类") {
                    TextField("输入分类名称", text: $categoryText)
                        .onAppear {
                            categoryText = book.category ?? ""
                        }
                }

                Section("推荐分类") {
                    ForEach(suggestedCategories, id: \.self) { cat in
                        Button {
                            categoryText = cat
                        } label: {
                            HStack {
                                Text(cat)
                                    .foregroundColor(.primary)
                                Spacer()
                                if categoryText == cat {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                if book.category != nil {
                    Section {
                        Button(role: .destructive) {
                            book.category = nil
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("清除分类")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        book.category = categoryText.isEmpty ? nil : categoryText
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 阅读器视图

@available(iOS 17.0, *)
struct ReaderView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch book.fileExtension?.lowercased() {
            case "txt":
                TXTReaderView(book: book)
            case "epub":
                EPUBReaderView(book: book)
            case "pdf":
                PDFReaderView(book: book)
            default:
                unsupportedFormatView
            }
        }
    }

    private var unsupportedFormatView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Unsupported Format")
                .font(.title2)
                .fontWeight(.bold)

            Text("'\(book.fileExtension ?? "unknown")' is not supported.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Close") {
                dismiss()
            }
            .padding(.top, 20)
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: Book(
            title: "The Great Gatsby",
            author: "F. Scott Fitzgerald",
            fileExtension: "epub"
        ))
    }
    .modelContainer(for: Book.self, inMemory: true)
}
