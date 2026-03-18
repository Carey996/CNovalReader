import SwiftUI

struct TXTReaderView: View {
    let book: Book
    @State private var content: String = "加载中..."
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    @ObservedObject private var settings = ReaderSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    
    private let linesPerPage: Int = 30
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(hex: settings.backgroundColor) ?? .white)
            
            // 内容区域
            ScrollView {
                Text(currentPageContent)
                    .font(.system(size: settings.fontSize))
                    .foregroundColor(Color(hex: settings.textColor) ?? .black)
                    .lineSpacing(settings.lineSpacing)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(hex: settings.backgroundColor) ?? .white)
            
            // 底部翻页栏
            HStack {
                Button("上一页") {
                    if currentPage > 1 {
                        currentPage -= 1
                    }
                }
                .disabled(currentPage <= 1)
                
                Spacer()
                
                Text("\(currentPage) / \(totalPages)")
                    .font(.caption)
                
                Spacer()
                
                Button("下一页") {
                    if currentPage < totalPages {
                        currentPage += 1
                    }
                }
                .disabled(currentPage >= totalPages)
            }
            .padding()
            .background(Color(hex: settings.backgroundColor) ?? .white)
        }
        .navigationTitle("TXT 阅读器")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView()
        }
        .onAppear {
            loadContent()
            restoreReadingPosition()
        }
        .onDisappear {
            saveReadingPosition()
        }
    }
    
    private var currentPageContent: String {
        let allLines = content.components(separatedBy: .newlines)
        let startIndex = (currentPage - 1) * linesPerPage
        let endIndex = min(startIndex + linesPerPage, allLines.count)
        
        guard startIndex < allLines.count else { return "" }
        return allLines[startIndex..<endIndex].joined(separator: "\n")
    }
    
    private func loadContent() {
        guard let fileName = book.localFileName else {
            content = "未找到文件"
            return
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookPath = documentsPath.appendingPathComponent("Books").appendingPathComponent(fileName)

        guard let data = try? Data(contentsOf: bookPath) else {
            content = "无法读取文件"
            return
        }

        // 1. 优先使用 NSString 智能检测编码
        var convertedString: NSString?
        var usedLossy: ObjCBool = false
        let detectedEncoding = NSString.stringEncoding(
            for: data,
            encodingOptions: [:],
            convertedString: &convertedString,
            usedLossyConversion: &usedLossy
        )
        if detectedEncoding != 0, let str = convertedString {
            content = str as String
            let lineCount = str.components(separatedBy: "\n").count
            totalPages = max(1, (lineCount + linesPerPage - 1) / linesPerPage)
            return
        }

        // 2. Fallback：常用编码列表（NSStringEncoding raw values）
        // 4=ASCII, 0x80000003=Windows-1252, 0x6581=GBK, 0x80000431=Big5, 6=ISO-8859-1, 5=ISO-8859-2
        let fallbackEncodings: [UInt] = [0x6581, 4, 0x80000003, 0x80000431, 6, 5, 0x80000421]
        for encodingRaw in fallbackEncodings {
            let encoding = String.Encoding(rawValue: encodingRaw)
            if let str = String(data: data, encoding: encoding), !str.isEmpty {
                content = str
                let lineCount = str.components(separatedBy: "\n").count
                totalPages = max(1, (lineCount + linesPerPage - 1) / linesPerPage)
                return
            }
        }

        content = "不支持的文件编码"
    }
    
    private func saveReadingPosition() {
        book.currentPage = currentPage
        book.totalPages = totalPages
        book.lastReadAt = Date()
        book.readingPosition = Double(currentPage) / Double(totalPages)
    }
    
    private func restoreReadingPosition() {
        if let savedPage = book.currentPage, savedPage > 0, savedPage <= totalPages {
            currentPage = savedPage
        }
    }
}
