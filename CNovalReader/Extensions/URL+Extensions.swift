import Foundation

extension URL {
    /// 从 URL 提取文件名（处理中文和特殊字符）
    var fileName: String {
        lastPathComponent.removingPercentEncoding ?? lastPathComponent
    }

    /// 提取文件扩展名（小写）
    var fileExtension: String {
        pathExtension.lowercased()
    }

    /// 检查 URL 是否指向可下载的文件
    var isDownloadableFile: Bool {
        let supportedExtensions = ["epub", "pdf", "txt", "mobi", "azw3", "fb2"]
        return supportedExtensions.contains(fileExtension)
    }

    /// 从 URL 猜测书籍标题
    var guessBookTitle: String {
        let fileNameWithoutExtension = fileName.replacingOccurrences(
            of: ".\(fileExtension)",
            with: ""
        )

        // 移除常见的后缀
        let cleanedName = fileNameWithoutExtension
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 如果文件名太短或只是数字，尝试从 host 提取
        if cleanedName.count < 3 || cleanedName.allSatisfy({ $0.isNumber }) {
            return host?.replacingOccurrences(of: "www.", with: "") ?? cleanedName
        }

        return cleanedName
    }

    /// 验证 URL 格式
    var isValid: Bool {
        scheme != nil && host != nil
    }
}
