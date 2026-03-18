import Foundation
import ZIPFoundation

/// EPUB 解析服务 - 负责解析 EPUB 文件结构
actor EPUBParsingService {
    
    // MARK: - EPUB 结构模型
    
    struct EPUBBook {
        let title: String
        let author: String
        let coverImage: Data?
        let chapters: [Chapter]
        let spine: [String]
        let manifest: [String: ManifestItem]
        /// 基础路径 - 指向 OPF 文件所在的目录
        let basePath: URL
    }
    
    struct Chapter: Identifiable, Hashable {
        let id: String
        let title: String
        let href: String
        let order: Int
    }
    
    struct ManifestItem {
        let id: String
        let href: String
        let mediaType: String
    }
    
    // MARK: - 错误类型
    
    enum EPUBError: Error, LocalizedError {
        case fileNotFound
        case invalidEPUB
        case missingContainer
        case missingOPF
        case parsingFailed(String)
        case extractionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "EPUB 文件未找到"
            case .invalidEPUB:
                return "无效的 EPUB 文件格式"
            case .missingContainer:
                return "缺少 container.xml 文件"
            case .missingOPF:
                return "找不到内容.opf 文件"
            case .parsingFailed(let reason):
                return "解析失败: \(reason)"
            case .extractionFailed(let reason):
                return "解压失败: \(reason)"
            }
        }
    }
    
    // MARK: - 解析入口
    
    func parse(fileURL: URL) async throws -> EPUBBook {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw EPUBError.fileNotFound
        }
        
        // 使用 Documents 目录
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookId = fileURL.lastPathComponent.replacingOccurrences(of: ".epub", with: "").replacingOccurrences(of: ".", with: "_")
        let epubExtractedDir = documentsDir.appendingPathComponent("ExtractedBooks").appendingPathComponent(bookId)
        
        // 删除旧目录并创建新的
        if fileManager.fileExists(atPath: epubExtractedDir.path) {
            try? fileManager.removeItem(at: epubExtractedDir)
        }
        try fileManager.createDirectory(at: epubExtractedDir, withIntermediateDirectories: true)
        
        // 使用 ZIPFoundation 解压
        try await extractZIP(from: fileURL, to: epubExtractedDir)
        
        // 验证解压结果
        guard let contents = try? fileManager.contentsOfDirectory(atPath: epubExtractedDir.path),
              !contents.isEmpty else {
            throw EPUBError.extractionFailed("无法解压 EPUB 文件")
        }
        
        // 查找 rootfile
        let rootFilePath = try await findRootFile(in: epubExtractedDir)
        let rootFileURL = epubExtractedDir.appendingPathComponent(rootFilePath)
        
        // 基础路径应该是 OPF 文件所在的目录
        let basePath = rootFileURL.deletingLastPathComponent()
        
        // 解析 OPF
        let (metadata, manifest, spineItems) = try await parseOPF(at: rootFileURL)
        let chapters = buildChapters(manifest: manifest, spine: spineItems)
        
        return EPUBBook(
            title: metadata.title ?? "Unknown",
            author: metadata.creator ?? "Unknown",
            coverImage: nil,
            chapters: chapters,
            spine: spineItems,
            manifest: manifest,
            basePath: basePath
        )
    }
    
    // MARK: - ZIP 解压 (使用 ZIPFoundation)
    
    private func extractZIP(from sourceURL: URL, to destinationURL: URL) async throws {
        let fileManager = FileManager.default
        
        // 确保目标目录存在
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        
        // 使用 ZIPFoundation 解压
        do {
            try fileManager.unzipItem(at: sourceURL, to: destinationURL)
        } catch {
            throw EPUBError.extractionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - OPF 解析
    
    private func findRootFile(in baseURL: URL) async throws -> String {
        let containerPath = baseURL.appendingPathComponent("META-INF/container.xml")
        
        guard FileManager.default.fileExists(atPath: containerPath.path) else {
            throw EPUBError.missingContainer
        }
        
        let containerData = try Data(contentsOf: containerPath)
        
        guard let xmlString = String(data: containerData, encoding: .utf8) else {
            throw EPUBError.parsingFailed("无法解析 container.xml")
        }
        
        // 使用正则表达式查找 full-path 属性
        guard let regex = try? NSRegularExpression(pattern: #"full-path="([^"]+)""#, options: .caseInsensitive) else {
            throw EPUBError.missingOPF
        }
        
        let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
        
        guard let match = matches.first,
              let range = Range(match.range(at: 1), in: xmlString) else {
            throw EPUBError.missingOPF
        }
        
        return String(xmlString[range])
    }
    
    struct OPFMetadata {
        var title: String?
        var creator: String?
    }
    
    private func parseOPF(at opfURL: URL) async throws -> (OPFMetadata, [String: ManifestItem], [String]) {
        let opfData = try Data(contentsOf: opfURL)
        
        guard let xmlString = String(data: opfData, encoding: .utf8) else {
            throw EPUBError.parsingFailed("无法读取 OPF 文件")
        }
        
        var metadata = OPFMetadata()
        var manifest: [String: ManifestItem] = [:]
        var spineItems: [String] = []
        
        // 解析 title - 支持 dc:title 和 title
        if let title = extractXMLValue(from: xmlString, tag: "dc:title") ?? extractXMLValue(from: xmlString, tag: "title") {
            metadata.title = title
        }
        
        // 解析 creator - 支持 dc:creator 和 creator
        if let creator = extractXMLValue(from: xmlString, tag: "dc:creator") ?? extractXMLValue(from: xmlString, tag: "creator") {
            metadata.creator = creator
        }
        
        // 解析 manifest - 查找所有 item 元素
        let manifestPattern = #"<item[^>]+id="([^"]+)"[^>]+href="([^"]+)"[^>]+media-type="([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: manifestPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: xmlString),
                   let hrefRange = Range(match.range(at: 2), in: xmlString),
                   let typeRange = Range(match.range(at: 3), in: xmlString) {
                    let id = String(xmlString[idRange])
                    manifest[id] = ManifestItem(
                        id: id,
                        href: String(xmlString[hrefRange]),
                        mediaType: String(xmlString[typeRange])
                    )
                }
            }
        }
        
        // 解析 spine
        let spinePattern = #"<itemref[^>]+idref="([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: spinePattern, options: .caseInsensitive) {
            let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
            for match in matches {
                if let idrefRange = Range(match.range(at: 1), in: xmlString) {
                    spineItems.append(String(xmlString[idrefRange]))
                }
            }
        }
        
        return (metadata, manifest, spineItems)
    }
    /// 从 XML 中提取标签内容
    private func extractXMLValue(from xml: String, tag: String) -> String? {
        // 支持带命名空间和不带命名空间的标签
        let patterns = [
            "<\(tag)[^>]*>([^<]+)</\(tag)>",
            "<\(tag)>([^<]+)</\(tag)>"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
                if let match = matches.first, let range = Range(match.range(at: 1), in: xml) {
                    return String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }
    
    private func buildChapters(manifest: [String: ManifestItem], spine: [String]) -> [Chapter] {
        var chapters: [Chapter] = []
        
        for (index, itemId) in spine.enumerated() {
            guard let item = manifest[itemId] else { continue }
            
            // 只包含 HTML 和 XML 类型的文件
            if item.mediaType.contains("html") || item.mediaType.contains("xml") || item.href.hasSuffix(".xhtml") {
                let title = (item.href as NSString).deletingPathExtension
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized
                
                chapters.append(Chapter(
                    id: itemId,
                    title: title,
                    href: item.href,
                    order: index
                ))
            }
        }
        
        return chapters
    }
    
    // MARK: - 内容提取
    
    func extractChapterContent(book: EPUBBook, chapterIndex: Int) async throws -> String {
        guard chapterIndex >= 0 && chapterIndex < book.chapters.count else {
            throw EPUBError.parsingFailed("无效的章节索引")
        }
        
        let chapter = book.chapters[chapterIndex]
        
        // 相对于 basePath (即 OPF 文件所在目录) 解析章节路径
        let chapterURL = book.basePath.appendingPathComponent(chapter.href)
        
        // 验证文件存在
        guard FileManager.default.fileExists(atPath: chapterURL.path) else {
            throw EPUBError.parsingFailed("找不到章节文件: \(chapter.href)")
        }
        
        let htmlData = try Data(contentsOf: chapterURL)
        
        guard let htmlString = String(data: htmlData, encoding: .utf8) else {
            throw EPUBError.parsingFailed("无法读取章节内容")
        }
        
        return stripHTMLToPlainText(htmlString)
    }
    
    private func stripHTMLToPlainText(_ html: String) -> String {
        var result = html
        
        // 替换 HTML 实体
        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&mdash;", "—"),
            ("&ndash;", "–"),
            ("&hellip;", "…"),
            ("&copy;", "©"),
            ("&reg;", "®"),
            ("&trade;", "™")
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // 移除脚本和样式
        if let regex = try? NSRegularExpression(pattern: #"<script[^>]*>.*?</script>"#, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        if let regex = try? NSRegularExpression(pattern: #"<style[^>]*>.*?</style>"#, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        // 移除注释
        if let regex = try? NSRegularExpression(pattern: #"<!--.*?-->"#, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        // 处理换行标签
        result = result.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "</p>", with: "\n\n")
        result = result.replacingOccurrences(of: "</div>", with: "\n")
        result = result.replacingOccurrences(of: "</h1>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h2>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h3>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h4>", with: "\n\n")
        
        // 移除所有 HTML 标签
        if let regex = try? NSRegularExpression(pattern: #"<[^>]+>"#) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        // 清理多余的空白
        result = result.replacingOccurrences(of: "\n+", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
