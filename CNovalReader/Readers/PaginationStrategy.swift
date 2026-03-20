import UIKit
import Foundation

// MARK: - 分页协议

/// 定义分页策略的协议
/// 用于 TXT、EPUB 等不同格式的智能分页
protocol PaginationStrategy {
    associatedtype Chapter
    
    /// 根据容器尺寸和字体设置，计算章节内容分为多少页
    func pageCount(for chapter: Chapter, containerSize: CGSize, fontSize: CGFloat, lineHeight: CGFloat) -> Int
    
    /// 获取指定页的内容片段
    /// - Parameters:
    ///   - page: 页码（从0开始）
    ///   - chapter: 章节内容
    ///   - containerSize: 容器尺寸
    ///   - fontSize: 字体大小
    ///   - lineHeight: 行高
    /// - Returns: 该页的内容文本
    func contentForPage(_ page: Int, in chapter: Chapter, containerSize: CGSize, fontSize: CGFloat, lineHeight: CGFloat) -> String
}

// MARK: - TXT 分页策略

/// TXT 文件分页策略
/// 根据每页行数 = (容器高度 - 上下padding) / lineHeight 进行分页
struct TXTPaginationStrategy: PaginationStrategy {
    typealias Chapter = TXTChapter

    private let verticalPadding: CGFloat = 32 // 上下 padding

    func pageCount(for chapter: TXTChapter, containerSize: CGSize, fontSize: CGFloat, lineHeight: CGFloat) -> Int {
        guard containerSize.height > 0, lineHeight > 0 else { return 1 }

        let availableHeight = containerSize.height - verticalPadding
        guard availableHeight > 0 else { return 1 }

        let lines = chapter.content.components(separatedBy: .newlines)
        let linesPerPage = max(1, Int(availableHeight / lineHeight))

        return max(1, Int(ceil(Double(lines.count) / Double(linesPerPage))))
    }

    func contentForPage(_ page: Int, in chapter: TXTChapter, containerSize: CGSize, fontSize: CGFloat, lineHeight: CGFloat) -> String {
        guard containerSize.height > 0, lineHeight > 0 else {
            return chapter.content
        }

        let availableHeight = containerSize.height - verticalPadding
        guard availableHeight > 0 else { return chapter.content }

        let lines = chapter.content.components(separatedBy: .newlines)
        let linesPerPage = max(1, Int(availableHeight / lineHeight))

        let startIndex = page * linesPerPage
        guard startIndex < lines.count else { return "" }

        let endIndex = min(startIndex + linesPerPage, lines.count)
        return lines[startIndex..<endIndex].joined(separator: "\n")
    }

    /// 根据内容字符串计算总页数（适用于惰性加载场景）
    func pageCountForContent(_ content: String, containerSize: CGSize, fontSize: CGFloat, lineHeight: CGFloat) -> Int {
        guard containerSize.height > 0, lineHeight > 0 else { return 1 }

        let availableHeight = containerSize.height - verticalPadding
        guard availableHeight > 0 else { return 1 }

        let lines = content.components(separatedBy: .newlines)
        let linesPerPage = max(1, Int(availableHeight / lineHeight))

        return max(1, Int(ceil(Double(lines.count) / Double(linesPerPage))))
    }

    /// 根据内容字符串获取指定页的内容（适用于惰性加载场景）
    func contentForPage(_ page: Int, content: String, containerSize: CGSize, fontSize: CGFloat, lineHeight: CGFloat) -> String {
        guard containerSize.height > 0, lineHeight > 0 else {
            return content
        }

        let availableHeight = containerSize.height - verticalPadding
        guard availableHeight > 0 else { return content }

        let lines = content.components(separatedBy: .newlines)
        let linesPerPage = max(1, Int(availableHeight / lineHeight))

        let startIndex = page * linesPerPage
        guard startIndex < lines.count else { return "" }

        let endIndex = min(startIndex + linesPerPage, lines.count)
        return lines[startIndex..<endIndex].joined(separator: "\n")
    }
}

// MARK: - EPUB 分页策略

/// EPUB 文件分页策略
/// 使用 NSAttributedString + NSTextStorage + NSLayoutManager 计算每页字符数
struct EPUBPaginationStrategy: PaginationStrategy {
    typealias Chapter = EPUBChapterContent
    
    private let verticalPadding: CGFloat = 32 // 上下 padding
    
    struct EPUBChapterContent {
        let title: String
        let content: String
    }
    
    func pageCount(for chapter: EPUBChapterContent, containerSize: CGSize, fontSize: CGFloat, lineHeight: CGFloat) -> Int {
        guard containerSize.height > 0, containerSize.width > 0, fontSize > 0 else { return 1 }
        
        let availableHeight = containerSize.height - verticalPadding
        guard availableHeight > 0 else { return 1 }
        
        let pageSize = CGSize(width: containerSize.width - 16, height: availableHeight)
        
        let charsPerPage = estimateCharsPerPage(containerSize: pageSize, fontSize: fontSize, lineHeight: lineHeight)
        guard charsPerPage > 0 else { return 1 }
        
        return max(1, Int(ceil(Double(chapter.content.count) / Double(charsPerPage))))
    }
    
    func contentForPage(_ page: Int, in chapter: EPUBChapterContent, containerSize: CGSize, fontSize: CGFloat, lineHeight: CGFloat) -> String {
        guard containerSize.height > 0, containerSize.width > 0, fontSize > 0 else {
            return chapter.content
        }
        
        let availableHeight = containerSize.height - verticalPadding
        guard availableHeight > 0 else { return chapter.content }
        
        let pageSize = CGSize(width: containerSize.width - 16, height: availableHeight)
        let charsPerPage = estimateCharsPerPage(containerSize: pageSize, fontSize: fontSize, lineHeight: lineHeight)
        guard charsPerPage > 0 else { return chapter.content }
        
        let startIndex = page * charsPerPage
        guard startIndex < chapter.content.count else { return "" }
        
        let endIndex = min(startIndex + charsPerPage, chapter.content.count)
        
        let start = chapter.content.index(chapter.content.startIndex, offsetBy: startIndex)
        let end = chapter.content.index(chapter.content.startIndex, offsetBy: endIndex)
        
        return String(chapter.content[start..<end])
    }
    
    /// 使用 NSTextStorage + NSLayoutManager 估算每页字符数（精确计算）
    private func estimateCharsPerPage(containerSize: CGSize, fontSize: CGFloat, lineHeight: CGFloat) -> Int {
        guard containerSize.width > 0, containerSize.height > 0 else { return 0 }
        
        // 创建 NSAttributedString
        let sampleText = "测试文本用于估算每页字符数，确保排版计算准确。"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineHeight - fontSize
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSMutableAttributedString(string: sampleText, attributes: attributes)
        
        // 创建 TextStorage + LayoutManager
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: containerSize.width, height: .greatestFiniteMagnitude))
        
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // 获取字符索引
        let glyphRange = layoutManager.glyphRange(forBoundingRect: CGRect(origin: .zero, size: CGSize(width: containerSize.width, height: containerSize.height)), in: textContainer)
        
        // sampleText 的字符数 / (glyphRange.length / sampleText字符数) = 每页约多少字符
        let sampleCharCount = sampleText.count
        let sampleGlyphCount = glyphRange.length
        
        guard sampleGlyphCount > 0 else {
            // fallback: 基于容器尺寸和字体大小估算
            let charWidth = fontSize * 0.6 // 粗略估计
            let charsPerLine = Int(containerSize.width / charWidth)
            let linesPerPage = Int(containerSize.height / lineHeight)
            return charsPerLine * linesPerPage
        }
        
        // 根据 sampleText 在容器中的实际 glyph 数，估算整个内容的 glyph 数
        let ratio = Double(sampleCharCount) / Double(sampleGlyphCount)
        let estimatedCharsPerLine = Int(Double(containerSize.width / fontSize) * ratio)
        
        // 估算每页行数
        let linesPerPage = Int(containerSize.height / lineHeight)
        return max(1, estimatedCharsPerLine * linesPerPage)
    }
}

// MARK: - 分页计算结果

/// 分页计算的结果，包含所有页面的信息
struct PaginationResult {
    let totalPages: Int
    let linesPerPage: Int
    let pageContents: [String]
    
    static let empty = PaginationResult(totalPages: 0, linesPerPage: 0, pageContents: [])
}

// MARK: - 后台分页计算器

/// 在后台线程进行分页计算的工具
enum PaginationCalculator {
    
    /// 计算 TXT 章节的分页（后台执行）
    static func calculateTXTPageCount(
        chapter: TXTChapter,
        containerSize: CGSize,
        fontSize: CGFloat,
        lineHeight: CGFloat,
        completion: @escaping (Int) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let strategy = TXTPaginationStrategy()
            let count = strategy.pageCount(for: chapter, containerSize: containerSize, fontSize: fontSize, lineHeight: lineHeight)
            DispatchQueue.main.async {
                completion(count)
            }
        }
    }
    
    /// 计算 EPUB 章节的分页（后台执行）
    static func calculateEPUBPageCount(
        content: EPUBPaginationStrategy.EPUBChapterContent,
        containerSize: CGSize,
        fontSize: CGFloat,
        lineHeight: CGFloat,
        completion: @escaping (Int) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let strategy = EPUBPaginationStrategy()
            let count = strategy.pageCount(for: content, containerSize: containerSize, fontSize: fontSize, lineHeight: lineHeight)
            DispatchQueue.main.async {
                completion(count)
            }
        }
    }
    
    /// 预计算所有页的内容（后台执行，返回所有页内容数组）
    static func precomputeTXTPages(
        chapter: TXTChapter,
        containerSize: CGSize,
        fontSize: CGFloat,
        lineHeight: CGFloat,
        completion: @escaping ([String]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let strategy = TXTPaginationStrategy()
            let totalPages = strategy.pageCount(for: chapter, containerSize: containerSize, fontSize: fontSize, lineHeight: lineHeight)
            var pages: [String] = []
            for page in 0..<totalPages {
                let content = strategy.contentForPage(page, in: chapter, containerSize: containerSize, fontSize: fontSize, lineHeight: lineHeight)
                pages.append(content)
            }
            DispatchQueue.main.async {
                completion(pages)
            }
        }
    }

    /// 预计算所有页的内容（直接传入内容字符串，适用于惰性加载场景）
    static func precomputeTXTPagesFromContent(
        content: String,
        containerSize: CGSize,
        fontSize: CGFloat,
        lineHeight: CGFloat,
        completion: @escaping ([String]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let strategy = TXTPaginationStrategy()
            let totalPages = strategy.pageCountForContent(content, containerSize: containerSize, fontSize: fontSize, lineHeight: lineHeight)
            var pages: [String] = []
            for page in 0..<totalPages {
                let pageContent = strategy.contentForPage(page, content: content, containerSize: containerSize, fontSize: fontSize, lineHeight: lineHeight)
                pages.append(pageContent)
            }
            DispatchQueue.main.async {
                completion(pages)
            }
        }
    }
    
    /// 预计算所有页的内容（EPUB，后台执行）
    static func precomputeEPUBTPages(
        chapter: EPUBPaginationStrategy.EPUBChapterContent,
        containerSize: CGSize,
        fontSize: CGFloat,
        lineHeight: CGFloat,
        completion: @escaping ([String]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let strategy = EPUBPaginationStrategy()
            let totalPages = strategy.pageCount(for: chapter, containerSize: containerSize, fontSize: fontSize, lineHeight: lineHeight)
            var pages: [String] = []
            for page in 0..<totalPages {
                let content = strategy.contentForPage(page, in: chapter, containerSize: containerSize, fontSize: fontSize, lineHeight: lineHeight)
                pages.append(content)
            }
            DispatchQueue.main.async {
                completion(pages)
            }
        }
    }
}
