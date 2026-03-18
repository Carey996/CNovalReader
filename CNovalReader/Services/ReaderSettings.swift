import Foundation

/// 全局阅读设置
class ReaderSettings: ObservableObject {
    static let shared = ReaderSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let fontSize = "reader_fontSize"
        static let backgroundColor = "reader_backgroundColor"
        static let textColor = "reader_textColor"
        static let fontFamily = "reader_fontFamily"
        static let lineSpacing = "reader_lineSpacing"
    }
    
    // MARK: - 字体大小
    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }
    
    // MARK: - 背景颜色 (0=白色, 1=浅灰, 2=深色, 3=黑色)
    @Published var backgroundColorIndex: Int {
        didSet { defaults.set(backgroundColorIndex, forKey: Keys.backgroundColor) }
    }
    
    // MARK: - 文字颜色
    @Published var textColorIndex: Int {
        didSet { defaults.set(textColorIndex, forKey: Keys.textColor) }
    }
    
    // MARK: - 字体
    @Published var fontFamily: String {
        didSet { defaults.set(fontFamily, forKey: Keys.fontFamily) }
    }
    
    // MARK: - 行间距
    @Published var lineSpacing: Double {
        didSet { defaults.set(lineSpacing, forKey: Keys.lineSpacing) }
    }
    
    // MARK: - 背景色选项
    static let backgroundColors: [(name: String, color: String)] = [
        ("White", "#FFFFFF"),
        ("Sepia", "#F4ECD8"),
        ("Dark", "#2D2D2D"),
        ("Black", "#000000")
    ]
    
    // MARK: - 文字颜色选项
    static let textColors: [(name: String, color: String)] = [
        ("Black", "#000000"),
        ("Gray", "#666666"),
        ("White", "#FFFFFF"),
        ("Gray (Dark)", "#AAAAAA")
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
        self.backgroundColorIndex = defaults.object(forKey: Keys.backgroundColor) as? Int ?? 0
        self.textColorIndex = defaults.object(forKey: Keys.textColor) as? Int ?? 0
        self.fontFamily = defaults.string(forKey: Keys.fontFamily) ?? "System"
        self.lineSpacing = defaults.object(forKey: Keys.lineSpacing) as? Double ?? 6
    }
    
    // MARK: - 获取背景色
    var backgroundColor: String {
        ReaderSettings.backgroundColors[backgroundColorIndex].color
    }
    
    // MARK: - 获取文字颜色
    var textColor: String {
        ReaderSettings.textColors[textColorIndex].color
    }
    
    // MARK: - 重置为默认值
    func resetToDefaults() {
        fontSize = 16
        backgroundColorIndex = 0
        textColorIndex = 0
        fontFamily = "System"
        lineSpacing = 6
    }
}
