import Foundation
import SwiftUI
import Combine

@MainActor
final class DownloadViewModel: ObservableObject {
    // MARK: - 输入

    @Published var urlString: String = ""

    // MARK: - 状态

    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0
    @Published var currentStatus: DownloadStatus = .idle

    // MARK: - 错误处理

    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // MARK: - 下载结果

    @Published var downloadedBook: Book?
    @Published var showSuccessAlert: Bool = false

    // MARK: - 依赖

    private let downloadService = DownloadService()
    private var downloadTask: Task<Void, Never>?

    // MARK: - 下载操作

    func startDownload() {
        guard !urlString.isEmpty else {
            showErrorMessage("Please enter a URL")
            return
        }

        guard let url = URL(string: urlString), url.scheme != nil else {
            showErrorMessage("Invalid URL format. Please check the URL and try again.")
            return
        }

        // 检查文件格式
        let supportedExtensions = ["epub", "pdf", "txt", "mobi", "azw3", "fb2"]
        let fileExtension = url.pathExtension.lowercased()
        if !supportedExtensions.contains(fileExtension) && !fileExtension.isEmpty {
            showErrorMessage("Unsupported format: \(fileExtension). Supported formats: EPUB, PDF, TXT")
            return
        }

        isDownloading = true
        currentStatus = .downloading(progress: 0)
        errorMessage = nil

        downloadTask = Task {
            do {
                let book = try await downloadService.download(from: urlString)
                downloadedBook = book
                currentStatus = .completed
                showSuccessAlert = true
            } catch let error as DownloadError {
                handleDownloadError(error)
            } catch {
                showErrorMessage(error.localizedDescription)
            }

            isDownloading = false
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        currentStatus = .idle
        urlString = ""
    }

    func clearInput() {
        urlString = ""
        errorMessage = nil
        showError = false
    }

    // MARK: - 错误处理

    private func handleDownloadError(_ error: DownloadError) {
        switch error {
        case .invalidURL:
            showErrorMessage("Invalid URL format. Please check and try again.")
        case .httpError(let statusCode):
            showErrorMessage("Server error (\(statusCode)). Please try again later.")
        case .networkError:
            showErrorMessage("Network error. Please check your connection.")
        case .unsupportedFormat(let format):
            showErrorMessage("Format \(format) is not supported.")
        default:
            showErrorMessage(error.localizedDescription)
        }
        currentStatus = .failed
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - 下载状态

enum DownloadStatus: Equatable {
    case idle
    case downloading(progress: Double)
    case completed
    case failed

    var displayText: String {
        switch self {
        case .idle:
            return ""
        case .downloading(let progress):
            return "Downloading... \(Int(progress * 100))%"
        case .completed:
            return "Download Complete"
        case .failed:
            return "Download Failed"
        }
    }
}
