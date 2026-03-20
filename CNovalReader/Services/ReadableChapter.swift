import Foundation

/// 统一章节协议，让 TTS 可以处理任意类型的章节
/// 让 TXT、EPUB 等不同格式的章节都可以被 TTS 朗读
public protocol ReadableChapter {
    var chapterId: String { get }
    var chapterTitle: String { get }
    var chapterContent: String { get }
}

// MARK: - TXTChapter 符合 ReadableChapter 协议
extension TXTChapter: ReadableChapter {
    public var chapterId: String { id }
    public var chapterTitle: String { title }
    public var chapterContent: String { content }
}

// MARK: - PDFPageChapter 符合 ReadableChapter 协议
struct PDFPageChapter: ReadableChapter {
    let chapterId: String
    let chapterTitle: String
    let chapterContent: String
}
