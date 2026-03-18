import SwiftUI

// MARK: - TXT 阅读器 (章节滚动版 - 异步加载优化 + 手势 + 沉浸模式)
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

    // 手势状态
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

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
                // 顶部工具栏
                topToolbar
                    .opacity(isImmersive ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isImmersive)

                // 内容区（带手势）
                contentScrollView
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

    // MARK: - 内容视图（带手势）
    private var contentScrollView: some View {
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
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ScrollOffsetKey.self,
                                    value: geo.frame(in: .named("scroll")).minY
                                )
                            }
                        )
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
            // 拖拽手势：左滑上一页，右滑下一页，下滑下一章
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
            // 双击：切换沉浸模式
            TapGesture(count: 2)
                .onEnded {
                    withAnimation {
                        isImmersive.toggle()
                    }
                }
        )
    }

    private func handleSwipeEnd(translation: CGSize) {
        let horizontal = translation.width
        let vertical = translation.height

        // 判断主要方向
        if abs(horizontal) > abs(vertical) {
            // 水平滑动
            if horizontal > 60 {
                // 右滑 → 上一页
                previousChapter()
            } else if horizontal < -60 {
                // 左滑 → 下一页
                nextChapter()
            }
        } else {
            // 垂直滑动
            if vertical > 80 {
                // 下滑 → 下一章
                nextChapter()
            }
        }
    }

    // MARK: - 边缘滑入显示工具栏
    private var edgeRevealOverlay: some View {
        HStack(spacing: 0) {
            // 左侧边缘区域
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

            // 右侧边缘区域
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
        // 注意：SwiftUI 的 textSelection 不提供选中文字 API，
        // 这里使用章节内容中提取高亮文本
        if currentChapterIndex < chapters.count {
            let chapter = chapters[currentChapterIndex]
            let text = chapter.content.prefix(50) + "..."
            let highlight = Highlight(
                text: String(text),
                chapterIndex: currentChapterIndex,
                rangeStart: 0,
                rangeEnd: min(50, chapter.content.count)
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
        // 显示一个简短提示（实际笔记功能需要更复杂的UI）
        addHighlight()
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
}

// MARK: - ScrollOffset Preference Key
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
