import SwiftUI

// MARK: - 搜索结果结构
struct SearchResult: Identifiable {
    let id = UUID()
    let chapterIndex: Int
    let chapterTitle: String
    let matchedText: String
    let contextBefore: String
    let contextAfter: String
    let rangeStart: Int
    let rangeEnd: Int
}

// MARK: - 书内搜索视图
struct InBookSearchView: View {
    let book: Book
    let chapters: [TXTChapter]
    let onJumpToChapter: (Int, Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("搜索书籍内容...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            performSearch()
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color(.systemGray6))

                // 搜索按钮
                if !searchText.isEmpty && searchResults.isEmpty && !isSearching {
                    Button {
                        performSearch()
                    } label: {
                        Label("搜索", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }

                // 搜索中
                if isSearching {
                    ProgressView("搜索中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    // 无结果
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("未找到「\(searchText)」")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("请尝试其他关键词")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 搜索结果列表
                    List {
                        Section {
                            Text("找到 \(searchResults.count) 处匹配")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)

                        ForEach(searchResults) { result in
                            SearchResultRow(result: result, searchText: searchText)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onJumpToChapter(result.chapterIndex, result.rangeStart, result.rangeEnd)
                                    dismiss()
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear {
            isSearchFieldFocused = true
        }
    }

    // MARK: - KMP 搜索算法
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        searchResults = []

        Task.detached(priority: .userInitiated) {
            let results = kmpSearch(keyword: searchText, in: chapters)
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }

    private func kmpSearch(keyword: String, in chapters: [TXTChapter]) -> [SearchResult] {
        var results: [SearchResult] = []
        let lowercasedKeyword = keyword.lowercased()

        for (chapterIndex, chapter) in chapters.enumerated() {
            let lowercasedContent = chapter.content.lowercased()
            let lowercasedChapterTitle = chapter.title.lowercased()

            // 如果标题包含关键词
            if lowercasedChapterTitle.contains(lowercasedKeyword) {
                let result = SearchResult(
                    chapterIndex: chapterIndex,
                    chapterTitle: chapter.title,
                    matchedText: chapter.title,
                    contextBefore: "",
                    contextAfter: "",
                    rangeStart: 0,
                    rangeEnd: chapter.title.count
                )
                results.append(result)
            }

            // 在内容中搜索
            var searchStart = lowercasedContent.startIndex
            while let range = lowercasedContent.range(of: lowercasedKeyword, range: searchStart..<lowercasedContent.endIndex) {
                let matchedRange = Range(uncheckedBounds: (lower: range.lowerBound, upper: range.upperBound))
                let startOffset = lowercasedContent.distance(from: lowercasedContent.startIndex, to: matchedRange.lowerBound)
                let endOffset = lowercasedContent.distance(from: lowercasedContent.startIndex, to: matchedRange.upperBound)

                // 提取上下文
                let contextStartIndex = chapter.content.index(range.lowerBound, offsetBy: -30, limitedBy: chapter.content.startIndex) ?? chapter.content.startIndex
                let contextEndIndex = chapter.content.index(range.upperBound, offsetBy: 30, limitedBy: chapter.content.endIndex) ?? chapter.content.endIndex

                let contextBefore = String(chapter.content[contextStartIndex..<range.lowerBound])
                let matchedText = String(chapter.content[matchedRange])
                let contextAfter = String(chapter.content[range.upperBound..<contextEndIndex])

                let result = SearchResult(
                    chapterIndex: chapterIndex,
                    chapterTitle: chapter.title,
                    matchedText: matchedText,
                    contextBefore: contextBefore,
                    contextAfter: contextAfter,
                    rangeStart: startOffset,
                    rangeEnd: endOffset
                )
                results.append(result)

                searchStart = range.upperBound
            }
        }

        return results
    }
}

// MARK: - 搜索结果行
struct SearchResultRow: View {
    let result: SearchResult
    let searchText: String
    @ObservedObject private var settings = ReaderSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 章节标题
            Text(result.chapterTitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)

            // 匹配内容上下文
            if !result.contextBefore.isEmpty || !result.contextAfter.isEmpty {
                Text("...\(result.contextBefore)\(result.matchedText)\(result.contextAfter)...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                Text(result.matchedText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - EPUB 书内搜索视图
struct EPUBInBookSearchView: View {
    let book: Book
    let chapters: [EPUBParsingService.Chapter]
    let chapterContents: [String] // 已加载的章节内容
    let onJumpToChapter: (Int, Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("搜索书籍内容...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            performSearch()
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color(.systemGray6))

                if !searchText.isEmpty && searchResults.isEmpty && !isSearching {
                    Button {
                        performSearch()
                    } label: {
                        Label("搜索", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }

                if isSearching {
                    ProgressView("搜索中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("未找到「\(searchText)」")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Text("找到 \(searchResults.count) 处匹配")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)

                        ForEach(searchResults) { result in
                            SearchResultRow(result: result, searchText: searchText)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onJumpToChapter(result.chapterIndex, result.rangeStart, result.rangeEnd)
                                    dismiss()
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear {
            isSearchFieldFocused = true
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        searchResults = []

        Task.detached(priority: .userInitiated) {
            let results = epubSearch(keyword: searchText)
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }

    private func epubSearch(keyword: String) -> [SearchResult] {
        var results: [SearchResult] = []
        let lowercasedKeyword = keyword.lowercased()

        for (chapterIndex, chapter) in chapters.enumerated() {
            guard chapterIndex < chapterContents.count else { continue }
            let content = chapterContents[chapterIndex]
            let lowercasedContent = content.lowercased()
            let lowercasedChapterTitle = chapter.title.lowercased()

            if lowercasedChapterTitle.contains(lowercasedKeyword) {
                let result = SearchResult(
                    chapterIndex: chapterIndex,
                    chapterTitle: chapter.title,
                    matchedText: chapter.title,
                    contextBefore: "",
                    contextAfter: "",
                    rangeStart: 0,
                    rangeEnd: chapter.title.count
                )
                results.append(result)
            }

            var searchStart = lowercasedContent.startIndex
            while let range = lowercasedContent.range(of: lowercasedKeyword, range: searchStart..<lowercasedContent.endIndex) {
                let matchedRange = Range(uncheckedBounds: (lower: range.lowerBound, upper: range.upperBound))
                let startOffset = lowercasedContent.distance(from: lowercasedContent.startIndex, to: matchedRange.lowerBound)
                let endOffset = lowercasedContent.distance(from: lowercasedContent.startIndex, to: matchedRange.upperBound)

                let contextStartIndex = content.index(range.lowerBound, offsetBy: -30, limitedBy: content.startIndex) ?? content.startIndex
                let contextEndIndex = content.index(range.upperBound, offsetBy: 30, limitedBy: content.endIndex) ?? content.endIndex

                let contextBefore = String(content[contextStartIndex..<range.lowerBound])
                let matchedText = String(content[matchedRange])
                let contextAfter = String(content[range.upperBound..<contextEndIndex])

                let result = SearchResult(
                    chapterIndex: chapterIndex,
                    chapterTitle: chapter.title,
                    matchedText: matchedText,
                    contextBefore: contextBefore,
                    contextAfter: contextAfter,
                    rangeStart: startOffset,
                    rangeEnd: endOffset
                )
                results.append(result)

                searchStart = range.upperBound
            }
        }

        return results
    }
}
