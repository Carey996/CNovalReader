import SwiftUI

// MARK: - TXT 阅读器 (翻页/滚动双模式)
struct TXTReaderView: View {
    let book: Book
    @State private var chapters: [TXTChapter] = []
    @State private var currentChapterIndex: Int = 0
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @ObservedObject private var settings = ReaderSettings.shared
    @Environment(\.dismiss) private var dismiss

    // MARK: - 新增状态
    @State private var showSettings = false
    @State private var showChapterList = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isImmersive = false

    // 高亮/书签
    @State private var showHighlights = false
    @State private var showTextMenu = false
    @State private var selectedText = ""
    @State private var textMenuPosition: CGPoint = .zero
    @State private var currentHighlightChapter: Int = 0

    // 搜索
    @State private var showSearch = false

    // 手势状态
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    // 阅读时长统计
    @State private var sessionStartTime: Date?
    
    // TTS
    @StateObject private var ttsService = TTSService.shared
    @State private var showTTSSettings = false
    
    // MARK: - 翻页模式状态
    @State private var pageModeCurrentPage: Int = 0
    @State private var pageModeTotalPages: Int = 0
    @State private var pageModePages: [String] = []
    @State private var pageModeContainerSize: CGSize = .zero
    @State private var pageModeOffset: CGFloat = 0
    @State private var isAnimatingPage: Bool = false

    private var chapterNumberDisplay: String {
        guard !chapters.isEmpty else { return "" }
        if settings.pageTurnMode && pageModeTotalPages > 0 {
            return "第 \(pageModeCurrentPage + 1) / \(pageModeTotalPages) 页"
        }
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
                // 顶部工具栏
                topToolbar
                    .opacity(isImmersive ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isImmersive)

                // 内容区
                contentArea
                    .gesture(combinedGestures)

                // 底部工具栏
                bottomToolbar
                    .opacity(isImmersive ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isImmersive)
            }

            // 文本选择菜单
            if showTextMenu {
                TextSelectionMenu(
                    commands: textCommands,
                    showMenu: $showTextMenu
                )
                .transition(.opacity)
            }

            // 边缘滑入检测（左/右边缘滑入显示工具栏）
            if isImmersive {
                edgeRevealOverlay
            }
            
            // TTS 控制条
            if ttsService.isPlaying || ttsService.isPaused {
                ttsControlBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(chapters.isEmpty ? "TXT 阅读器" : chapterTitleDisplay)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(isImmersive)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView()
        }
        .sheet(isPresented: $showChapterList) {
            chapterListSheet
        }
        .sheet(isPresented: $showHighlights) {
            HighlightsListView(book: book)
        }
        .sheet(isPresented: $showSearch) {
            InBookSearchView(
                book: book,
                chapters: chapters,
                onJumpToChapter: { chapterIndex, _, _ in
                    currentChapterIndex = chapterIndex
                    showSearch = false
                }
            )
        }
        .sheet(isPresented: $showTTSSettings) {
            TTSSettingsView()
        }
        .onChange(of: chapters.count) { _, newCount in
            if newCount > 0 {
                ttsService.configure(chapters: chapters, startChapter: currentChapterIndex)
            }
        }
        .onChange(of: currentChapterIndex) { _, newIndex in
            ttsService.configure(chapters: chapters, startChapter: newIndex)
            if settings.pageTurnMode {
                resetPageMode(for: newIndex)
            }
        }
        .onChange(of: settings.fontSize) { _, _ in
            if settings.pageTurnMode {
                recomputePages()
            }
        }
        .onChange(of: settings.lineSpacing) { _, _ in
            if settings.pageTurnMode {
                recomputePages()
            }
        }
        .task {
            await loadContentAsync()
        }
        .onAppear {
            sessionStartTime = Date()
        }
        .onDisappear {
            saveReadingPosition()
            recordReadingTime()
        }
    }

    // MARK: - 内容区域（翻页 vs 滚动）
    @ViewBuilder
    private var contentArea: some View {
        if settings.pageTurnMode {
            pageTurnContentView
        } else {
            contentScrollView
        }
    }
    
    // MARK: - 翻页模式内容视图
    private var pageTurnContentView: some View {
        GeometryReader { geo in
            let containerSize = geo.size
            
            ZStack {
                if pageModePages.isEmpty {
                    // 加载中
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("计算分页中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if pageModeCurrentPage < pageModePages.count {
                    let currentContent = pageModePages[pageModeCurrentPage]
                    
                    VStack(alignment: .leading, spacing: 0) {
                        // 章节标题（仅第一页显示）
                        if pageModeCurrentPage == 0 {
                            Text(chapters[currentChapterIndex].title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: settings.currentTextColor) ?? .white)
                                .padding(.bottom, 12)
                        }
                        
                        // 页面内容
                        Text(currentContent)
                            .font(.system(size: settings.fontSize))
                            .foregroundColor(Color(hex: settings.currentTextColor) ?? .white)
                            .lineSpacing(settings.lineSpacing)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .offset(x: pageModeOffset)
                    .gesture(pageDragGesture)
                    .animation(.interactiveSpring(), value: pageModeOffset)
                }
                
                // 页码指示器
                if settings.pagesModeShowProgress && pageModeTotalPages > 0 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(pageModeCurrentPage + 1) / \(pageModeTotalPages)")
                                .font(.caption)
                                .foregroundColor(Color(hex: settings.currentTextColor)?.opacity(0.5) ?? .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .padding(.trailing, 16)
                                .padding(.bottom, 16)
                        }
                    }
                }
            }
            .frame(width: containerSize.width, height: containerSize.height)
            .background(Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E")!)
            .onAppear {
                if pageModeContainerSize != containerSize {
                    pageModeContainerSize = containerSize
                    recomputePages()
                }
            }
            .onChange(of: containerSize) { _, newSize in
                pageModeContainerSize = newSize
                recomputePages()
            }
        }
    }
    
    // MARK: - 翻页拖拽手势
    private var pageDragGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                guard !isAnimatingPage else { return }
                pageModeOffset = value.translation.width
            }
            .onEnded { value in
                guard !isAnimatingPage else { return }
                let threshold: CGFloat = 60
                withAnimation(.interactiveSpring()) {
                    if value.translation.width > threshold {
                        // 右滑 → 上一页
                        goToPreviousPage()
                    } else if value.translation.width < -threshold {
                        // 左滑 → 下一页
                        goToNextPage()
                    }
                    pageModeOffset = 0
                }
            }
    }
    
    // MARK: - 翻页控制
    private func goToNextPage() {
        guard pageModeCurrentPage < pageModeTotalPages - 1 else {
            // 最后一页 → 下一章
            if currentChapterIndex < chapters.count - 1 {
                currentChapterIndex += 1
                resetPageMode(for: currentChapterIndex)
            }
            return
        }
        isAnimatingPage = true
        pageModeCurrentPage += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimatingPage = false
        }
    }
    
    private func goToPreviousPage() {
        guard pageModeCurrentPage > 0 else {
            // 第一页 → 上一章
            if currentChapterIndex > 0 {
                currentChapterIndex -= 1
                resetPageMode(for: currentChapterIndex)
            }
            return
        }
        isAnimatingPage = true
        pageModeCurrentPage -= 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimatingPage = false
        }
    }
    
    // MARK: - 重置分页状态
    private func resetPageMode(for chapterIndex: Int) {
        guard chapterIndex < chapters.count else { return }
        pageModeCurrentPage = 0
        pageModeOffset = 0
        recomputePages()
    }
    
    // MARK: - 重新计算分页（先确保章节内容已加载）
    private func recomputePages() {
        guard currentChapterIndex < chapters.count else { return }
        guard pageModeContainerSize.height > 0 else { return }

        let chapter = chapters[currentChapterIndex]

        // 如果内容未加载，先加载内容再计算分页
        if chapter._content == nil || chapter._content?.isEmpty == true {
            Task { @MainActor in
                await self.preloadChapter(at: self.currentChapterIndex)
                self.computePagesForCurrentChapter()
            }
            return
        }

        computePagesForCurrentChapter()
    }

    @MainActor
    private func computePagesForCurrentChapter() {
        guard currentChapterIndex < chapters.count else { return }
        guard pageModeContainerSize.height > 0 else { return }

        let chapter = chapters[currentChapterIndex]
        let fontSize = CGFloat(settings.fontSize)
        let lineHeight = fontSize + settings.lineSpacing
        let content = chapter._content ?? ""

        PaginationCalculator.precomputeTXTPagesFromContent(
            content: content,
            containerSize: pageModeContainerSize,
            fontSize: fontSize,
            lineHeight: lineHeight
        ) { [self] pages in
            pageModePages = pages
            pageModeTotalPages = pages.count
            // 确保当前页不越界
            if pageModeCurrentPage >= pageModeTotalPages && pageModeTotalPages > 0 {
                pageModeCurrentPage = pageModeTotalPages - 1
            }
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

                    Button(action: { showChapterList = true }) {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }

                    Button(action: { showSearch = true }) {
                        Image(systemName: "magnifyingglass")
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

                if !chapters.isEmpty {
                    if settings.pageTurnMode {
                        metadataTag("第\(pageModeCurrentPage + 1)/\(max(1, pageModeTotalPages))页")
                    } else {
                        metadataTag("第\(currentChapterIndex + 1)/\(chapters.count)章")
                    }
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

    // MARK: - 滚动模式内容视图（惰性加载章节内容）
    private var contentScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        ChapterContentView(
                            chapter: chapter,
                            chapterIndex: index,
                            fontSize: settings.fontSize,
                            textColor: settings.currentTextColor,
                            lineSpacing: settings.lineSpacing,
                            onLoadContent: { loadedContent in
                                // 内容加载完成后更新 chapters 数组
                                Task { @MainActor in
                                    guard index < self.chapters.count else { return }
                                    var updated = self.chapters[index]
                                    updated._content = loadedContent
                                    self.chapters[index] = updated
                                }
                            }
                        )
                        .id(chapter.id)
                    }
                }
                .padding(.vertical, 12)
            }
            .coordinateSpace(name: "scroll")
            .onAppear {
                self.scrollProxy = proxy
            }
            .onChange(of: currentChapterIndex) { _, newIndex in
                guard newIndex < chapters.count else { return }
                // 切换章节时预加载该章节内容
                Task { @MainActor in
                    await self.preloadChapter(at: newIndex)
                }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(chapters[newIndex].id, anchor: .top)
                }
            }
        }
        .background(Color(hex: settings.currentBackgroundColor) ?? Color(hex: "#1C1C1E")!)
    }

    // MARK: - 手势处理
    private var combinedGestures: some Gesture {
        SimultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    handleSwipeEnd(translation: value.translation)
                    dragOffset = .zero
                },
            TapGesture(count: 2)
                .onEnded {
                    withAnimation {
                        isImmersive.toggle()
                    }
                }
        )
    }

    private func handleSwipeEnd(translation: CGSize) {
        // 翻页模式下不处理章节级别的滑动
        guard !settings.pageTurnMode else { return }
        
        let horizontal = translation.width
        let vertical = translation.height

        if abs(horizontal) > abs(vertical) {
            if horizontal > 60 {
                previousChapter()
            } else if horizontal < -60 {
                nextChapter()
            }
        } else {
            if vertical > 80 {
                nextChapter()
            }
        }
    }

    // MARK: - 边缘滑入显示工具栏
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

    // MARK: - 文本菜单命令
    private var textCommands: [TextSelectionCommand] {
        [
            TextSelectionCommand(title: "高亮", systemImage: "highlighter") {
                addHighlight()
            },
            TextSelectionCommand(title: "添加书签", systemImage: "bookmark") {
                addBookmark()
            },
            TextSelectionCommand(title: "添加笔记", systemImage: "note.text") {
                addNote()
            }
        ]
    }

    // MARK: - 高亮/书签操作
    private func addHighlight() {
        if currentChapterIndex < chapters.count {
            let chapter = chapters[currentChapterIndex]
            let content = chapter._content ?? ""
            let text = content.prefix(50)
            let highlight = Highlight(
                text: String(text),
                chapterIndex: currentChapterIndex,
                rangeStart: 0,
                rangeEnd: min(50, content.count)
            )
            var highlights = book.highlights
            highlights.append(highlight)
            book.highlights = highlights
        }
    }

    private func addBookmark() {
        let bookmark = Bookmark(
            chapterIndex: currentChapterIndex,
            text: chapters.isEmpty ? "" : chapters[currentChapterIndex].title
        )
        var bookmarks = book.bookmarks
        bookmarks.append(bookmark)
        book.bookmarks = bookmarks
    }

    private func addNote() {
        addHighlight()
    }

    // MARK: - TTS 控制条
    private var ttsControlBar: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 3)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * ttsService.progress, height: 3)
                }
                .cornerRadius(1.5)
            }
            .frame(height: 3)
            .padding(.horizontal)
            .padding(.top, 8)
            
            HStack(spacing: 20) {
                Button(action: { ttsService.previousChapter() }) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .disabled(ttsService.currentChapterIndex <= 0)
                
                Button(action: {
                    if ttsService.isPlaying {
                        ttsService.pause()
                    } else {
                        ttsService.play()
                    }
                }) {
                    Image(systemName: ttsService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                
                Button(action: { ttsService.nextChapter() }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .disabled(ttsService.currentChapterIndex >= chapters.count - 1)
                
                Spacer()
                
                Text("第 \(ttsService.currentChapterIndex + 1) 章 / 共 \(chapters.count) 章")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { showTTSSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
                
                Button(action: { ttsService.stop() }) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16, corners: [.topLeft, .topRight])
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
        if settings.pageTurnMode {
            guard pageModeTotalPages > 0 else { return 0 }
            let chapterProgress = Double(currentChapterIndex) / Double(chapters.count)
            let pageInChapter = Double(pageModeCurrentPage) / Double(pageModeTotalPages)
            return chapterProgress + (pageInChapter / Double(chapters.count))
        }
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

    // MARK: - 异步内容加载
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

        let savedChapters = loadPersistedChapters()

        if let persisted = savedChapters, !persisted.isEmpty {
            isLoading = false

            if book.currentChapterIndex > 0 && book.currentChapterIndex < persisted.count {
                currentChapterIndex = book.currentChapterIndex
            }

            Task.detached(priority: .userInitiated) { [bookPath, persisted, bookID = book.id] in
                await self.loadChaptersWithContent(bookPath: bookPath, persistedChapters: persisted, bookID: bookID)
            }
            return
        }

        await parseAndLoadContent(bookPath: bookPath)
    }

    @MainActor
    private func loadChaptersWithContent(bookPath: URL, persistedChapters: [PersistedChapterInfo], bookID: UUID) async {
        let filePath = bookPath.path

        // 1. 检测编码（先读 4KB 头部）
        let encoding = await detectEncoding(bookPath: bookPath)
        guard let enc = encoding else {
            await parseAndLoadContent(bookPath: bookPath)
            return
        }

        // 2. 在后台加载文件并构建惰性章节
        let rebuiltChapters: [TXTChapter] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let data = try? Data(contentsOf: bookPath),
                      let text = String(data: data, encoding: enc) else {
                    continuation.resume(returning: [])
                    return
                }

                let lines = text.components(separatedBy: .newlines)
                let chapters = persistedChapters.map { persisted -> TXTChapter in
                    TXTChapter(
                        id: persisted.id,
                        title: persisted.title,
                        startLine: persisted.startLine,
                        endLine: persisted.endLine,
                        _content: nil,
                        filePath: filePath
                    )
                }
                continuation.resume(returning: chapters)
            }
        }

        guard !rebuiltChapters.isEmpty else {
            await parseAndLoadContent(bookPath: bookPath)
            return
        }

        self.chapters = rebuiltChapters

        // 3. 预加载当前章节内容（供立即阅读）
        await preloadChapter(at: currentChapterIndex)

        if settings.pageTurnMode {
            recomputePages()
        }
    }

    private func parseAndLoadContent(bookPath: URL) async {
        isLoading = true
        let filePath = bookPath.path

        // 1. 检测编码（先读 4KB 头部，不阻塞主线程）
        let encoding = await detectEncoding(bookPath: bookPath)
        guard let enc = encoding else {
            errorMessage = "不支持的文件编码"
            isLoading = false
            return
        }

        // 2. 在后台加载文件 + 章节边界检测
        typealias ChapterBoundary = (startLine: Int, endLine: Int, title: String)
        let (lines, boundaries, totalLines): ([String], [ChapterBoundary], Int) = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let data = try? Data(contentsOf: bookPath),
                      let text = String(data: data, encoding: enc) else {
                    continuation.resume(returning: ([], [], 0))
                    return
                }
                let allLines = text.components(separatedBy: .newlines)
                let bookTitle = self.book.title
                let bounds = detectChapterBoundaries(allLines, bookTitle: bookTitle)
                continuation.resume(returning: (allLines, bounds, allLines.count))
            }
        }

        guard !lines.isEmpty else {
            errorMessage = "文件为空或无法读取"
            isLoading = false
            return
        }

        // 3. 构建章节（只存储边界，不存储内容）
        var finalChapters: [TXTChapter]
        if boundaries.isEmpty {
            finalChapters = [TXTChapter(
                id: "chapter_0",
                title: book.title,
                startLine: 0,
                endLine: totalLines,
                _content: lines[0..<totalLines].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                filePath: filePath
            )]
        } else {
            finalChapters = boundaries.enumerated().map { index, boundary in
                TXTChapter(
                    id: "chapter_\(index + 1)",
                    title: boundary.title,
                    startLine: boundary.startLine,
                    endLine: boundary.endLine,
                    _content: nil,
                    filePath: filePath
                )
            }
        }

        persistChapters(finalChapters)

        let startIndex = book.currentChapterIndex > 0 && book.currentChapterIndex < finalChapters.count
            ? book.currentChapterIndex : 0

        chapters = finalChapters
        isLoading = false

        // 4. 预加载当前章节内容
        await preloadChapter(at: startIndex)

        if book.currentChapterIndex > 0 && book.currentChapterIndex < finalChapters.count {
            currentChapterIndex = book.currentChapterIndex
        }

        if settings.pageTurnMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.recomputePages()
            }
        }
    }

    // MARK: - 编码检测（先读 4KB 头部）
    private func detectEncoding(bookPath: URL) async -> String.Encoding? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let headerData: Data?
                if #available(iOS 17.0, macOS 14.0, *) {
                    headerData = try? Data(contentsOf: bookPath, options: .mappedIfSafe)
                } else {
                    headerData = FileManager.default.contents(atPath: bookPath.path)
                }

                guard let data = headerData else {
                    continuation.resume(returning: nil)
                    return
                }

                // 只用前 4KB 检测编码
                let headerBytes = data.prefix(4096)
                let headerString = String(data: Data(headerBytes), encoding: .ascii)
                    ?? String(data: Data(headerBytes), encoding: .isoLatin1)

                // BOM 检测
                if data.count >= 3 {
                    let bom = [UInt8](data.prefix(3))
                    if bom[0] == 0xEF && bom[1] == 0xBB && bom[2] == 0xBF {
                        continuation.resume(returning: .utf8)
                        return
                    }
                }
                if data.count >= 2 {
                    let bom = [UInt8](data.prefix(2))
                    if bom[0] == 0xFF && bom[1] == 0xFE {
                        continuation.resume(returning: .utf16LittleEndian)
                        return
                    }
                    if bom[0] == 0xFE && bom[1] == 0xFF {
                        continuation.resume(returning: .unicode)
                        return
                    }
                }

                // NSString 自动检测
                var convertedString: NSString?
                var usedLossy: ObjCBool = false
                let detectedEncoding = NSString.stringEncoding(
                    for: Data(headerBytes),
                    encodingOptions: [:],
                    convertedString: &convertedString,
                    usedLossyConversion: &usedLossy
                )
                if detectedEncoding != 0 {
                    let encoding = String.Encoding(rawValue: detectedEncoding)
                    continuation.resume(returning: encoding)
                    return
                }

                // Fallback 编码尝试
                let fallbackEncodings: [UInt] = [0x6581, 4, 0x80000003, 0x80000431, 6, 5, 0x80000421]
                for encodingRaw in fallbackEncodings {
                    let encoding = String.Encoding(rawValue: encodingRaw)
                    if let str = String(data: Data(headerBytes), encoding: encoding), !str.isEmpty {
                        continuation.resume(returning: encoding)
                        return
                    }
                }

                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - 惰性章节内容加载
    /// 加载指定章节的内容（在后台线程执行）
    private func loadChapterContent(chapter: TXTChapter, encoding: String.Encoding) -> String {
        guard let data = FileManager.default.contents(atPath: chapter.filePath) else { return "" }
        guard let text = String(data: data, encoding: encoding) else { return "" }
        let lines = text.components(separatedBy: .newlines)
        guard chapter.startLine < lines.count else { return "" }
        let endLine = min(chapter.endLine, lines.count)
        return lines[chapter.startLine..<endLine].joined(separator: "\n")
    }

    /// 预加载章节内容到内存（后台执行，不阻塞主线程）
    @MainActor
    private func preloadChapter(at index: Int) async {
        guard index >= 0 && index < chapters.count else { return }
        var chapter = chapters[index]
        guard chapter._content == nil else { return }  // 已有内容则跳过

        let encoding = await detectEncoding(bookPath: URL(fileURLWithPath: chapter.filePath))
        guard let enc = encoding else { return }

        let content = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let loaded = self.loadChapterContent(chapter: chapter, encoding: enc)
                continuation.resume(returning: loaded)
            }
        }

        if !content.isEmpty {
            chapter._content = content
            chapters[index] = chapter
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
            if settings.pageTurnMode {
                book.currentPage = currentChapterIndex * max(1, pageModeTotalPages) + pageModeCurrentPage
                book.totalPages = chapters.count * max(1, pageModeTotalPages)
                book.readingPosition = progressPercentage
            } else {
                book.currentPage = currentChapterIndex
                book.readingPosition = Double(currentChapterIndex + 1) / Double(chapters.count)
            }
            if currentChapterIndex < chapters.count {
                book.currentChapterTitle = chapters[currentChapterIndex].title
            }
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

    // MARK: - 辅助方法
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - ScrollOffset Preference Key
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 惰性章节内容视图
/// 负责惰性加载并显示章节内容
struct ChapterContentView: View {
    let chapter: TXTChapter
    let chapterIndex: Int
    let fontSize: CGFloat
    let textColor: String
    let lineSpacing: CGFloat
    let onLoadContent: (String) -> Void

    @State private var loadedContent: String = ""
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chapter.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: textColor) ?? .white)
                .padding(.top, chapterIndex == 0 ? 0 : 24)
                .padding(.bottom, 12)

            if loadedContent.isEmpty && isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !loadedContent.isEmpty {
                Text(loadedContent)
                    .font(.system(size: fontSize))
                    .foregroundColor(Color(hex: textColor) ?? .white)
                    .lineSpacing(lineSpacing)
                    .textSelection(.enabled)
            } else {
                // 占位高度，防止滚动跳动
                Color.clear.frame(height: 100)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollOffsetKey.self,
                    value: geo.frame(in: .named("scroll")).minY
                )
            }
        )
        .task(id: chapter.id) {
            // 首次访问且内容未加载时，触发惰性加载
            if chapter._content == nil && !isLoading && loadedContent.isEmpty {
                isLoading = true
                await loadContent()
                isLoading = false
            }
        }
        .onAppear {
            // 如果章节内容已在 chapters 数组中加载，直接使用
            if let content = chapter._content, !content.isEmpty {
                loadedContent = content
            }
        }
    }

    private func loadContent() async {
        let content = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let data = FileManager.default.contents(atPath: chapter.filePath) else {
                    continuation.resume(returning: "")
                    return
                }
                // 尝试 UTF-8 编码
                var text = String(data: data, encoding: .utf8)
                if text == nil {
                    let fallbackEncodings: [UInt] = [0x80000431, 0x6581, 5, 4]
                    for encRaw in fallbackEncodings {
                        if let s = String(data: data, encoding: String.Encoding(rawValue: encRaw)), !s.isEmpty {
                            text = s
                            break
                        }
                    }
                }
                guard let fullText = text else {
                    continuation.resume(returning: "")
                    return
                }
                let lines = fullText.components(separatedBy: .newlines)
                guard chapter.startLine < lines.count else {
                    continuation.resume(returning: "")
                    return
                }
                let endLine = min(chapter.endLine, lines.count)
                let content = lines[chapter.startLine..<endLine].joined(separator: "\n")
                continuation.resume(returning: content)
            }
        }

        if !content.isEmpty {
            loadedContent = content
            onLoadContent(content)
        }
    }
}
