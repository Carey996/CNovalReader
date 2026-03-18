import SwiftUI
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
        }
        .frame(width: spineWidth, height: 150)
        .shadow(color: .black.opacity(0.35), radius: 3, x: 2, y: 4)
        .shadow(color: colors.shadow.opacity(0.2), radius: 1, x: -1, y: 1)
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
                    NavigationLink { BookDetailView(book: book) } label: {
                        BookSpineView(book: book, spineWidth: spineWidth)
                    }
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
                    ToolbarItem(placement: .topBarTrailing) {
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(recentBooks.prefix(6)) { book in
                        NavigationLink { BookDetailView(book: book) } label: {
                            VStack(spacing: 4) {
                                RecentBookCover(book: book)
                                Text(book.title)
                                    .font(.caption2)
                                    .foregroundColor(BookshelfTheme.shelfDark)
                                    .lineLimit(2)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.center)

                                if let position = book.readingPosition {
                                    ProgressView(value: position)
                                        .progressViewStyle(.linear)
                                        .frame(width: 60)
                                        .tint(BookshelfTheme.accentGold)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - 全部书籍书架
    private var allBooksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "books.vertical")
                    .foregroundColor(BookshelfTheme.accentGold)
                Text("全部书籍")
                    .font(.headline)
                    .foregroundColor(BookshelfTheme.shelfDark)
                Spacer()
                Text("\(allBooks.count) 本")
                    .font(.caption)
                    .foregroundColor(BookshelfTheme.shelfDark.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // 按每行5本分组显示为书架层
            ForEach(Array(allBooks.chunked(into: 6).enumerated()), id: \.offset) { _, row in
                BookshelfRow(books: row)
                if row.count > 0 {
                    Divider()
                        .background(BookshelfTheme.shelfLight.opacity(0.5))
                        .padding(.horizontal, 8)
                }
            }

            // 删除入口
            if !allBooks.isEmpty {
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
