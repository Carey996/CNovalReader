import Foundation
import ZIPFoundation

/// EPUB 解析服务 - 负责解析 EPUB 文件结构
/// 优化版本：支持缓存，提高启动速度
actor EPUBParsingService {
    
    // MARK: - 缓存
    private static var bookCache: [String: EPUBBook] = [:]
    private static var contentCache: [String: [String]] = [:]
    
    // MARK: - EPUB 结构模型
    
    struct EPUBBook: Sendable {
        let title: String
        let author: String
        let coverImage: Data?
        let chapters: [Chapter]
        let spine: [String]
        let manifest: [String: ManifestItem]
        /// 基础路径 - 指向 OPF 文件所在的目录
        let basePath: URL
        /// 文件名（用于缓存键）
        let fileName: String
    }
    
    struct Chapter: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let href: String
        let order: Int
    }
    
    struct ManifestItem: Sendable {
        let id: String
        let href: String
        let mediaType: String
    }
    
    // MARK: - 错误类型
    
    enum EPUBError: Error, LocalizedError, Sendable {
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
    
    // MARK: - 获取缓存的书籍
    
    func getCachedBook(fileName: String) -> EPUBBook? {
        return Self.bookCache[fileName]
    }
    
    // MARK: - 清除缓存
    
    func clearCache() {
        Self.bookCache.removeAll()
        Self.contentCache.removeAll()
    }
    
    // MARK: - 解析入口 (优化版)
    
    func parse(fileURL: URL) async throws -> EPUBBook {
        let fileManager = FileManager.default
        let fileName = fileURL.lastPathComponent
        
        // 检查缓存
        if let cached = Self.bookCache[fileName] {
            return cached
        }
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw EPUBError.fileNotFound
        }
        
        // 使用 Documents 目录
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookId = fileName.replacingOccurrences(of: ".epub", with: "").replacingOccurrences(of: ".", with: "_")
        let epubExtractedDir = documentsDir.appendingPathComponent("ExtractedBooks").appendingPathComponent(bookId)
        
        // 检查解压目录是否存在且有效
        let containerPath = epubExtractedDir.appendingPathComponent("META-INF/container.xml")
        
        if !fileManager.fileExists(atPath: epubExtractedDir.path) || !fileManager.fileExists(atPath: containerPath.path) {
            // 删除旧目录并创建新的
            if fileManager.fileExists(atPath: epubExtractedDir.path) {
                try? fileManager.removeItem(at: epubExtractedDir)
            }
            try fileManager.createDirectory(at: epubExtractedDir, withIntermediateDirectories: true)
            
            // 使用 ZIPFoundation 解压
            try await extractZIP(from: fileURL, to: epubExtractedDir)
        }
        
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
        
        let epubBook = EPUBBook(
            title: metadata.title ?? "Unknown",
            author: metadata.creator ?? "Unknown",
            coverImage: nil,
            chapters: chapters,
            spine: spineItems,
            manifest: manifest,
            basePath: basePath,
            fileName: fileName
        )
        
        // 缓存
        Self.bookCache[fileName] = epubBook
        
        return epubBook
    }
    
    // MARK: - ZIP 解压 (使用 ZIPFoundation - 手动提取每个条目以获得更好的错误处理)
    
    private func extractZIP(from sourceURL: URL, to destinationURL: URL) async throws {
        let fileManager = FileManager.default
        
        // 确保目标目录存在
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        
        // 使用 ZIPFoundation 的 Archive API 进行更精细的控制
        guard let archive = Archive(url: sourceURL, accessMode: .read) else {
            throw EPUBError.extractionFailed("无法打开 EPUB 文件作为 ZIP 归档")
        }
        
        var entries: [(path: String, data: Data)] = []
        
        // 先收集所有条目，避免在遍历时修改 archive
        for entry in archive {
            entries.append((entry.path, Data()))
        }
        
        // 提取每个条目
        for (path, _) in entries {
            let entryPath = destinationURL.appendingPathComponent(path)
            let parentDir = entryPath.deletingLastPathComponent()
            
            // 确保父目录存在
            if !fileManager.fileExists(atPath: parentDir.path) {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            
            // 判断是文件还是目录
            if path.hasSuffix("/") {
                // 目录，创建它
                try fileManager.createDirectory(at: entryPath, withIntermediateDirectories: true)
            } else {
                // 文件，提取内容
                // 先通过路径查找 Entry 对象
                guard let zipEntry = archive[path] else {
                    throw EPUBError.extractionFailed("无法找到归档中的文件: \(path)")
                }
                
                do {
                    _ = try archive.extract(zipEntry, to: entryPath)
                } catch {
                    // 如果直接提取失败，尝试用 Data 方式提取
                    var extractedData = Data()
                    _ = try archive.extract(zipEntry) { data in
                        extractedData.append(data)
                        return ()
                    }
                    try extractedData.write(to: entryPath)
                }
            }
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
    
    struct OPFMetadata: Sendable {
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
        
        // 解析 manifest - 使用更灵活的方式查找所有 item 元素
        // 匹配格式: <item id="..." href="..." media-type="..."/> 或 <item href="..." id="..." media-type="..."/>
        let manifestPattern = #"<item\s+([^>]+)/?"#
        if let regex = try? NSRegularExpression(pattern: manifestPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
            for match in matches {
                if let attrsRange = Range(match.range(at: 1), in: xmlString) {
                    let attrsString = String(xmlString[attrsRange])
                    
                    // 提取 id 属性
                    var id: String?
                    if let idMatch = try? NSRegularExpression(pattern: #"id\s*=\s*["']([^"']+)["']"#, options: .caseInsensitive) {
                        let idMatches = idMatch.matches(in: attrsString, range: NSRange(attrsString.startIndex..., in: attrsString))
                        if let idMatchResult = idMatches.first, let idRange = Range(idMatchResult.range(at: 1), in: attrsString) {
                            id = String(attrsString[idRange])
                        }
                    }
                    
                    // 提取 href 属性
                    var href: String?
                    if let hrefMatch = try? NSRegularExpression(pattern: #"href\s*=\s*["']([^"']+)["']"#, options: .caseInsensitive) {
                        let hrefMatches = hrefMatch.matches(in: attrsString, range: NSRange(attrsString.startIndex..., in: attrsString))
                        if let hrefMatchResult = hrefMatches.first, let hrefRange = Range(hrefMatchResult.range(at: 1), in: attrsString) {
                            href = String(attrsString[hrefRange])
                        }
                    }
                    
                    // 提取 media-type 属性
                    var mediaType: String?
                    if let typeMatch = try? NSRegularExpression(pattern: #"media-type\s*=\s*["']([^"']+)["']"#, options: .caseInsensitive) {
                        let typeMatches = typeMatch.matches(in: attrsString, range: NSRange(attrsString.startIndex..., in: attrsString))
                        if let typeMatchResult = typeMatches.first, let typeRange = Range(typeMatchResult.range(at: 1), in: attrsString) {
                            mediaType = String(attrsString[typeRange])
                        }
                    }
                    
                    if let id = id, let href = href, let mediaType = mediaType {
                        manifest[id] = ManifestItem(id: id, href: href, mediaType: mediaType)
                    }
                }
            }
        }
        
        // 解析 spine - 使用更灵活的方式
        let spinePattern = #"<itemref\s+([^>]+)/?"#
        if let regex = try? NSRegularExpression(pattern: spinePattern, options: .caseInsensitive) {
            let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
            for match in matches {
                if let attrsRange = Range(match.range(at: 1), in: xmlString) {
                    let attrsString = String(xmlString[attrsRange])
                    
                    // 提取 idref 属性
                    if let idrefMatch = try? NSRegularExpression(pattern: #"idref\s*=\s*["']([^"']+)["']"#, options: .caseInsensitive) {
                        let idrefMatches = idrefMatch.matches(in: attrsString, range: NSRange(attrsString.startIndex..., in: attrsString))
                        if let idrefMatchResult = idrefMatches.first, let idrefRange = Range(idrefMatchResult.range(at: 1), in: attrsString) {
                            spineItems.append(String(attrsString[idrefRange]))
                        }
                    }
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
            // 跳过 manifest 中不存在的项
            guard let item = manifest[itemId] else { continue }
            
            // 只包含 HTML 和 XML 类型的文件
            let isHTML = item.mediaType.contains("html")
            let isXML = item.mediaType.contains("xml")
            let isXHTML = item.href.lowercased().hasSuffix(".xhtml")
            
            if isHTML || isXML || isXHTML {
                let title = (item.href as NSString).deletingPathExtension
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized
                
                chapters.append(Chapter(
                    id: "chapter_\(index)",
                    title: title,
                    href: item.href,
                    order: index
                ))
            }
        }
        
        // 如果通过 spine 没有找到章节，尝试从 manifest 中找到所有 HTML/XHTML 项目
        if chapters.isEmpty {
            for (index, item) in manifest.values.enumerated() {
                let isHTML = item.mediaType.contains("html")
                let isXML = item.mediaType.contains("xml")
                let isXHTML = item.href.lowercased().hasSuffix(".xhtml")
                
                if isHTML || isXML || isXHTML {
                    let title = (item.href as NSString).deletingPathExtension
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized
                    
                    chapters.append(Chapter(
                        id: "chapter_\(index)",
                        title: title,
                        href: item.href,
                        order: index
                    ))
                }
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
        
        // 构建缓存键
        let contentCacheKey = "\(book.fileName)_\(chapterIndex)"
        
        // 检查内容缓存
        if let cachedContent = Self.contentCache[contentCacheKey] {
            return cachedContent.joined(separator: "\n\n")
        }
        
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
        
        let plainText = stripHTMLToPlainText(htmlString)
        
        // 缓存内容
        Self.contentCache[contentCacheKey] = [plainText]
        
        return plainText
    }
    
    private func stripHTMLToPlainText(_ html: String) -> String {
        var result = html
        
        // 替换 HTML 实体（包括数字形式的）
        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&#x27;", "'"),
            ("&mdash;", "—"),
            ("&ndash;", "–"),
            ("&hellip;", "…"),
            ("&copy;", "©"),
            ("&reg;", "®"),
            ("&trade;", "™"),
            ("&lsquo;", "'"),
            ("&rsquo;", "'"),
            ("&ldquo;", "\u{201C}"),
            ("&rdquo;", "\u{201D}"),
            ("&bull;", "•"),
            ("&middot;", "·")
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // 替换数字形式的 HTML 实体
        let numericEntityPattern = #"&#([0-9]+);"#
        if let regex = try? NSRegularExpression(pattern: numericEntityPattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let numRange = Range(match.range(at: 1), in: result),
                   let codePoint = Int(result[numRange]),
                   let scalar = Unicode.Scalar(codePoint) {
                    result.replaceSubrange(range, with: String(Character(scalar)))
                }
            }
        }
        
        // 移除脚本和样式
        if let regex = try? NSRegularExpression(pattern: #"<script[^>]*>.*?</script>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        if let regex = try? NSRegularExpression(pattern: #"<style[^>]*>.*?</style>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        // 移除注释
        if let regex = try? NSRegularExpression(pattern: #"<!--.*?-->"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        // 处理常见的换行标签
        result = result.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "<br/>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "<br />", with: "\n", options: .regularExpression)
        
        // 处理段落和标题标签
        result = result.replacingOccurrences(of: "</p>", with: "\n\n")
        result = result.replacingOccurrences(of: "</div>", with: "\n")
        result = result.replacingOccurrences(of: "</h1>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h2>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h3>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h4>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h5>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h6>", with: "\n\n")
        result = result.replacingOccurrences(of: "</li>", with: "\n")
        result = result.replacingOccurrences(of: "</tr>", with: "\n")
        
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
