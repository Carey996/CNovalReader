import SwiftUI
import SwiftUI
import UIKit
import SwiftData

// MARK: - 书柜风格主题色
struct BookshelfTheme {
    // 木质书架色调
    static let shelfBrown = Color(hex: "#8B6914") ?? .brown
    static let shelfDark = Color(hex: "#5C4033") ?? .brown
    static let shelfLight = Color(hex: "#D2B48C") ?? Color(red: 0.82, green: 0.71, blue: 0.55)
    static let warmBeige = Color(hex: "#F5E6C8") ?? .init(red: 0.96, green: 0.90, blue: 0.78)
    static let warmBackground = Color(hex: "#FDF6E3") ?? .init(red: 0.99, green: 0.96, blue: 0.89)
    static let accentGold = Color(hex: "#C19A6B") ?? .init(red: 0.76, green: 0.60, blue: 0.42)

    // 根据书类型返回封面配色
    static func coverColors(for ext: String?) -> [Color] {
        switch ext?.lowercased() {
        case "epub": return [Color(hex: "#C0392B") ?? .red, Color(hex: "#8E4411") ?? .orange]
        case "pdf":  return [Color(hex: "#1A5276") ?? .blue, Color(hex: "#1B4F72") ?? .indigo]
        case "txt":  return [Color(hex: "#1E8449") ?? .green, Color(hex: "#145A32") ?? .teal]
        default:     return [Color(hex: "#7D6608") ?? .yellow, Color(hex: "#4A4000") ?? Color(red: 0.29, green: 0.25, blue: 0.0)]
        }
    }

    // 书脊配色（更有质感的深色系）
    static func spineColors(for ext: String?) -> (main: Color, shadow: Color, highlight: Color) {
        switch ext?.lowercased() {
        case "epub": return (
            Color(hex: "#922B21") ?? .red.opacity(0.9),
            Color(hex: "#641E16") ?? .black.opacity(0.4),
            Color(hex: "#C0392B") ?? .red.opacity(0.3)
        )
        case "pdf":  return (
            Color(hex: "#1A5276") ?? .blue.opacity(0.9),
            Color(hex: "#154360") ?? .black.opacity(0.4),
            Color(hex: "#2E86C1") ?? .blue.opacity(0.3)
        )
        case "txt":  return (
            Color(hex: "#1E8449") ?? .green.opacity(0.9),
            Color(hex: "#145A32") ?? .black.opacity(0.4),
            Color(hex: "#27AE60") ?? .green.opacity(0.3)
        )
        default:     return (
            Color(hex: "#7D6608") ?? .yellow.opacity(0.9),
            Color(hex: "#4A4000") ?? .black.opacity(0.4),
            Color(hex: "#B7950B") ?? .yellow.opacity(0.3)
        )
        }
    }
}

// MARK: - 3D书脊视图
struct BookSpineView: View {
    let book: Book
    let spineWidth: CGFloat
    @State private var showDetail = false
    @State private var showReader = false

    var body: some View {
        let colors = BookshelfTheme.spineColors(for: book.fileExtension)

        ZStack(alignment: .center) {
            // 书脊主体
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [colors.highlight, colors.main, colors.shadow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 顶部高光模拟光照
            VStack(spacing: 0) {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(height: spineWidth * 0.6)

                Spacer()

                // 书脊文字
                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.system(size: spineWidth * 0.55, weight: .semibold, design: .serif))
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .frame(width: spineWidth * 1.1)

                    if let author = book.author, !author.isEmpty {
                        Text(author)
                            .font(.system(size: spineWidth * 0.4, weight: .light, design: .serif))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(width: spineWidth * 1.1)
                    }
                }
                .padding(.vertical, spineWidth * 0.3)

                Spacer()
            }
            .padding(.horizontal, 2)

            // 底部书脊底部阴影
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 1)
                    .fill(colors.shadow.opacity(0.6))
                    .frame(height: 3)
            }
            
            // 右上角信息按钮
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showDetail = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: spineWidth * 0.35))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: spineWidth * 0.45, height: spineWidth * 0.45)
                            )
                    }
                    .padding(4)
                }
                Spacer()
            }
        }
        .frame(width: spineWidth, height: 150)
        .shadow(color: .black.opacity(0.35), radius: 3, x: 2, y: 4)
        .shadow(color: colors.shadow.opacity(0.2), radius: 1, x: -1, y: 1)
        .onTapGesture {
            // 点击书脊直接进入阅读
            if book.localFileName != nil {
                showReader = true
            }
        }
        .sheet(isPresented: $showDetail) {
            NavigationStack {
                BookDetailView(book: book)
            }
        }
        .fullScreenCover(isPresented: $showReader) {
            if #available(iOS 17.0, *) {
                ReaderView(book: book)
            }
        }
    }
}

// MARK: - 书架层视图
struct BookshelfRow: View {
    let books: [Book]
    let spineWidth: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            // 书架层内容（书脊）
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(books) { book in
                    BookSpineView(book: book, spineWidth: spineWidth)
                    .buttonStyle(.plain)
                }

                if books.isEmpty {
                    ForEach(0..<5, id: \.self) { _ in
                        EmptySpineSlot(width: spineWidth)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)

            // 书架层板（木质横条）
            ShelfBoard()
                .frame(height: 8)
        }
    }
}

// MARK: - 空书脊槽位
struct EmptySpineSlot: View {
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.15),
                        Color.gray.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: 150)
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5)
            }
    }
}

// MARK: - 书架层板
struct ShelfBoard: View {
    var body: some View {
        ShelfBoardBody()
    }
}

private struct ShelfBoardBody: View {
    var body: some View {
        ZStack(alignment: .top) {
            boardGradient
            highlightOverlay
            shadowOverlay
        }
    }

    private var boardGradient: some View {
        LinearGradient(
            colors: [boardColor1, boardColor2, boardColor3],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var highlightOverlay: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 2)
    }

    private var shadowOverlay: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(Color.black.opacity(0.25))
        }
    }

    private var boardColor1: Color { Color(red: 0.63, green: 0.32, blue: 0.18) }   // #A0522D
    private var boardColor2: Color { Color(red: 0.55, green: 0.27, blue: 0.07) }   // #8B4513
    private var boardColor3: Color { Color(red: 0.42, green: 0.24, blue: 0.04) }   // #6B3E0A
}

// MARK: - 书柜背景
struct BookshelfBackground: View {
    var body: some View {
        ZStack {
            warmBg
            woodTexture
        }
    }

    private var warmBg: some View {
        BookshelfTheme.warmBackground
            .ignoresSafeArea()
    }

    private var woodTexture: some View {
        VStack(spacing: 0) {
            ForEach(0..<20, id: \.self) { i in
                let item = Self.woodPattern[i]
                Rectangle()
                    .fill(LinearGradient(
                        colors: [bgColor1.opacity(item.opacity1), bgColor2.opacity(item.opacity2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: item.height)
            }
        }
        .mask(LinearGradient(
            colors: [.black, .clear, .clear, .black],
            startPoint: .top,
            endPoint: .bottom
        ))
        .opacity(0.4)
    }

    private var bgColor1: Color { Color(red: 0.96, green: 0.90, blue: 0.78) }
    private var bgColor2: Color { Color(red: 0.93, green: 0.85, blue: 0.64) }

    private static let woodPattern: [(height: CGFloat, opacity1: Double, opacity2: Double)] = [
        (height: 3, opacity1: 0.5, opacity2: 0.3),
        (height: 5, opacity1: 0.3, opacity2: 0.5),
        (height: 4, opacity1: 0.6, opacity2: 0.4),
        (height: 7, opacity1: 0.4, opacity2: 0.6),
        (height: 3, opacity1: 0.5, opacity2: 0.4),
        (height: 6, opacity1: 0.3, opacity2: 0.5),
        (height: 4, opacity1: 0.5, opacity2: 0.6),
        (height: 5, opacity1: 0.4, opacity2: 0.3),
        (height: 3, opacity1: 0.6, opacity2: 0.5),
        (height: 8, opacity1: 0.3, opacity2: 0.4),
        (height: 4, opacity1: 0.5, opacity2: 0.6),
        (height: 5, opacity1: 0.4, opacity2: 0.3),
        (height: 3, opacity1: 0.5, opacity2: 0.5),
        (height: 6, opacity1: 0.6, opacity2: 0.3),
        (height: 4, opacity1: 0.3, opacity2: 0.5),
        (height: 5, opacity1: 0.5, opacity2: 0.4),
        (height: 3, opacity1: 0.4, opacity2: 0.6),
        (height: 7, opacity1: 0.5, opacity2: 0.3),
        (height: 4, opacity1: 0.6, opacity2: 0.5),
        (height: 3, opacity1: 0.3, opacity2: 0.4),
    ]
}

// MARK: - 内容视图
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.lastReadAt, order: .reverse) private var books: [Book]
    @Query(sort: \Book.createdAt, order: .reverse) private var allBooks: [Book]
    @State private var showDownloadSheet = false
    @State private var showSettings = false
    @State private var selectedTab = 0
    @State private var selectedCategory: String? = nil
    @State private var showFileImporter = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showImportError = false

    // MARK: - 计算属性：所有分类
    private var allCategories: [String] {
        var categories = Set<String>()
        for book in allBooks {
            if let cat = book.category, !cat.isEmpty {
                categories.insert(cat)
            }
        }
        return Array(categories).sorted()
    }

    // MARK: - 计算属性：过滤后的书籍
    private var filteredBooks: [Book] {
        if let cat = selectedCategory {
            return allBooks.filter { $0.category == cat }
        }
        return allBooks
    }

    private var recentBooks: [Book] {
        books.filter { book in
            if case .downloaded = book.status { return book.localFileName != nil }
            if case .reading = book.status { return book.localFileName != nil }
            return false
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // 书库（书架风格）
            NavigationStack {
                ZStack {
                    BookshelfBackground()

                    ScrollView {
                        VStack(spacing: 0) {
                            if allBooks.isEmpty {
                                emptyStateView
                            } else {
                                // 继续阅读区（横向滑动）
                                if !recentBooks.isEmpty {
                                    recentReadingSection
                                }

                                // 全部书籍书架
                                allBooksSection
                            }
                        }
                    }
                }
                .navigationTitle("书库")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                                .foregroundColor(BookshelfTheme.shelfDark)
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { showFileImporter = true } label: {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(BookshelfTheme.shelfDark)
                        }
                        Button { showDownloadSheet = true } label: {
                            Image(systemName: "plus")
                                .foregroundColor(BookshelfTheme.shelfDark)
                        }
                    }
                }
            }
            .tabItem { Label("书库", systemImage: "books.vertical") }
            .tag(0)

            // 正在阅读
            NavigationStack {
                ZStack {
                    BookshelfBackground()

                    if recentBooks.isEmpty {
                        readingEmptyView
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(recentBooks.chunked(into: 5).enumerated()), id: \.offset) { _, row in
                                    BookshelfRow(books: row)
                                    if row.count > 0 { Divider().background(BookshelfTheme.shelfLight) }
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            .tabItem { Label("阅读", systemImage: "book") }
            .tag(1)
        }
        .tint(BookshelfTheme.accentGold)
        .sheet(isPresented: $showDownloadSheet) { DownloadView() }
        .sheet(isPresented: $showSettings) { ReaderSettingsView() }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.plainText, .pdf, .epub],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("导入失败", isPresented: $showImportError) {
            Button("确定") {}
        } message: {
            Text(importError ?? "未知错误")
        }
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("正在导入书籍...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(Color(.systemGray5).opacity(0.9))
                    .cornerRadius(16)
                }
            }
        }
    }

    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 70))
                .foregroundColor(BookshelfTheme.shelfLight)

            Text("书库是空的")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(BookshelfTheme.shelfDark)

            Text("下载书籍或从文件导入\n开始阅读")
                .font(.subheadline)
                .foregroundColor(BookshelfTheme.shelfDark.opacity(0.7))
                .multilineTextAlignment(.center)

            Button {
                showDownloadSheet = true
            } label: {
                Label("添加书籍", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookshelfTheme.accentGold)
            .padding(.top, 8)
        }
        .padding(.top, 80)
    }

    private var readingEmptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(BookshelfTheme.shelfLight)

            Text("没有正在阅读的书籍")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(BookshelfTheme.shelfDark)

            Text("正在阅读的书籍\n会显示在这里")
                .font(.subheadline)
                .foregroundColor(BookshelfTheme.shelfDark.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 继续阅读区
    private var recentReadingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(BookshelfTheme.accentGold)
                Text("继续阅读")
                    .font(.headline)
                    .foregroundColor(BookshelfTheme.shelfDark)
                Spacer()
                if todayReadingMinutes > 0 {
                    Text("今日阅读 \(todayReadingMinutes)m")
                        .font(.caption)
                        .foregroundColor(BookshelfTheme.accentGold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(recentBooks.prefix(6)) { book in
                        RecentBookCover(book: book)
                        .onTapGesture {
                            if book.localFileName != nil {
                                // 直接进入阅读
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let rootVC = windowScene.windows.first?.rootViewController {
                                    let readerView = UIHostingController(rootView: AnyView(Group {
                                        if #available(iOS 17.0, *) {
                                            ReaderView(book: book)
                                        }
                                    }))
                                    readerView.modalPresentationStyle = .fullScreen
                                    rootVC.present(readerView, animated: true)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - 今日阅读分钟数
    private var todayReadingMinutes: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let recentBooksWithReadingToday = recentBooks.filter { book in
            guard let lastReading = book.lastReadingTime else { return false }
            return calendar.isDate(lastReading, inSameDayAs: today)
        }
        let totalSeconds = recentBooksWithReadingToday.reduce(0) { $0 + $1.totalReadingTime }
        return max(1, Int(totalSeconds / 60))
    }

    // MARK: - 文件导入处理
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let sourceURL = urls.first else { return }
            isImporting = true

            Task.detached(priority: .userInitiated) {
                do {
                    let book = try await importBook(from: sourceURL)
                    await MainActor.run {
                        modelContext.insert(book)
                        isImporting = false
                    }
                } catch {
                    await MainActor.run {
                        importError = error.localizedDescription
                        showImportError = true
                        isImporting = false
                    }
                }
            }

        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }

    private func importBook(from sourceURL: URL) async throws -> Book {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileName = sourceURL.lastPathComponent
        let fileExtension = sourceURL.pathExtension.lowercased()
        let uniqueFileName = "\(UUID().uuidString).\(fileExtension)"

        // 移动文件到书籍目录
        let destinationURL = try FileManagerService.shared.moveToDocuments(sourceURL, fileName: uniqueFileName)

        // 获取文件大小
        let fileSize = try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64

        // 创建书籍对象
        let book = Book(
            title: sourceURL.deletingPathExtension().lastPathComponent,
            author: nil,
            localFileName: uniqueFileName,
            fileExtension: fileExtension
        )
        book.fileSize = fileSize
        book.status = .downloaded

        return book
    }

    // MARK: - 全部书籍书架
    private var allBooksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "books.vertical")
                    .foregroundColor(BookshelfTheme.accentGold)
                Text(selectedCategory ?? "全部书籍")
                    .font(.headline)
                    .foregroundColor(BookshelfTheme.shelfDark)
                Spacer()
                Text("\(filteredBooks.count) 本")
                    .font(.caption)
                    .foregroundColor(BookshelfTheme.shelfDark.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // 分类筛选 Tab
            if !allCategories.isEmpty {
                categoryFilterBar
            }

            // 按每行5本分组显示为书架层
            ForEach(Array(filteredBooks.chunked(into: 6).enumerated()), id: \.offset) { _, row in
                BookshelfRow(books: row)
                if row.count > 0 {
                    Divider()
                        .background(BookshelfTheme.shelfLight.opacity(0.5))
                        .padding(.horizontal, 8)
                }
            }

            // 删除入口
            if !filteredBooks.isEmpty {
                NavigationLink {
                    ManageBooksView()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("管理书籍")
                    }
                    .font(.caption)
                    .foregroundColor(BookshelfTheme.shelfDark.opacity(0.6))
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - 分类筛选栏
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部
                categoryChip(title: "全部", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(allCategories, id: \.self) { cat in
                    categoryChip(title: cat, isSelected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : BookshelfTheme.shelfDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? BookshelfTheme.accentGold : Color.gray.opacity(0.15))
                .cornerRadius(16)
        }
    }
}

// MARK: - 最近阅读封面
struct RecentBookCover: View {
    let book: Book

    private var colors: (main: Color, shadow: Color, highlight: Color) {
        BookshelfTheme.spineColors(for: book.fileExtension)
    }

    var body: some View {
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [colors.highlight, colors.main, colors.shadow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 2) {
                Image(systemName: bookIconName)
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.9))
                Text(book.title)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
        }
        .frame(width: 70, height: 100)
        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 3)
    }

    private var bookIconName: String {
        switch book.fileExtension?.lowercased() {
        case "epub": return "book.closed"
        case "pdf": return "doc.text"
        default: return "doc.plaintext"
        }
    }
}

// MARK: - 管理书籍视图
struct ManageBooksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var allBooks: [Book]

    var body: some View {
        List {
            ForEach(allBooks) { book in
                NavigationLink { BookDetailView(book: book) } label: {
                    BookRowView(book: book)
                }
            }
            .onDelete(perform: deleteBooks)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("管理书籍")
    }

    private func deleteBooks(_ offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let book = allBooks[index]
                if let fileName = book.localFileName {
                    try? FileManagerService.shared.deleteBook(fileName: fileName)
                }
                modelContext.delete(book)
            }
        }
    }
}

// MARK: - 最近阅读卡片（保留兼容）
struct RecentBookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            let colors = BookshelfTheme.spineColors(for: book.fileExtension)
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [colors.highlight, colors.main, colors.shadow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 60)
                Image(systemName: bookIconName)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .shadow(color: .black.opacity(0.2), radius: 1, x: 1, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                if let author = book.author {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let position = book.readingPosition {
                    HStack(spacing: 6) {
                        ProgressView(value: position)
                            .progressViewStyle(.linear)
                            .frame(width: 60)
                            .tint(BookshelfTheme.accentGold)
                        Text("\(Int(position * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
    }

    private var bookIconName: String {
        switch book.fileExtension?.lowercased() {
        case "epub": return "book.closed"
        case "pdf": return "doc.text"
        default: return "doc.plaintext"
        }
    }
}

// MARK: - 书籍行视图
struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            let colors = BookshelfTheme.spineColors(for: book.fileExtension)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [colors.highlight, colors.main, colors.shadow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 75)

                VStack(spacing: 2) {
                    Image(systemName: bookIconName)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                    if let ext = book.fileExtension?.uppercased() {
                        Text(ext)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)

                if let author = book.author, !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let position = book.readingPosition, position > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 3)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(BookshelfTheme.accentGold)
                                    .frame(width: geo.size.width * position, height: 3)
                            }
                        }
                        .frame(height: 3)
                        Text("\(Int(position * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if case .downloaded = book.status {
                    Text("未开始阅读")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var bookIconName: String {
        switch book.fileExtension?.lowercased() {
        case "epub": return "book.closed"
        case "pdf": return "doc.text"
        default: return "doc.plaintext"
        }
    }
}

// MARK: - Array Chunked Extension
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
