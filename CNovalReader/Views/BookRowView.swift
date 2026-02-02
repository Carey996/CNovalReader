import SwiftUI
import SwiftData

struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            // 封面占位符
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 80)
                .overlay {
                    if let coverData = book.coverImageData,
                       let uiImage = UIImage(data: coverData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: bookIconName)
                                .font(.title3)
                                .foregroundColor(.secondary)
                            if let ext = book.fileExtension?.uppercased(), ext.count > 0 {
                                Text(ext)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

            // 书籍信息
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)

                if let author = book.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    statusBadge

                    if let fileSize = book.fileSize {
                        Text(formattedFileSize(fileSize))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // 状态图标
            Image(systemName: statusIconName)
                .foregroundColor(statusColor)
                .font(.title3)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 状态徽章

    @ViewBuilder
    private var statusBadge: some View {
        switch book.status {
        case .downloading(let progress):
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
            }
            .foregroundColor(.blue)

        case .downloaded:
            Label("Downloaded", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)

        case .failed(let error):
            VStack(alignment: .leading, spacing: 2) {
                Label("Failed", systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.7))
                    .lineLimit(1)
            }

        case .reading:
            Label("Reading", systemImage: "book.fill")
                .font(.caption)
                .foregroundColor(.orange)

        case .unknown:
            EmptyView()
        }
    }

    // MARK: - 辅助属性

    private var statusIconName: String {
        switch book.status {
        case .downloading: return "arrow.down.circle"
        case .downloaded: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .reading: return "book.fill"
        case .unknown: return "book.closed"
        }
    }

    private var statusColor: Color {
        switch book.status {
        case .downloading: return .blue
        case .downloaded: return .green
        case .failed: return .red
        case .reading: return .orange
        case .unknown: return .gray
        }
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
}

#Preview {
    List {
        BookRowView(book: Book(title: "Sample Book", fileExtension: "epub"))
        BookRowView(book: Book(title: "Another Book", fileExtension: "pdf"))
    }
    .modelContainer(for: Book.self, inMemory: true)
}
