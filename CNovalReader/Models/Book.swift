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

    // MARK: - 章节状态持久化 (TXT)
    var currentChapterIndex: Int
    var currentChapterTitle: String?
    var chaptersData: Data? // 序列化的章节信息

    // MARK: - 元数据
    var bookDescription: String?
    var coverImageData: Data?

    // MARK: - 书籍分类
    var category: String?

    // MARK: - 高亮列表
    var highlightsData: Data?
    // MARK: - 书签列表
    var bookmarksData: Data?

    // MARK: - 计算属性
    @Transient
    var highlights: [Highlight] {
        get {
            guard let data = highlightsData else { return [] }
            return (try? JSONDecoder().decode([Highlight].self, from: data)) ?? []
        }
        set {
            highlightsData = try? JSONEncoder().encode(newValue)
        }
    }

    @Transient
    var bookmarks: [Bookmark] {
        get {
            guard let data = bookmarksData else { return [] }
            return (try? JSONDecoder().decode([Bookmark].self, from: data)) ?? []
        }
        set {
            bookmarksData = try? JSONEncoder().encode(newValue)
        }
    }

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
        self.statusRawValue = nil
        self.currentChapterIndex = 0
        self.currentChapterTitle = nil
        self.chaptersData = nil
    }
}

// MARK: - 章节信息 (可序列化)
struct PersistedChapterInfo: Codable, Identifiable {
    let id: String
    let title: String
    let startLine: Int
    let endLine: Int

    init(id: String, title: String, startLine: Int, endLine: Int) {
        self.id = id
        self.title = title
        self.startLine = startLine
        self.endLine = endLine
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

// MARK: - 高亮数据结构
struct Highlight: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let chapterIndex: Int
    let rangeStart: Int
    let rangeEnd: Int
    let createdAt: Date
    var note: String?

    init(text: String, chapterIndex: Int, rangeStart: Int, rangeEnd: Int, note: String? = nil) {
        self.id = UUID()
        self.text = text
        self.chapterIndex = chapterIndex
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.createdAt = Date()
        self.note = note
    }
}

// MARK: - 书签数据结构
struct Bookmark: Codable, Identifiable, Equatable {
    let id: UUID
    let chapterIndex: Int
    let text: String
    let createdAt: Date

    init(chapterIndex: Int, text: String) {
        self.id = UUID()
        self.chapterIndex = chapterIndex
        self.text = text
        self.createdAt = Date()
    }
}

// MARK: - TXT 章节模型
struct TXTChapter: Identifiable, Hashable {
    let id: String
    let title: String
    let startLine: Int
    let endLine: Int
    let content: String
}

// MARK: - 章节智能检测 (独立函数，可在任何上下文中调用)
func detectChaptersFromText(_ text: String, bookTitle: String) -> [TXTChapter] {
    var detectedChapters: [TXTChapter] = []
    let lines = text.components(separatedBy: .newlines)

    let chapterPatterns = [
        #"^第[零一二三四五六七八九十百千0-9〇○]+章[:：]?\s*(.*)$"#,
        #"^第[零一二三四五六七八九十百千0-9〇○]+回[:：]?\s*(.*)$"#,
        #"^第[零一二三四五六七八九十百千0-9〇○]+篇[:：]?\s*(.*)$"#,
        #"^第[零一二三四五六七八九十百千0-9〇○]+部[:：]?\s*(.*)$"#,
        #"^卷[零一二三四五六七八九十百千0-9〇○]+[:：]\s*(.*)$"#,
        #"^(Volume|CHAPTER|Chapter|vol\.)\s*([0-9]+)[:\s]?(.*)$"#,
        #"^第[零一二三四五六七八九十百千0-9〇○]+节[:：]?\s*(.*)$"#,
        #"^章节\s*([0-9]+)[:：]?\s*(.*)$"#,
        #"^\(([0-9]+)\)[:：]?\s*(.*)$"#,
        #"^【([0-9零一二三四五六七八九十百千]+)】\s*(.*)$"#,
    ]

    var compiledPatterns: [NSRegularExpression] = []
    for pattern in chapterPatterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            compiledPatterns.append(regex)
        }
    }

    var currentChapterStart = 0
    var chapterCounter = 0
    var pendingChapterTitle: String?

    for (index, line) in lines.enumerated() {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)

        if trimmedLine.isEmpty {
            continue
        }

        var isChapterTitle = false
        var chapterTitle = ""

        for regex in compiledPatterns {
            let range = NSRange(trimmedLine.startIndex..., in: trimmedLine)
            if let match = regex.firstMatch(in: trimmedLine, options: [], range: range) {
                isChapterTitle = true
                if match.numberOfRanges > 1 {
                    for groupIndex in 1..<match.numberOfRanges {
                        if let groupRange = Range(match.range(at: groupIndex), in: trimmedLine) {
                            let groupValue = String(trimmedLine[groupRange]).trimmingCharacters(in: .whitespaces)
                            if !groupValue.isEmpty && groupValue.count > chapterTitle.count {
                                chapterTitle = groupValue
                            }
                        }
                    }
                }
                if chapterTitle.isEmpty {
                    chapterTitle = trimmedLine
                }
                break
            }
        }

        if !isChapterTitle {
            let pureNumberPattern = #"^(\d+)[\.、、]\s*\S"#
            if let regex = try? NSRegularExpression(pattern: pureNumberPattern, options: []) {
                let range = NSRange(trimmedLine.startIndex..., in: trimmedLine)
                if let match = regex.firstMatch(in: trimmedLine, options: [], range: range) {
                    if index + 1 < lines.count {
                        let nextLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
                        if nextLine.isEmpty || nextLine.count < 5 {
                            continue
                        }
                    }
                    isChapterTitle = true
                    chapterTitle = trimmedLine
                }
            }
        }

        if isChapterTitle {
            if chapterCounter > 0 || !detectedChapters.isEmpty {
                let endLine = index > 0 ? index - 1 : 0
                if endLine > currentChapterStart {
                    let chapterContent = lines[currentChapterStart..<endLine].joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !chapterContent.isEmpty {
                        let title = pendingChapterTitle ?? "第\(chapterCounter)章"
                        detectedChapters.append(TXTChapter(
                            id: "chapter_\(chapterCounter)",
                            title: title,
                            startLine: currentChapterStart,
                            endLine: endLine,
                            content: chapterContent
                        ))
                    }
                }
            }

            currentChapterStart = index
            chapterCounter += 1
            pendingChapterTitle = chapterTitle.isEmpty ? "第\(chapterCounter)章" : chapterTitle
        }
    }

    if currentChapterStart < lines.count {
        let chapterContent = lines[currentChapterStart..<lines.count].joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !chapterContent.isEmpty {
            let lastTitle = pendingChapterTitle ?? "第\(chapterCounter)章"
            detectedChapters.append(TXTChapter(
                id: "chapter_\(chapterCounter)",
                title: lastTitle,
                startLine: currentChapterStart,
                endLine: lines.count,
                content: chapterContent
            ))
        }
    }

    return detectedChapters
}
