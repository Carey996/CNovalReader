import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let book: Book
    @State private var pdfDocument: PDFDocument?
    @State private var currentPage: Int = 1
    @State private var showSettings: Bool = false
    @ObservedObject private var settings = ReaderSettings.shared
    @Environment(\.dismiss) private var dismiss

    // MARK: - 新增状态
    @State private var isImmersive = false
    @State private var showHighlights = false

    // 阅读时长统计
    @State private var sessionStartTime: Date?

    private var progressPercentage: Double {
        guard let total = pdfDocument?.pageCount, total > 0 else { return 0 }
        return Double(currentPage) / Double(total)
    }

    var body: some View {
        ZStack {
            (Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E")!)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topToolbar
                    .opacity(isImmersive ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isImmersive)

                if let document = pdfDocument {
                    PDFKitView(document: document, currentPage: $currentPage)
                        .gesture(combinedGestures)
                } else {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                bottomToolbar
                    .opacity(isImmersive ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isImmersive)
            }

            if isImmersive {
                edgeRevealOverlay
            }
        }
        .navigationTitle("PDF 阅读器")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(isImmersive)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView()
        }
        .sheet(isPresented: $showHighlights) {
            HighlightsListView(book: book)
        }
        .task {
            await loadPDFAsync()
        }
        .onAppear {
            sessionStartTime = Date()
        }
        .onDisappear {
            saveReadingPosition()
            recordReadingTime()
        }
    }

    // MARK: - 顶部工具栏
    private var topToolbar: some View {
        VStack(spacing: 4) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.blue)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(1)

                    if let author = book.author, !author.isEmpty {
                        Text(author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    Button(action: { showHighlights = true }) {
                        Image(systemName: "highlighter")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }

                    Button(action: { showSettings = true }) {
                        Image(systemName: "textformat.size")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }

            HStack(spacing: 12) {
                if let ext = book.fileExtension?.uppercased() {
                    metadataTag(ext)
                }

                if let fileSize = book.fileSize {
                    metadataTag(formatFileSize(fileSize))
                }

                metadataTag(book.createdAt.formatted(date: .abbreviated, time: .omitted))

                if let total = pdfDocument?.pageCount, total > 0 {
                    metadataTag("第\(currentPage)/\(total)页")
                }

                if let position = book.readingPosition {
                    metadataTag("\(Int(position * 100))%")
                }

                if let remoteURL = book.remoteURL, !remoteURL.isEmpty {
                    if let host = URL(string: remoteURL)?.host {
                        metadataTag(host)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E"))
    }

    private func metadataTag(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(Color(hex: settings.currentTextColor)?.opacity(0.6) ?? .gray)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(4)
    }

    // MARK: - 手势处理
    private var combinedGestures: some Gesture {
        SimultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    handleSwipeEnd(translation: value.translation)
                },
            TapGesture(count: 2)
                .onEnded {
                    withAnimation { isImmersive.toggle() }
                }
        )
    }

    private func handleSwipeEnd(translation: CGSize) {
        let horizontal = translation.width

        if horizontal > 60 {
            // 右滑 → 上一页
            if currentPage > 1 {
                currentPage -= 1
            }
        } else if horizontal < -60 {
            // 左滑 → 下一页
            if let total = pdfDocument?.pageCount, currentPage < total {
                currentPage += 1
            }
        }
    }

    // MARK: - 边缘滑入
    private var edgeRevealOverlay: some View {
        HStack(spacing: 0) {
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                if value.translation.width > 40 {
                                    withAnimation { isImmersive = false }
                                }
                            }
                    )
            }
            .frame(width: 60)

            Spacer()

            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                if value.translation.width < -40 {
                                    withAnimation { isImmersive = false }
                                }
                            }
                    )
            }
            .frame(width: 60)
        }
    }

    // MARK: - 底部导航栏
    private var bottomToolbar: some View {
        VStack(spacing: 8) {
            if let total = pdfDocument?.pageCount, total > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)

                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * progressPercentage, height: 4)
                    }
                    .cornerRadius(2)
                }
                .frame(height: 4)
                .padding(.horizontal)
            }

            HStack {
                Button(action: { if currentPage > 1 { currentPage -= 1 } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一页")
                    }
                }
                .disabled(currentPage <= 1)
                .buttonStyle(.bordered)

                Spacer()

                if let total = pdfDocument?.pageCount, total > 0 {
                    Text("第 \(currentPage) 页 / 共 \(total) 页")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { if let total = pdfDocument?.pageCount, currentPage < total { currentPage += 1 } }) {
                    HStack(spacing: 4) {
                        Text("下一页")
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(pdfDocument == nil || currentPage >= (pdfDocument?.pageCount ?? 1))
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E"))
    }

    // MARK: - 异步加载 PDF
    private func loadPDFAsync() async {
        guard let fileName = book.localFileName else { return }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookPath = documentsPath.appendingPathComponent("Books").appendingPathComponent(fileName)

        await MainActor.run {
            if let document = PDFDocument(url: bookPath) {
                pdfDocument = document
                if let savedPage = book.currentPage, savedPage > 0 && savedPage <= document.pageCount {
                    currentPage = savedPage
                }
            }
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

    // MARK: - 阅读时长记录
    private func recordReadingTime() {
        guard let startTime = sessionStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > 5 {
            book.totalReadingTime += elapsed
            book.lastReadingTime = Date()
        }
        sessionStartTime = nil
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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
