import SwiftUI

struct EPUBReaderView: View {
    let book: Book
    
    @State private var epubBook: EPUBParsingService.EPUBBook?
    @State private var currentChapterIndex: Int = 0
    @State private var chapterContent: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showChapterList: Bool = false
    @State private var showSettings: Bool = false
    @State private var showContent: Bool = false
    @ObservedObject private var settings = ReaderSettings.shared
    
    @Environment(\.dismiss) private var dismiss
    
    private let parsingService = EPUBParsingService()
    
    // MARK: - 章节编号显示
    private var chapterNumberDisplay: String {
        guard let chapters = epubBook?.chapters, !chapters.isEmpty else { return "" }
        return "第 \(currentChapterIndex + 1) 章 / 共 \(chapters.count) 章"
    }
    
    private var progressPercentage: Double {
        guard let chapters = epubBook?.chapters, !chapters.isEmpty else { return 0 }
        return Double(currentChapterIndex + 1) / Double(chapters.count)
    }
    
    var body: some View {
        ZStack {
            (Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E")!)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                topToolbar
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if showContent {
                    contentView
                } else {
                    loadingView
                }
                
                bottomToolbar
            }
        }
        .navigationTitle(epubBook?.title ?? "EPUB 阅读器")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChapterList) {
            chapterListSheet
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView()
        }
        .task {
            await loadContent()
        }
        .onDisappear {
            saveReadingPosition()
        }
    }
    
    // MARK: - 顶部工具栏 - 显示完整元数据
    
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
                    Text(epubBook?.title ?? book.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let author = epubBook?.author, author != "Unknown", !author.isEmpty {
                        Text(author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else if let author = book.author, !author.isEmpty {
                        Text(author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "textformat.size")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { showChapterList = true }) {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // 元数据行
            HStack(spacing: 12) {
                if let ext = book.fileExtension?.uppercased() {
                    metadataTag(ext)
                }
                
                if let fileSize = book.fileSize {
                    metadataTag(formatFileSize(fileSize))
                }
                
                metadataTag(book.createdAt.formatted(date: .abbreviated, time: .omitted))
                
                if let chapters = epubBook?.chapters, !chapters.isEmpty {
                    metadataTag("第\(currentChapterIndex + 1)/\(chapters.count)章")
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
        .background(Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E")!)
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
    
    // MARK: - 内容视图
    
    private var contentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let chapters = epubBook?.chapters, currentChapterIndex < chapters.count {
                        let chapter = chapters[currentChapterIndex]
                        VStack(alignment: .leading, spacing: 8) {
                            Text(chapter.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: settings.currentTextColor) ?? .white)
                                .padding(.bottom, 8)
                                .id(chapter.id)
                            
                            Text(chapterContent)
                                .font(.system(size: settings.fontSize))
                                .foregroundColor(Color(hex: settings.currentTextColor) ?? .white)
                                .lineSpacing(settings.lineSpacing)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: currentChapterIndex) { _, newIndex in
                if let chapters = epubBook?.chapters, newIndex < chapters.count {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(chapters[newIndex].id, anchor: .top)
                    }
                }
            }
        }
    }
    
    // MARK: - 加载视图
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 错误视图
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("重试") {
                Task { await loadContent() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 底部工具栏
    
    private var bottomToolbar: some View {
        VStack(spacing: 8) {
            // 进度条
            if let chapters = epubBook?.chapters, !chapters.isEmpty {
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
            
            HStack(spacing: 32) {
                Button(action: previousChapter) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一章")
                    }
                }
                .disabled(currentChapterIndex <= 0)
                .buttonStyle(.bordered)
                
                Spacer()
                
                if let chapters = epubBook?.chapters, !chapters.isEmpty {
                    Text(chapterNumberDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: nextChapter) {
                    HStack(spacing: 4) {
                        Text("下一章")
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(epubBook == nil || currentChapterIndex >= (epubBook?.chapters.count ?? 1) - 1)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E")!)
    }
    
    // MARK: - 章节列表
    
    private var chapterListSheet: some View {
        NavigationStack {
            List {
                if let chapters = epubBook?.chapters {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        Button(action: {
                            currentChapterIndex = index
                            showChapterList = false
                            Task { await loadChapter(index) }
                        }) {
                            HStack {
                                Text(chapter.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                if index == currentChapterIndex {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { showChapterList = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - 加载内容 (优化版 - 先显示元数据，后加载内容)
    
    private func loadContent() async {
        isLoading = true
        errorMessage = nil
        showContent = false
        
        guard let fileName = book.localFileName else {
            errorMessage = "书籍文件未找到"
            isLoading = false
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookPath = documentsPath.appendingPathComponent("Books").appendingPathComponent(fileName)
        
        // 先尝试从缓存获取
        if let cached = await parsingService.getCachedBook(fileName: fileName) {
            epubBook = cached
            isLoading = false
            showContent = true
            
            // 恢复阅读位置 - 使用 currentChapterIndex 字段
            if book.currentChapterIndex > 0 && book.currentChapterIndex < cached.chapters.count {
                currentChapterIndex = book.currentChapterIndex
            }
            
            // 立即加载当前章节
            await loadChapter(currentChapterIndex)
            return
        }
        
        do {
            epubBook = try await parsingService.parse(fileURL: bookPath)
            
            if let parsedBook = epubBook, !parsedBook.chapters.isEmpty {
                isLoading = false
                showContent = true
                
                // 恢复阅读位置 - 使用 Book 模型的 currentChapterIndex
                if book.currentChapterIndex > 0 && book.currentChapterIndex < parsedBook.chapters.count {
                    currentChapterIndex = book.currentChapterIndex
                }
                
                // 立即加载当前章节
                await loadChapter(currentChapterIndex)
            } else {
                errorMessage = "未能解析出章节内容"
                isLoading = false
            }
        } catch {
            errorMessage = "解析失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func loadChapter(_ index: Int) async {
        guard let epub = epubBook, index < epub.chapters.count else { return }
        
        do {
            chapterContent = try await parsingService.extractChapterContent(book: epub, chapterIndex: index)
            currentChapterIndex = index
        } catch {
            chapterContent = "无法加载章节内容: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 翻页控制
    
    private func previousChapter() {
        guard currentChapterIndex > 0 else { return }
        Task {
            await loadChapter(currentChapterIndex - 1)
        }
    }
    
    private func nextChapter() {
        guard let chapters = epubBook?.chapters, currentChapterIndex < chapters.count - 1 else { return }
        Task {
            await loadChapter(currentChapterIndex + 1)
        }
    }
    
    // MARK: - 阅读进度
    
    private func saveReadingPosition() {
        book.currentPage = currentChapterIndex
        book.totalPages = epubBook?.chapters.count
        book.lastReadAt = Date()
        if let total = book.totalPages, total > 0 {
            book.readingPosition = Double(currentChapterIndex + 1) / Double(total)
        }
        // 持久化章节索引
        book.currentChapterIndex = currentChapterIndex
        if let chapters = epubBook?.chapters, currentChapterIndex < chapters.count {
            book.currentChapterTitle = chapters[currentChapterIndex].title
        }
    }
    
    // MARK: - 辅助方法
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
