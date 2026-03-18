import SwiftUI
import Foundation

enum BookFormat: String, Codable {
    case epub
    case pdf
    case txt
    case mobi
    case azw3
    case fb2
    case unknown
    
    static func from(fileName: String) -> BookFormat {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "epub": return .epub
        case "pdf": return .pdf
        case "txt": return .txt
        case "mobi": return .mobi
        case "azw3": return .azw3
        case "fb2": return .fb2
        default: return .unknown
        }
    }
}

struct ReaderFactory {
    static func createReader(for book: Book) -> AnyView {
        let format = BookFormat.from(fileName: book.localFileName ?? "")
        
        switch format {
        case .epub:
            return AnyView(EPUBReaderView(book: book))
        case .pdf:
            return AnyView(PDFReaderView(book: book))
        case .txt:
            return AnyView(TXTReaderView(book: book))
        default:
            return AnyView(Text("Unsupported format: \(format.rawValue)"))
        }
    }
}
