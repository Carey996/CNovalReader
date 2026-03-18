import SwiftUI

struct ReaderSettingsView: View {
    @ObservedObject var settings = ReaderSettings.shared
    @StateObject private var fontDownloadService = FontDownloadService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showResetConfirmation = false
    @State private var showFontDownloadSheet = false
    @State private var fontDownloadURL = ""
    @State private var fontDownloadName = ""
    
    private var isDarkMode: Bool {
        if settings.colorSchemeOverride == 0 {
            return colorScheme == .dark
        }
        return settings.colorSchemeOverride == 2
    }
    
    private var currentBackgroundColors: [(name: String, color: String)] {
        isDarkMode ? ReaderSettings.darkBackgroundColors : ReaderSettings.lightBackgroundColors
    }
    
    private var currentTextColors: [(name: String, color: String)] {
        isDarkMode ? ReaderSettings.darkTextColors : ReaderSettings.lightTextColors
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 主题模式
                Section("主题模式") {
                    Picker("显示模式", selection: $settings.colorSchemeOverride) {
                        Text("跟随系统").tag(0)
                        Text("浅色模式").tag(1)
                        Text("深色模式").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                
                // 字体大小
                Section("字体") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("字体大小")
                            Spacer()
                            Text("\(Int(settings.fontSize))pt")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "textformat.size.smaller")
                                .foregroundColor(.secondary)
                            
                            Slider(value: $settings.fontSize, in: 12...32, step: 1)
                                .tint(.blue)
                            
                            Image(systemName: "textformat.size.larger")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 字体选择
                Section("字体") {
                    Picker("字体", selection: $settings.fontFamily) {
                        // 内置字体
                        Section(header: Text("内置字体")) {
                            ForEach(ReaderSettings.builtInFonts, id: \.name) { font in
                                Text(font.displayName).tag(font.name)
                            }
                        }
                        
                        // 自定义字体
                        if !settings.customFonts.isEmpty {
                            Section(header: Text("自定义字体")) {
                                ForEach(settings.customFonts, id: \.self) { fontName in
                                    Text(fontName).tag(fontName)
                                }
                            }
                        }
                    }
                    
                    Button {
                        showFontDownloadSheet = true
                    } label: {
                        Label("下载自定义字体", systemImage: "arrow.down.circle")
                    }
                }
                
                // 行间距
                Section("间距") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("行间距")
                            Spacer()
                            Text("\(Int(settings.lineSpacing))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $settings.lineSpacing, in: 0...20, step: 1)
                            .tint(.blue)
                    }
                    .padding(.vertical, 4)
                }
                
                // 背景颜色
                Section("主题") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("背景色")
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
                            ForEach(0..<currentBackgroundColors.count, id: \.self) { index in
                                Button {
                                    settings.backgroundColorIndex = index
                                } label: {
                                    VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hex: currentBackgroundColors[index].color) ?? .white)
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(settings.backgroundColorIndex == index ? Color.blue : Color.gray.opacity(0.3),
                                                            lineWidth: settings.backgroundColorIndex == index ? 3 : 1)
                                            )
                                            .overlay(
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(isDarkMode ? .white : .blue)
                                                    .font(.caption.bold())
                                            )
                                        
                                        Text(currentBackgroundColors[index].name)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 文字颜色
                Section("文字") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("文字颜色")
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
                            ForEach(0..<currentTextColors.count, id: \.self) { index in
                                Button {
                                    settings.textColorIndex = index
                                } label: {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(Color(hex: currentTextColors[index].color) ?? .black)
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Circle()
                                                    .stroke(settings.textColorIndex == index ? Color.blue : Color.gray.opacity(0.3),
                                                            lineWidth: settings.textColorIndex == index ? 3 : 1)
                                            )
                                            .overlay(
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(settings.textColorIndex == index ? (isDarkMode ? .black : .blue) : .clear)
                                                    .font(.caption.bold())
                                            )
                                        
                                        Text(currentTextColors[index].name)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 预览
                Section {
                    ReaderPreviewView(isDarkMode: isDarkMode)
                        .frame(height: 120)
                        .listRowInsets(EdgeInsets())
                } header: {
                    Text("预览")
                }
                
                // 重置
                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("恢复默认设置")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("恢复默认设置", isPresented: $showResetConfirmation) {
                Button("恢复", role: .destructive) { settings.resetToDefaults() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确定要恢复所有设置为默认值吗？")
            }
            .sheet(isPresented: $showFontDownloadSheet) {
                FontDownloadSheet(isPresented: $showFontDownloadSheet)
            }
        }
    }
}

// MARK: - 字体下载表单
struct FontDownloadSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var fontDownloadService = FontDownloadService.shared
    @State private var fontURL = ""
    @State private var fontName = ""
    @State private var isDownloading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("字体名称", text: $fontName)
                        .autocapitalization(.none)
                    
                    TextField("字体下载链接 (TTF/OTF)", text: $fontURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                } header: {
                    Text("字体信息")
                } footer: {
                    Text("请提供有效的 TTF 或 OTF 字体文件下载链接")
                }
                
                Section("已下载的字体") {
                    if fontDownloadService.downloadedFonts.isEmpty {
                        Text("暂无自定义字体")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(fontDownloadService.downloadedFonts.keys.sorted()), id: \.self) { fontName in
                            HStack {
                                Text(fontName)
                                Spacer()
                                Button(role: .destructive) {
                                    fontDownloadService.deleteFont(name: fontName)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        downloadFont()
                    } label: {
                        HStack {
                            Spacer()
                            if isDownloading {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("下载中...")
                            } else {
                                Text("下载字体")
                            }
                            Spacer()
                        }
                    }
                    .disabled(fontURL.isEmpty || fontName.isEmpty || isDownloading)
                }
            }
            .navigationTitle("下载字体")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
            .alert("下载失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: fontDownloadService.isDownloading) { _, newValue in
                isDownloading = newValue
            }
            .onChange(of: fontDownloadService.errorMessage) { _, newValue in
                if let error = newValue {
                    errorMessage = error
                    showError = true
                }
            }
        }
    }
    
    private func downloadFont() {
        isDownloading = true
        Task {
            let success = await fontDownloadService.downloadFont(from: fontURL, fontName: fontName)
            await MainActor.run {
                isDownloading = false
                if success {
                    fontURL = ""
                    fontName = ""
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - 预览视图

struct ReaderPreviewView: View {
    @ObservedObject var settings = ReaderSettings.shared
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("示例文字")
                .font(.headline)
                .foregroundColor(Color(hex: settings.currentTextColor) ?? (isDarkMode ? .white : .black))
            
            Text("这是预览效果，会根据您当前的设置显示。调整字体大小、背景色和文字颜色来获得最佳的阅读体验。")
                .font(.system(size: settings.fontSize))
                .foregroundColor(Color(hex: settings.currentTextColor) ?? (isDarkMode ? .white : .black))
                .lineSpacing(settings.lineSpacing)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: settings.currentBackgroundColor) ?? (isDarkMode ? Color(hex: "#1C1C1E")! : .white))
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ReaderSettingsView()
}
