//
//  CNovalReaderTests.swift
//  CNovalReaderTests
//
//  Created by 陈凯瑞 on 2026/2/2.
//

import Foundation
import Testing
@testable import CNovalReader

struct BookTests {

    @Test func testBookInitialization() {
        let book = Book(title: "Test Book", author: "Test Author", fileExtension: "epub")

        #expect(book.title == "Test Book")
        #expect(book.author == "Test Author")
        #expect(book.fileExtension == "epub")
        #expect(book.downloadProgress == 0)
        #expect(book.status == .unknown)
        #expect(book.id != nil)
        #expect(book.createdAt != nil)
    }

    @Test func testBookStatusUnknown() {
        let book = Book(title: "Test")

        #expect(book.status == .unknown)
        #expect(book.status.isDownloading == false)
        #expect(book.status.isDownloaded == false)
    }

    @Test func testBookStatusDownloading() {
        let book = Book(title: "Test")

        book.status = .downloading(progress: 0.5)

        #expect(book.status.isDownloading == true)
        #expect(book.status.isDownloaded == false)
    }

    @Test func testBookStatusDownloaded() {
        let book = Book(title: "Test")

        book.status = .downloaded

        #expect(book.status.isDownloading == false)
        #expect(book.status.isDownloaded == true)
    }

    @Test func testBookStatusFailed() {
        let book = Book(title: "Test")

        book.status = .failed("Network error")

        if case .failed(let error) = book.status {
            #expect(error == "Network error")
        } else {
            Issue.record("Expected failed status")
        }
    }

    @Test func testBookStatusPersistsThroughCodable() {
        let book = Book(title: "Test")
        book.status = .downloading(progress: 0.75)

        // Status is stored as Data via Codable
        guard let statusData = book.statusRawValue else {
            Issue.record("Expected statusRawValue to be set")
            return
        }

        let decodedStatus = try? JSONDecoder().decode(BookStatus.self, from: statusData)

        #expect(decodedStatus == .downloading(progress: 0.75))
    }
}

struct DownloadErrorTests {

    @Test func testInvalidURLErrorDescription() {
        let error = DownloadError.invalidURL

        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("Invalid URL"))
    }

    @Test func testHttpErrorWithStatusCode() {
        let error = DownloadError.httpError(statusCode: 404)

        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("404"))
    }

    @Test func testUnsupportedFormatError() {
        let error = DownloadError.unsupportedFormat("exe")

        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("exe"))
    }

    @Test func testRecoverySuggestionForInvalidURL() {
        let error = DownloadError.invalidURL

        #expect(error.recoverySuggestion != nil)
        #expect(error.recoverySuggestion!.contains("http"))
    }

    @Test func testNoRecoverySuggestionForHttpError() {
        let error = DownloadError.httpError(statusCode: 500)

        #expect(error.recoverySuggestion == nil)
    }
}

struct URLExtensionsTests {

    @Test func testFileNameExtraction() {
        let url = URL(string: "https://example.com/path/to/book.epub")!

        #expect(url.fileName == "book.epub")
    }

    @Test func testFileNameWithSpaces() {
        let url = URL(string: "https://example.com/path/to/My%20Book.epub")!

        #expect(url.fileName == "My Book.epub")
    }

    @Test func testFileExtensionLowercased() {
        let url = URL(string: "https://example.com/book.EPUB")!

        #expect(url.fileExtension == "epub")
    }

    @Test func testIsDownloadableFileWithEpub() {
        let url = URL(string: "https://example.com/book.epub")!

        #expect(url.isDownloadableFile == true)
    }

    @Test func testIsDownloadableFileWithPdf() {
        let url = URL(string: "https://example.com/book.pdf")!

        #expect(url.isDownloadableFile == true)
    }

    @Test func testIsDownloadableFileWithUnsupportedFormat() {
        let url = URL(string: "https://example.com/book.exe")!

        #expect(url.isDownloadableFile == false)
    }

    @Test func testGuessBookTitleFromFileName() {
        let url = URL(string: "https://example.com/The_Great_Gatsby.epub")!

        #expect(url.guessBookTitle == "The Great Gatsby")
    }

    @Test func testGuessBookTitleRemovesHyphens() {
        let url = URL(string: "https://example.com/my-book-name.epub")!

        #expect(url.guessBookTitle == "my book name")
    }

    @Test func testGuessBookTitleUsesHostWhenFileNameIsShort() {
        let url = URL(string: "https://www.example.com/123.epub")!

        #expect(url.guessBookTitle == "example.com")
    }

    @Test func testIsValidWithHTTPS() {
        let url = URL(string: "https://example.com/book.epub")!

        #expect(url.isValid == true)
    }

    @Test func testIsValidWithHTTP() {
        let url = URL(string: "http://example.com/book.epub")!

        #expect(url.isValid == true)
    }

    @Test func testIsValidWithInvalidURL() {
        let url = URL(string: "not-a-valid-url")!

        #expect(url.isValid == false)
    }

    @Test func testAllSupportedExtensions() {
        let supportedExtensions = ["epub", "pdf", "txt", "mobi", "azw3", "fb2"]

        for ext in supportedExtensions {
            let url = URL(string: "https://example.com/book.\(ext)")!
            #expect(url.isDownloadableFile == true, "Extension \(ext) should be downloadable")
        }
    }
}

struct DownloadStatusTests {

    @Test func testDownloadStatusDisplayTextIdle() {
        let status = DownloadStatus.idle

        #expect(status.displayText == "")
    }

    @Test func testDownloadStatusDisplayTextDownloading() {
        let status = DownloadStatus.downloading(progress: 0.5)

        #expect(status.displayText.contains("50%"))
    }

    @Test func testDownloadStatusDisplayTextCompleted() {
        let status = DownloadStatus.completed

        #expect(status.displayText == "Download Complete")
    }

    @Test func testDownloadStatusDisplayTextFailed() {
        let status = DownloadStatus.failed

        #expect(status.displayText == "Download Failed")
    }
}
