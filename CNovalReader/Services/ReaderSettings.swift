import Foundation
import SwiftUI
import Combine

/// 全局阅读设置
class ReaderSettings: ObservableObject {
    static let shared = ReaderSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let fontSize = "reader_fontSize"
        static let colorSchemeOverride = "reader_colorSchemeOverride"
        static let backgroundColorIndex = "reader_backgroundColorIndex"
        static let textColorIndex = "reader_textColorIndex"
        static let fontFamily = "reader_fontFamily"
        static let lineSpacing = "reader_lineSpacing"
        static let customFonts = "reader_customFonts"
        static let downloadedFontURLs = "reader_downloadedFontURLs"
    }
    
    // MARK: - Color Scheme Override (0=system, 1=light, 2=dark)
    @Published var colorSchemeOverride: Int {
        didSet { defaults.set(colorSchemeOverride, forKey: Keys.colorSchemeOverride) }
    }
    
    // MARK: - 字体大小
    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }
    
    // MARK: - 背景颜色索引
    @Published var backgroundColorIndex: Int {
        didSet { defaults.set(backgroundColorIndex, forKey: Keys.backgroundColorIndex) }
    }
    
    // MARK: - 文字颜色索引
    @Published var textColorIndex: Int {
        didSet { defaults.set(textColorIndex, forKey: Keys.textColorIndex) }
    }
    
    // MARK: - 字体
    @Published var fontFamily: String {
        didSet { defaults.set(fontFamily, forKey: Keys.fontFamily) }
    }
    
    // MARK: - 行间距
    @Published var lineSpacing: Double {
        didSet { defaults.set(lineSpacing, forKey: Keys.lineSpacing) }
    }
    
    // MARK: - 自定义字体列表
    @Published var customFonts: [String] {
        didSet { defaults.set(customFonts, forKey: Keys.customFonts) }
    }
    
    // MARK: - 下载的字体URL列表
    @Published var downloadedFontURLs: [String] {
        didSet { defaults.set(downloadedFontURLs, forKey: Keys.downloadedFontURLs) }
    }
    
    // MARK: - 浅色模式背景色选项
    static let lightBackgroundColors: [(name: String, color: String)] = [
        ("白色", "#FFFFFF"),
        ("护眼米色", "#F5F5DC"),
        ("纸质黄", "#FFF8DC")
    ]
    
    // MARK: - 深色模式背景色选项
    static let darkBackgroundColors: [(name: String, color: String)] = [
        ("深色", "#1C1C1E"),
        ("黑色", "#000000"),
        ("深灰", "#2D2D2D")
    ]
    
    // MARK: - 浅色模式文字颜色选项
    static let lightTextColors: [(name: String, color: String)] = [
        ("黑色", "#000000"),
        ("深灰", "#333333")
    ]
    
    // MARK: - 深色模式文字颜色选项
    static let darkTextColors: [(name: String, color: String)] = [
        ("白色", "#FFFFFF"),
        ("浅灰", "#E5E5E5")
    ]
    
    // MARK: - 内置字体选项
    static let builtInFonts: [(name: String, displayName: String, isChinese: Bool)] = [
        ("System", "系统默认", false),
        ("Georgia", "Georgia", false),
        ("Times New Roman", "Times New Roman", false),
        ("Helvetica", "Helvetica", false),
        ("PingFang SC", "苹果丽黑", true),
        ("STHeiti", "华文黑体", true),
        ("STKaiti", "华文楷体", true),
        ("STSong", "华文宋体", true),
        ("STFangsong", "华文仿宋", true),
        ("Hiragino Sans GB", "冬青黑体", true),
        ("Songti SC", "宋体", true),
        ("Heiti SC", "黑体", true),
        ("Kaiti SC", "楷体", true),
        ("Fangsong SC", "仿宋", true),
    ]
    
    // MARK: - 所有可用字体（包括内置和自定义）
    var availableFonts: [(name: String, displayName: String, isChinese: Bool)] {
        var fonts = Self.builtInFonts
        // 添加自定义字体
        for fontName in customFonts {
            fonts.append((name: fontName, displayName: fontName, isChinese: true))
        }
        return fonts
    }
    
    // MARK: - 获取字体的显示名称
    func fontDisplayName(for fontName: String) -> String {
        if let font = availableFonts.first(where: { $0.name == fontName }) {
            return font.displayName
        }
        return fontName
    }
    
    // MARK: - 初始化
    private init() {
        self.fontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? 16
        self.colorSchemeOverride = defaults.object(forKey: Keys.colorSchemeOverride) as? Int ?? 0
        self.backgroundColorIndex = defaults.object(forKey: Keys.backgroundColorIndex) as? Int ?? 0
        self.textColorIndex = defaults.object(forKey: Keys.textColorIndex) as? Int ?? 0
        self.fontFamily = defaults.string(forKey: Keys.fontFamily) ?? "System"
        self.lineSpacing = defaults.object(forKey: Keys.lineSpacing) as? Double ?? 6
        self.customFonts = defaults.stringArray(forKey: Keys.customFonts) ?? []
        self.downloadedFontURLs = defaults.stringArray(forKey: Keys.downloadedFontURLs) ?? []
    }
    
    // MARK: - 获取当前背景色
    var currentBackgroundColor: String {
        let colors = isDarkMode ? Self.darkBackgroundColors : Self.lightBackgroundColors
        let index = min(backgroundColorIndex, colors.count - 1)
        return colors[max(0, index)].color
    }
    
    // MARK: - 获取当前文字颜色
    var currentTextColor: String {
        let colors = isDarkMode ? Self.darkTextColors : Self.lightTextColors
        let index = min(textColorIndex, colors.count - 1)
        return colors[max(0, index)].color
    }
    
    // MARK: - 判断是否使用深色模式
    var isDarkMode: Bool {
        colorSchemeOverride == 2
    }
    
    // MARK: - 获取当前字体的 Font
    var currentFont: Font {
        let fontSize = self.fontSize
        switch fontFamily {
        case "System":
            return .system(size: fontSize)
        case "Georgia":
            return .custom("Georgia", size: fontSize)
        case "Times New Roman":
            return .custom("Times New Roman", size: fontSize)
        case "Helvetica":
            return .custom("Helvetica", size: fontSize)
        default:
            // 尝试使用自定义字体
            if UIFont(name: fontFamily, size: CGFloat(fontSize)) != nil {
                return .custom(fontFamily, size: fontSize)
            }
            // 如果字体不可用，回退到系统字体
            return .system(size: fontSize)
        }
    }
    
    // MARK: - 添加自定义字体
    func addCustomFont(name: String) {
        if !customFonts.contains(name) {
            customFonts.append(name)
        }
    }
    
    // MARK: - 移除自定义字体
    func removeCustomFont(name: String) {
        customFonts.removeAll { $0 == name }
    }
    
    // MARK: - 获取字体目录
    static var fontsDirectory: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fontsDir = documentsDir.appendingPathComponent("CustomFonts")
        
        if !FileManager.default.fileExists(atPath: fontsDir.path) {
            try? FileManager.default.createDirectory(at: fontsDir, withIntermediateDirectories: true)
        }
        
        return fontsDir
    }
    
    // MARK: - 重置为默认值
    func resetToDefaults() {
        fontSize = 16
        colorSchemeOverride = 0
        backgroundColorIndex = 0
        textColorIndex = 0
        fontFamily = "System"
        lineSpacing = 6
    }
}

// MARK: - 字体下载服务
class FontDownloadService: ObservableObject {
    static let shared = FontDownloadService()
    
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var downloadedFonts: [String: String] = [:] // name: path
    
    private init() {
        loadDownloadedFonts()
    }
    
    // MARK: - 加载已下载的字体
    private func loadDownloadedFonts() {
        let fontsDir = ReaderSettings.fontsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: fontsDir.path) else {
            return
        }
        
        for file in files {
            let ext = (file as NSString).pathExtension.lowercased()
            if ext == "ttf" || ext == "otf" {
                let fontName = (file as NSString).deletingPathExtension
                downloadedFonts[fontName] = fontsDir.appendingPathComponent(file).path
                
                // 注册字体
                registerFont(name: fontName, path: fontsDir.appendingPathComponent(file).path)
            }
        }
    }
    
    // MARK: - 下载字体
    func downloadFont(from urlString: String, fontName: String) async -> Bool {
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0
            errorMessage = nil
        }
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                errorMessage = "无效的 URL"
                isDownloading = false
            }
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    errorMessage = "下载失败：服务器返回错误"
                    isDownloading = false
                }
                return false
            }
            
            await MainActor.run {
                downloadProgress = 0.5
            }
            
            // 保存字体文件
            let fontsDir = ReaderSettings.fontsDirectory
            let fileName = "\(fontName).\(url.lastPathComponent.components(separatedBy: ".").last ?? "ttf")"
            let filePath = fontsDir.appendingPathComponent(fileName)
            
            try data.write(to: filePath)
            
            // 注册字体
            registerFont(name: fontName, path: filePath.path)
            
            // 更新已下载字体列表
            await MainActor.run {
                downloadedFonts[fontName] = filePath.path
                ReaderSettings.shared.addCustomFont(name: fontName)
                downloadProgress = 1.0
                isDownloading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                errorMessage = "下载失败：\(error.localizedDescription)"
                isDownloading = false
            }
            return false
        }
    }
    
    // MARK: - 注册字体
    private func registerFont(name: String, path: String) {
        var fontError: Unmanaged<CFError>?
        guard let fontURL = URL(string: "file://\(path)"),
              let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
              let cgFont = CGFont(fontDataProvider) else {
            return
        }
        
        if !CTFontManagerRegisterGraphicsFont(cgFont, &fontError) {
            // 字体可能已经注册
            if let error = fontError?.takeRetainedValue() {
                print("Font registration error: \(error)")
            }
        }
    }
    
    // MARK: - 删除字体
    func deleteFont(name: String) {
        guard let path = downloadedFonts[name] else { return }
        
        try? FileManager.default.removeItem(atPath: path)
        downloadedFonts.removeValue(forKey: name)
        ReaderSettings.shared.removeCustomFont(name: name)
    }
}
