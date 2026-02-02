import Foundation

final class FileManagerService {
    static let shared = FileManagerService()

    private let fileManager = FileManager.default

    private init() {
        createDirectoriesIfNeeded()
    }

    // MARK: - 目录路径

    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var booksDirectory: URL {
        documentsDirectory.appendingPathComponent("Books", isDirectory: true)
    }

    var coversDirectory: URL {
        documentsDirectory.appendingPathComponent("Covers", isDirectory: true)
    }

    var tempDirectory: URL {
        fileManager.temporaryDirectory
    }

    // MARK: - 目录管理

    func createDirectoriesIfNeeded() {
        createDirectoryIfNeeded(at: booksDirectory)
        createDirectoryIfNeeded(at: coversDirectory)
    }

    private func createDirectoryIfNeeded(at url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - 文件操作

    func moveToDocuments(_ sourceURL: URL, fileName: String) throws -> URL {
        createDirectoriesIfNeeded()

        let destinationURL = booksDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: sourceURL, to: destinationURL)

        return destinationURL
    }

    func deleteBook(fileName: String) throws {
        let fileURL = booksDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    func fileExists(fileName: String) -> Bool {
        fileManager.fileExists(atPath: booksDirectory.appendingPathComponent(fileName).path)
    }

    func fileSize(fileName: String) -> Int64? {
        let url = booksDirectory.appendingPathComponent(fileName)
        return (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64)
    }

    func localFileURL(for fileName: String?) -> URL? {
        guard let fileName = fileName else { return nil }
        return booksDirectory.appendingPathComponent(fileName)
    }

    // MARK: - 列出所有书籍

    func listAllBooks() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: booksDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return []
        }
        return files
    }

    // MARK: - 存储空间检查

    func availableStorageSpace() -> Int64 {
        do {
            let values = try documentsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage ?? 0
        } catch {
            return 0
        }
    }

    func isStorageSufficient(for bytes: Int64) -> Bool {
        availableStorageSpace() > bytes
    }
}
