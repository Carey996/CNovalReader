import SwiftUI
import SwiftData

struct DownloadView: View {
    @StateObject private var viewModel = DownloadViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // URL 输入区域
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter Book URL")
                            .font(.headline)

                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.secondary)
                                .font(.body)

                            TextField("https://example.com/book.epub", text: $viewModel.urlString)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .disabled(viewModel.isDownloading)

                            if !viewModel.urlString.isEmpty && !viewModel.isDownloading {
                                Button {
                                    viewModel.clearInput()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // 下载按钮
                    Button {
                        viewModel.startDownload()
                    } label: {
                        HStack {
                            if viewModel.isDownloading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            Text(viewModel.isDownloading ? "Downloading..." : "Download Book")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.urlString.isEmpty ? Color.gray.opacity(0.5) : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.urlString.isEmpty || viewModel.isDownloading)
                    .padding(.horizontal)

                    // 进度条
                    if viewModel.isDownloading {
                        VStack(spacing: 8) {
                            ProgressView(value: viewModel.downloadProgress)
                                .progressViewStyle(.linear)
                                .padding(.horizontal)

                            Text(viewModel.currentStatus.displayText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .transition(.opacity)
                    }

                    Spacer(minLength: 20)

                    // 提示信息
                    VStack(spacing: 12) {
                        Text("Supported Formats")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            FormatBadge(format: "EPUB")
                            FormatBadge(format: "PDF")
                            FormatBadge(format: "TXT")
                        }

                        Text("Enter a URL above to download a book to your library")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("Download Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.isDownloading {
                        Button("Cancel") {
                            viewModel.cancelDownload()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Download Complete", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") {
                    if let book = viewModel.downloadedBook {
                        modelContext.insert(book)
                        dismiss()
                    }
                }
            } message: {
                if let book = viewModel.downloadedBook {
                    Text("\"\(book.title)\" has been added to your library.")
                }
            }
            .alert("Download Failed", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
        }
    }
}

// MARK: - 格式徽章

struct FormatBadge: View {
    let format: String

    var body: some View {
        Text(format)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .cornerRadius(8)
    }
}

#Preview {
    DownloadView()
        .modelContainer(for: Book.self, inMemory: true)
}
