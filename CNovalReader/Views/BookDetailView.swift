import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let book: Book
    @State private var showReader = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 封面
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
}

// MARK: - 阅读器视图占位符

@available(iOS 17.0, *)
struct ReaderView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Reader for")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(book.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Spacer()

                if let fileName = book.localFileName {
                    let url = FileManagerService.shared.localFileURL(for: fileName)
                    if let url = url {
                        Text("File: \(url.lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Reader implementation coming soon...")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
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
