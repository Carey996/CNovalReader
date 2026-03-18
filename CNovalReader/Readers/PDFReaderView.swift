import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let book: Book
    @State private var pdfDocument: PDFDocument?
    @State private var currentPage: Int = 1
    @State private var showSettings: Bool = false
    @ObservedObject private var settings = ReaderSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
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
            
            if let document = pdfDocument {
                PDFKitView(document: document, currentPage: $currentPage)
            } else {
                ProgressView("加载中...")
            }
            
            if let document = pdfDocument {
                HStack {
                    Button("上一页") {
                        if currentPage > 1 {
                            currentPage -= 1
                        }
                    }
                    .disabled(currentPage <= 1)
                    
                    Spacer()
                    
                    Text("第 \(currentPage) 页 / 共 \(document.pageCount) 页")
                        .font(.caption)
                    
                    Spacer()
                    
                    Button("下一页") {
                        if currentPage < document.pageCount {
                            currentPage += 1
                        }
                    }
                    .disabled(currentPage >= document.pageCount)
                }
                .padding()
                .background(Color(hex: settings.backgroundColor) ?? .white)
            }
        }
        .navigationTitle("PDF 阅读器")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView()
        }
        .onAppear {
            loadPDF()
            restoreReadingPosition()
        }
        .onDisappear {
            saveReadingPosition()
        }
    }
    
    private func loadPDF() {
        guard let fileName = book.localFileName else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookPath = documentsPath.appendingPathComponent("Books").appendingPathComponent(fileName)
        
        if let document = PDFDocument(url: bookPath) {
            pdfDocument = document
        }
    }
    
    private func saveReadingPosition() {
        book.currentPage = currentPage
        book.totalPages = pdfDocument?.pageCount
        book.lastReadAt = Date()
        if let total = book.totalPages, total > 0 {
            book.readingPosition = Double(currentPage) / Double(total)
        }
    }
    
    private func restoreReadingPosition() {
        if let savedPage = book.currentPage, savedPage > 0 {
            currentPage = savedPage
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let page = document.page(at: currentPage - 1) {
            pdfView.go(to: page)
        }
    }
}
