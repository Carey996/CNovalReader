import Foundation

enum DownloadError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case fileNotFound
    case fileMoveFailed
    case networkError(underlying: Error)
    case downloadCancelled
    case insufficientStorage
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL format. Please check the URL and try again."
        case .invalidResponse:
            return "Invalid server response. Please try again later."
        case .httpError(let statusCode):
            return "Server error (HTTP \(statusCode)). Please try again later."
        case .fileNotFound:
            return "Downloaded file not found."
        case .fileMoveFailed:
            return "Failed to save file to library."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .downloadCancelled:
            return "Download was cancelled."
        case .insufficientStorage:
            return "Insufficient storage space."
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Make sure the URL starts with http:// or https://"
        case .networkError:
            return "Check your internet connection and try again."
        case .unsupportedFormat:
            return "Try downloading an EPUB, PDF, or TXT file."
        default:
            return nil
        }
    }
}
