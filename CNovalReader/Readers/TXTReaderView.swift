import SwiftUI

// MARK: - TXT 章节模型
struct TXTChapter: Identifiable, Hashable {
    let id: String
    let title: String
    let startLine: Int
    let endLine: Int
    let content: String
}

// MARK: - TXT 阅读器 (章节滚动版)
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
    
    var body: some View {
        ZStack {
            (Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E")!)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部工具栏
                topToolbar
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    contentView
                }
                
                // 底部导航栏
                bottomToolbar
            }
        }
        .navigationTitle(chapters.isEmpty ? "TXT 阅读器" : (chapters[currentChapterIndex].title))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView()
        }
        .sheet(isPresented: $showChapterList) {
            chapterListSheet
        }
        .onAppear {
            loadContent()
        }
        .onDisappear {
            saveReadingPosition()
        }
    }
    
    // MARK: - 顶部工具栏
    
    private var topToolbar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            if !chapters.isEmpty {
                Text(chapters[currentChapterIndex].title)
                    .font(.headline)
                    .lineLimit(1)
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
        .padding()
        .background(Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E")!)
    }
    
    // MARK: - 内容视图
    
    private var contentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        VStack(alignment: .leading, spacing: 8) {
                            // 章节标题
                            Text(chapter.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: settings.currentTextColor) ?? .white)
                                .padding(.top, index == 0 ? 0 : 24)
                                .padding(.bottom, 12)
                                .id(chapter.id)
                            
                            // 章节内容
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
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollProxy?.scrollTo(chapters[newIndex].id, anchor: .top)
                }
            }
        }
        .background(Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E")!)
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
                loadContent()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 底部工具栏
    
    private var bottomToolbar: some View {
        VStack(spacing: 8) {
            if !chapters.isEmpty {
                Text("第 \(currentChapterIndex + 1) 章 / 共 \(chapters.count) 章")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    
    // MARK: - 内容加载
    
    private func loadContent() {
        isLoading = true
        errorMessage = nil
        
        guard let fileName = book.localFileName else {
            errorMessage = "未找到文件"
            isLoading = false
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookPath = documentsPath.appendingPathComponent("Books").appendingPathComponent(fileName)
        
        guard let data = try? Data(contentsOf: bookPath) else {
            errorMessage = "无法读取文件"
            isLoading = false
            return
        }
        
        // 编码检测
        var content: String?
        
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
        }
        
        // 2. Fallback：常用编码列表
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
        
        // 章节拆分
        chapters = detectChapters(from: text)
        
        // 如果没有识别到章节，创建整本书作为一个章节
        if chapters.isEmpty {
            chapters = [TXTChapter(
                id: "chapter_0",
                title: book.title,
                startLine: 0,
                endLine: text.components(separatedBy: .newlines).count,
                content: text
            )]
        }
        
        // 恢复阅读位置
        if let savedChapter = book.currentPage, savedChapter > 0, savedChapter < chapters.count {
            currentChapterIndex = savedChapter
        }
        
        isLoading = false
    }
    
    // MARK: - 章节智能检测
    
    private func detectChapters(from text: String) -> [TXTChapter] {
        var detectedChapters: [TXTChapter] = []
        let lines = text.components(separatedBy: .newlines)
        
        // 章节标题匹配模式 - 扩展的中文网络小说模式
        let chapterPatterns = [
            // 标准中文章节格式：第X章
            #"^第[零一二三四五六七八九十百千0-9〇○]+章[:：]?\s*(.*)$"#,
            // 第X回 (古风小说)
            #"^第[零一二三四五六七八九十百千0-9〇○]+回[:：]?\s*(.*)$"#,
            // 第X篇 / 第X部
            #"^第[零一二三四五六七八九十百千0-9〇○]+篇[:：]?\s*(.*)$"#,
            #"^第[零一二三四五六七八九十百千0-9〇○]+部[:：]?\s*(.*)$"#,
            // 卷X：标题 格式
            #"^卷[零一二三四五六七八九十百千0-9〇○]+[:：]\s*(.*)$"#,
            // Volume X / CHAPTER X (英文)
            #"^(Volume|CHAPTER|Chapter|vol\\.)\\s*([0-9]+)[:\\s]?(.*)$"#,
            // 第X节 / 第X小节
            #"^第[零一二三四五六七八九十百千0-9〇○]+节[:：]?\s*(.*)$"#,
            // 章节 标题 格式
            #"^章节\\s*([0-9]+)[:：]?\\s*(.*)$"#,
            // (X) 格式
            #"^\\(([0-9]+)\\)[:：]?\\s*(.*)$"#,
            // 【X】标题 格式
            #"^【([0-9零一二三四五六七八九十百千]+)】\\s*(.*)$"#,
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
            
            // 跳过空行（但记录前一个章节的结束）
            if trimmedLine.isEmpty {
                continue
            }
            
            // 检查是否匹配章节标题模式
            var isChapterTitle = false
            var chapterTitle = ""
            var chapterNumber = ""
            
            for regex in compiledPatterns {
                let range = NSRange(trimmedLine.startIndex..., in: trimmedLine)
                if let match = regex.firstMatch(in: trimmedLine, options: [], range: range) {
                    isChapterTitle = true
                    // 尝试提取标题（从捕获组）
                    if match.numberOfRanges > 1 {
                        // 尝试多个可能的捕获组
                        for groupIndex in 1..<match.numberOfRanges {
                            if let groupRange = Range(match.range(at: groupIndex), in: trimmedLine) {
                                let groupValue = String(trimmedLine[groupRange]).trimmingCharacters(in: .whitespaces)
                                if !groupValue.isEmpty && groupValue.count > chapterNumber.count {
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
            
            // 纯数字 "1." "2." 等也可能是章节标题
            if !isChapterTitle {
                let pureNumberPattern = #"^(\d+)[\.、、]\s*\S"#
                if let regex = try? NSRegularExpression(pattern: pureNumberPattern, options: []) {
                    let range = NSRange(trimmedLine.startIndex..., in: trimmedLine)
                    if let match = regex.firstMatch(in: trimmedLine, options: [], range: range) {
                        // 检查是否是章节号（后面跟着非特殊字符的内容）
                        if index + 1 < lines.count {
                            let nextLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
                            // 如果下一行是空行或很短，可能是正文开始
                            if nextLine.isEmpty || nextLine.count < 5 {
                                continue
                            }
                        }
                        isChapterTitle = true
                        chapterTitle = trimmedLine
                    }
                }
            }
            
            // 检测到章节标题
            if isChapterTitle {
                // 保存上一个章节
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
                
                // 开始新章节
                currentChapterStart = index
                chapterCounter += 1
                pendingChapterTitle = chapterTitle.isEmpty ? "第\(chapterCounter)章" : chapterTitle
            } else {
                // 非章节标题行
                // 如果还没有检测到任何章节，继续累积
                if detectedChapters.isEmpty && chapterCounter == 0 {
                    // 检查是否应该开始新章节（累积了足够多的非空行后出现的新行可能是章节标题）
                    // 这种情况较少见，暂时不处理
                }
            }
        }
        
        // 添加最后一个章节
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
        
        // 如果没有检测到章节，使用默认章节（整本书为一个章节）
        if detectedChapters.isEmpty && !lines.isEmpty {
            detectedChapters = [TXTChapter(
                id: "chapter_0",
                title: book.title,
                startLine: 0,
                endLine: lines.count,
                content: text
            )]
        }
        
        // 重新分配 ID 使其与索引对应（确保 ID 唯一）
        var finalChapters: [TXTChapter] = []
        for (index, chapter) in detectedChapters.enumerated() {
            finalChapters.append(TXTChapter(
                id: "chapter_\(index)",
                title: chapter.title,
                startLine: chapter.startLine,
                endLine: chapter.endLine,
                content: chapter.content
            ))
        }
        
        return finalChapters
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
        book.currentPage = currentChapterIndex
        book.totalPages = chapters.count
        book.lastReadAt = Date()
        if let total = book.totalPages, total > 0 {
            book.readingPosition = Double(currentChapterIndex) / Double(total)
        }
    }
}
