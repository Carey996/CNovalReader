import SwiftUI

// MARK: - TXT 章节模型
struct TXTChapter: Identifiable, Hashable {
    let id: String
    let title: String
    let startLine: Int
    let endLine: Int
    let content: String
}

// MARK: - 章节智能检测 (独立函数，可在任何上下文中调用)
private func detectChaptersFromText(_ text: String, bookTitle: String) -> [TXTChapter] {
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

// MARK: - TXT 阅读器 (章节滚动版 - 异步加载优化)
struct TXTReaderView: View {
    let book: Book
    @State private var chapters: [TXTChapter] = []
    @State private var currentChapterIndex: Int = 0
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @ObservedObject private var settings = ReaderSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    @State private var showChapterList = false
    @State private var scrollProxy: ScrollViewProxy?
    
    private var chapterNumberDisplay: String {
        guard !chapters.isEmpty else { return "" }
        return "第 \(currentChapterIndex + 1) 章 / 共 \(chapters.count) 章"
    }
    
    private var chapterTitleDisplay: String {
        guard currentChapterIndex < chapters.count else { return "" }
        return chapters[currentChapterIndex].title
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
                } else {
                    contentView
                }
                
                bottomToolbar
            }
        }
        .navigationTitle(chapters.isEmpty ? "TXT 阅读器" : chapterTitleDisplay)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView()
        }
        .sheet(isPresented: $showChapterList) {
            chapterListSheet
        }
        .task {
            await loadContentAsync()
        }
        .onDisappear {
            saveReadingPosition()
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
                    Button(action: { showChapterList = true }) {
                        Image(systemName: "list.bullet")
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
                
                if let total = book.totalPages, total > 0 {
                    metadataTag("第\(currentChapterIndex + 1)/\(total)章")
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
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(chapter.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: settings.currentTextColor) ?? .white)
                                .padding(.top, index == 0 ? 0 : 24)
                                .padding(.bottom, 12)
                                .id(chapter.id)
                            
                            Text(chapter.content)
                                .font(.system(size: settings.fontSize))
                                .foregroundColor(Color(hex: settings.currentTextColor) ?? .white)
                                .lineSpacing(settings.lineSpacing)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
                .padding(.vertical, 12)
            }
            .onAppear {
                self.scrollProxy = proxy
            }
            .onChange(of: currentChapterIndex) { _, newIndex in
                guard newIndex < chapters.count else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(chapters[newIndex].id, anchor: .top)
                }
            }
        }
        .background(Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E")!)
    }
    
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
                Task { await loadContentAsync() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 底部工具栏
    
    private var bottomToolbar: some View {
        VStack(spacing: 8) {
            if !chapters.isEmpty {
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
                Button(action: previousChapter) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一章")
                    }
                }
                .disabled(currentChapterIndex <= 0)
                .buttonStyle(.bordered)
                
                Spacer()
                
                if !chapters.isEmpty {
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
                .disabled(chapters.isEmpty || currentChapterIndex >= chapters.count - 1)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E")!)
    }
    
    private var progressPercentage: Double {
        guard !chapters.isEmpty else { return 0 }
        return Double(currentChapterIndex + 1) / Double(chapters.count)
    }
    
    // MARK: - 章节列表
    
    private var chapterListSheet: some View {
        NavigationStack {
            List {
                if chapters.isEmpty {
                    Text("未能识别章节")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        Button(action: {
                            currentChapterIndex = index
                            showChapterList = false
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
    
    // MARK: - 异步内容加载 (优化版 - 不卡 UI)
    
    private func loadContentAsync() async {
        isLoading = true
        errorMessage = nil
        
        guard let fileName = book.localFileName else {
            errorMessage = "未找到文件"
            isLoading = false
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookPath = documentsPath.appendingPathComponent("Books").appendingPathComponent(fileName)
        
        // 先尝试从 Book 模型恢复章节信息（快速路径）
        let savedChapters = loadPersistedChapters()
        
        if let persisted = savedChapters, !persisted.isEmpty {
            // 有缓存的章节，快速显示 UI
            isLoading = false
            
            if book.currentChapterIndex > 0 && book.currentChapterIndex < persisted.count {
                currentChapterIndex = book.currentChapterIndex
            }
            
            // 后台加载完整内容和章节详情
            Task.detached(priority: .userInitiated) { [bookPath, persisted, bookID = book.id] in
                await self.loadChaptersWithContent(bookPath: bookPath, persistedChapters: persisted, bookID: bookID)
            }
            return
        }
        
        // 无缓存，需要完整解析
        await parseAndLoadContent(bookPath: bookPath)
    }
    
    @MainActor
    private func loadChaptersWithContent(bookPath: URL, persistedChapters: [PersistedChapterInfo], bookID: UUID) async {
        do {
            let data = try Data(contentsOf: bookPath)
            
            var content: String?
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
            }
            
            if content == nil {
                let fallbackEncodings: [UInt] = [0x6581, 4, 0x80000003, 0x80000431, 6, 5, 0x80000421]
                for encodingRaw in fallbackEncodings {
                    let encoding = String.Encoding(rawValue: encodingRaw)
                    if let str = String(data: data, encoding: encoding), !str.isEmpty {
                        content = str
                        break
                    }
                }
            }
            
            guard let text = content else { return }
            
            let lines = text.components(separatedBy: .newlines)
            
            let rebuiltChapters = persistedChapters.map { persisted -> TXTChapter in
                let endLine = min(persisted.endLine, lines.count)
                let startLine = min(persisted.startLine, endLine)
                let chapterContent = lines[startLine..<endLine].joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return TXTChapter(
                    id: persisted.id,
                    title: persisted.title,
                    startLine: persisted.startLine,
                    endLine: persisted.endLine,
                    content: chapterContent
                )
            }
            
            self.chapters = rebuiltChapters
            
        } catch {
            // 如果恢复失败，重新完整解析
            await parseAndLoadContent(bookPath: bookPath)
        }
    }
    
    private func parseAndLoadContent(bookPath: URL) async {
        isLoading = true
        
        do {
            let data = try Data(contentsOf: bookPath)
            
            var content: String?
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
            }
            
            if content == nil {
                let fallbackEncodings: [UInt] = [0x6581, 4, 0x80000003, 0x80000431, 6, 5, 0x80000421]
                for encodingRaw in fallbackEncodings {
                    let encoding = String.Encoding(rawValue: encodingRaw)
                    if let str = String(data: data, encoding: encoding), !str.isEmpty {
                        content = str
                        break
                    }
                }
            }
            
            guard let text = content else {
                errorMessage = "不支持的文件编码"
                isLoading = false
                return
            }
            
            let bookTitle = book.title
            
            let parsedChapters = detectChaptersFromText(text, bookTitle: bookTitle)
            
            var finalChapters = parsedChapters
            if finalChapters.isEmpty {
                finalChapters = [TXTChapter(
                    id: "chapter_0",
                    title: bookTitle,
                    startLine: 0,
                    endLine: text.components(separatedBy: .newlines).count,
                    content: text
                )]
            }
            
            persistChapters(finalChapters)
            
            if book.currentChapterIndex > 0 && book.currentChapterIndex < finalChapters.count {
                currentChapterIndex = book.currentChapterIndex
            }
            
            chapters = finalChapters
            isLoading = false
            
        } catch {
            errorMessage = "无法读取文件: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - 章节持久化
    
    private func persistChapters(_ chapters: [TXTChapter]) {
        let persisted = chapters.map {
            PersistedChapterInfo(id: $0.id, title: $0.title, startLine: $0.startLine, endLine: $0.endLine)
        }
        if let data = try? JSONEncoder().encode(persisted) {
            book.chaptersData = data
        }
    }
    
    private func loadPersistedChapters() -> [PersistedChapterInfo]? {
        guard let data = book.chaptersData,
              let chapters = try? JSONDecoder().decode([PersistedChapterInfo].self, from: data),
              !chapters.isEmpty else {
            return nil
        }
        return chapters
    }
    
    // MARK: - 翻页控制
    
    private func previousChapter() {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
    }
    
    private func nextChapter() {
        guard currentChapterIndex < chapters.count - 1 else { return }
        currentChapterIndex += 1
    }
    
    // MARK: - 阅读进度
    
    private func saveReadingPosition() {
        book.currentChapterIndex = currentChapterIndex
        book.totalPages = chapters.count
        book.lastReadAt = Date()
        if !chapters.isEmpty {
            book.currentPage = currentChapterIndex
            book.readingPosition = Double(currentChapterIndex + 1) / Double(chapters.count)
            if currentChapterIndex < chapters.count {
                book.currentChapterTitle = chapters[currentChapterIndex].title
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
