import Foundation
import SwiftData

@Model
final class Book {
    // MARK: - 基础信息
    var id: UUID
    var title: String
    var author: String?
    var remoteURL: String?
    var localFileName: String?

    // MARK: - 文件信息
    var fileSize: Int64?
    var fileExtension: String?

    // MARK: - 状态
    var statusRawValue: Data?
    var downloadProgress: Double

    // MARK: - 时间戳
    var createdAt: Date
    var updatedAt: Date
    var lastReadAt: Date?

    // MARK: - 阅读进度
    var currentPage: Int?
    var totalPages: Int?
    var readingPosition: Double?

    // MARK: - 元数据
    var bookDescription: String?
    var coverImageData: Data?

    // MARK: - 计算属性
    @Transient
    var status: BookStatus {
        get {
            guard let data = statusRawValue else { return .unknown }
            return (try? JSONDecoder().decode(BookStatus.self, from: data)) ?? .unknown
        }
        set {
            statusRawValue = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        title: String,
        author: String? = nil,
        remoteURL: String? = nil,
        localFileName: String? = nil,
        fileExtension: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.remoteURL = remoteURL
        self.localFileName = localFileName
        self.fileExtension = fileExtension
        self.downloadProgress = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.status = .unknown
    }
}

// MARK: - 下载状态枚举
enum BookStatus: Codable, Equatable {
    case unknown
    case downloading(progress: Double)
    case downloaded
    case failed(String)
    case reading

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }

    var isDownloaded: Bool {
        if case .downloaded = self { return true }
        return false
    }
}
