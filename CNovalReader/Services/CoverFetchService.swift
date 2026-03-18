import Foundation

/// 书籍封面联网获取服务（豆瓣API）
actor CoverFetchService {
    static let shared = CoverFetchService()

    private init() {}

    /// 搜索书籍并获取封面
    /// - Parameters:
    ///   - title: 书籍标题
    ///   - author: 作者（可选，更精准）
    /// - Returns: 封面图片数据
    func fetchCover(title: String, author: String? = nil) async -> Data? {
        // 先尝试精准匹配（ISBN）
        if let isbnCover = await fetchCoverByISBN(title: title, author: author) {
            return isbnCover
        }

        // 再尝试模糊搜索书名
        return await fetchCoverBySearch(title: title, author: author)
    }

    /// 通过ISBN精准匹配
    private func fetchCoverByISBN(title: String, author: String? = nil) async -> Data? {
        // 从标题中尝试提取ISBN
        let isbnPattern = #"ISBN[:\s]*([0-9\-X]{10,17})"#
        guard let regex = try? NSRegularExpression(pattern: isbnPattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(title.startIndex..., in: title)
        if let match = regex.firstMatch(in: title, options: [], range: range),
           let isbnRange = Range(match.range(at: 1), in: title) {
            let isbn = String(title[isbnRange]).replacingOccurrences(of: "-", with: "")
            return await fetchCoverFromDouban(isbn: isbn)
        }
        return nil
    }

    /// 通过搜索获取封面
    private func fetchCoverBySearch(title: String, author: String? = nil) async -> Data? {
        var searchTitle = title
            .replacingOccurrences(of: #"[\(（\[].*[\)\]）]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if searchTitle.count > 30 {
            searchTitle = String(searchTitle.prefix(30))
        }

        guard let encoded = searchTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.douban.com/v2/book/search?q=\(encoded)&count=5") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode(DoubanSearchResult.self, from: data)

            guard let best = findBestMatch(books: result.books, title: title, author: author) else {
                return nil
            }

            if let imageURL = best.image, let url = URL(string: imageURL) {
                return try await fetchImageData(from: url)
            }
        } catch {
            print("Douban search failed: \(error)")
        }

        return nil
    }

    private func findBestMatch(books: [DoubanBook], title: String, author: String?) -> DoubanBook? {
        let normalizedTitle = normalize(title)

        for book in books {
            let bookTitleNorm = normalize(book.title)
            let authorMatch = author == nil || book.authorString.contains(author!)

            if bookTitleNorm == normalizedTitle && authorMatch {
                return book
            }
        }

        // 宽松匹配：标题包含关系
        for book in books {
            let bookTitleNorm = normalize(book.title)
            let normalizedTitleStr = normalize(title)
            let authorMatch = author == nil || book.authorString.contains(author ?? "")

            if (bookTitleNorm.contains(normalizedTitleStr) || normalizedTitleStr.contains(bookTitleNorm))
               && authorMatch {
                return book
            }
        }

        return books.first
    }

    private func normalize(_ str: String) -> String {
        str.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
    }

    private func fetchCoverFromDouban(isbn: String) async -> Data? {
        guard let url = URL(string: "https://api.douban.com/v2/book/isbn/\(isbn)") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let book = try JSONDecoder().decode(DoubanBook.self, from: data)
            if let imageURL = book.image, let url = URL(string: imageURL) {
                return try await fetchImageData(from: url)
            }
        } catch {
            print("Douban ISBN fetch failed: \(error)")
        }

        return nil
    }

    private func fetchImageData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "CoverFetch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        return data
    }
}

// MARK: - 豆瓣API响应模型
private struct DoubanSearchResult: Codable {
    let books: [DoubanBook]
}

private struct DoubanBook: Codable {
    let title: String
    let author: [String]?
    let image: String?
    let isbn: String?

    var authorString: String {
        author?.joined(separator: ", ") ?? ""
    }
}
