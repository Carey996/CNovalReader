import Foundation
import Combine

@MainActor
final class DownloadService: ObservableObject {
    // MARK: - 发布属性

    @Published private(set) var activeDownloads: [String: Book] = [:]

    // MARK: - 依赖

    private let fileManagerService: FileManagerService
    private var urlSession: URLSession

    // MARK: - 初始化

    init(fileManagerService: FileManagerService = FileManagerService.shared) {
        self.fileManagerService = fileManagerService

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - 下载方法

    func download(from urlString: String) async throws -> Book {
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }

        return try await download(from: url)
    }

    func download(from url: URL) async throws -> Book {
        let book = createBook(from: url)
        activeDownloads[book.id.uuidString] = book

        do {
            let (tempURL, response) = try await urlSession.download(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                book.status = .failed(DownloadError.invalidResponse.localizedDescription)
                activeDownloads.removeValue(forKey: book.id.uuidString)
                throw DownloadError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                book.status = .failed(DownloadError.httpError(statusCode: httpResponse.statusCode).localizedDescription)
                activeDownloads.removeValue(forKey: book.id.uuidString)
                throw DownloadError.httpError(statusCode: httpResponse.statusCode)
            }

            let savedURL = try fileManagerService.moveToDocuments(tempURL, fileName: book.localFileName ?? url.lastPathComponent)
            book.localFileName = savedURL.lastPathComponent
            book.status = .downloaded
            book.downloadProgress = 1.0
            book.fileSize = fileManagerService.fileSize(fileName: savedURL.lastPathComponent)

            activeDownloads.removeValue(forKey: book.id.uuidString)
            return book
        } catch let error as DownloadError {
            book.status = .failed(error.localizedDescription)
            activeDownloads.removeValue(forKey: book.id.uuidString)
            throw error
        } catch {
            book.status = .failed(error.localizedDescription)
            activeDownloads.removeValue(forKey: book.id.uuidString)
            throw DownloadError.networkError(underlying: error)
        }
    }

    // MARK: - 任务管理

    func cancelDownload(bookId: String) {
        activeDownloads.removeValue(forKey: bookId)
    }

    // MARK: - 辅助方法

    private func createBook(from url: URL) -> Book {
        let fileName = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        let fileExtension = url.pathExtension.lowercased()

        let book = Book(
            title: url.guessBookTitle,
            author: nil,
            remoteURL: url.absoluteString,
            localFileName: fileName,
            fileExtension: fileExtension
        )
        book.status = .downloading(progress: 0)

        return book
    }
}
