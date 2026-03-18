import Foundation

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
    
    // MARK: - 字体选项
    static let fonts = [
        "System",
        "Georgia",
        "Times New Roman",
        "Helvetica"
    ]
    
    // MARK: - 初始化
    private init() {
        self.fontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? 16
        self.colorSchemeOverride = defaults.object(forKey: Keys.colorSchemeOverride) as? Int ?? 0
        self.backgroundColorIndex = defaults.object(forKey: Keys.backgroundColorIndex) as? Int ?? 0
        self.textColorIndex = defaults.object(forKey: Keys.textColorIndex) as? Int ?? 0
        self.fontFamily = defaults.string(forKey: Keys.fontFamily) ?? "System"
        self.lineSpacing = defaults.object(forKey: Keys.lineSpacing) as? Double ?? 6
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
