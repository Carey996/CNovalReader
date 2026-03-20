import AVFoundation
import Combine
import SwiftUI

// MARK: - TTS 朗读服务

/// TTS 朗读服务 - 使用 AVSpeechSynthesizer
@MainActor
class TTSService: NSObject, ObservableObject {
    
    static let shared = TTSService()
    
    // MARK: - Published 属性
    @Published var isPlaying: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentChapterIndex: Int = 0
    @Published var progress: Double = 0  // 0.0 - 1.0
    
    // MARK: - 配置
    @Published var voiceIdentifier: String = "com.apple.voice.premium.zh-CN.Yunxi"
    @Published var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    @Published var pitchMultiplier: Float = 1.0
    
    // MARK: - 可用声音列表
    var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix("zh") || voice.language.hasPrefix("en")
        }.sorted { $0.name < $1.name }
    }
    
    // MARK: - 中文声音
    var chineseVoices: [AVSpeechSynthesisVoice] {
        availableVoices.filter { $0.language.hasPrefix("zh") }
    }
    
    // MARK: - 私有属性
    private let synthesizer = AVSpeechSynthesizer()
    private var chapters: [any ReadableChapter] = []
    private var currentText: String = ""
    private var totalCharacters: Int = 0
    private var spokenCharacters: Int = 0
    
    // 章节段落文本（用于进度计算）
    private var chapterStartIndices: [Int] = []
    
    override init() {
        super.init()
        synthesizer.delegate = self
        
        // 设置音频会话
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("TTS Audio session setup failed: \(error)")
        }
        
        // 加载保存的声音偏好
        if let savedVoice = UserDefaults.standard.string(forKey: "TTSVoiceIdentifier") {
            voiceIdentifier = savedVoice
        }
        speechRate = UserDefaults.standard.float(forKey: "TTSSpeechRate")
        if speechRate == 0 { speechRate = AVSpeechUtteranceDefaultSpeechRate }
    }
    
    // MARK: - 公开方法
    
    /// 配置章节内容（支持任意符合 ReadableChapter 协议的类型）
    func configure(chapters: [any ReadableChapter], startChapter: Int = 0) {
        self.chapters = chapters
        self.currentChapterIndex = startChapter
        
        // 计算章节起始位置
        chapterStartIndices = [0]
        var cumulative = 0
        for chapter in chapters {
            cumulative += chapter.chapterContent.count
            chapterStartIndices.append(cumulative)
        }
        totalCharacters = cumulative
    }
    
    /// 开始朗读
    func play() {
        guard !chapters.isEmpty else { return }
        
        if isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
            isPlaying = true
        } else {
            speakChapter(at: currentChapterIndex)
            isPlaying = true
        }
    }
    
    /// 暂停
    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
            isPaused = true
            isPlaying = false
        }
    }
    
    /// 停止
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        currentChapterIndex = 0
        spokenCharacters = 0
        progress = 0
    }
    
    /// 跳转到章节
    func jumpToChapter(_ index: Int) {
        guard index >= 0 && index < chapters.count else { return }
        
        let wasPlaying = isPlaying
        synthesizer.stopSpeaking(at: .immediate)
        currentChapterIndex = index
        spokenCharacters = chapterStartIndices[index]
        
        if wasPlaying {
            speakChapter(at: index)
        }
    }
    
    /// 上一章
    func previousChapter() {
        if currentChapterIndex > 0 {
            jumpToChapter(currentChapterIndex - 1)
        }
    }
    
    /// 下一章
    func nextChapter() {
        if currentChapterIndex < chapters.count - 1 {
            jumpToChapter(currentChapterIndex + 1)
        }
    }
    
    /// 保存偏好设置
    func savePreferences() {
        UserDefaults.standard.set(voiceIdentifier, forKey: "TTSVoiceIdentifier")
        UserDefaults.standard.set(speechRate, forKey: "TTSSpeechRate")
    }
    
    // MARK: - 私有方法
    
    private func speakChapter(at index: Int) {
        guard index >= 0 && index < chapters.count else { return }
        
        let chapter = chapters[index]
        currentText = chapter.chapterContent
        currentChapterIndex = index
        
        let utterance = AVSpeechUtterance(string: currentText)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) ?? 
                         chineseVoices.first
        utterance.rate = speechRate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        
        // 设置中文语言的音调变化
        if voiceIdentifier.contains("zh") {
            // 根据句子结尾调整语调（感叹号略微升高）
            adjustUtteranceForEmotion(utterance, text: currentText)
        }
        
        synthesizer.speak(utterance)
    }
    
    /// 根据文本情绪调整语音参数
    private func adjustUtteranceForEmotion(_ utterance: AVSpeechUtterance, text: String) {
        // 简单策略：设置合理的默认参数
        // 复杂情绪分析需要 NLP，这里做基础版本
        
        // 如果文本中感叹号多，稍微提高音调
        let exclamationCount = text.filter { $0 == "!" || $0 == "！" || $0 == "?" || $0 == "？" }.count
        let exclamationRatio = Double(exclamationCount) / Double(text.count)
        
        if exclamationRatio > 0.02 {
            utterance.pitchMultiplier = 1.1  // 稍微提高音调
        } else if exclamationRatio > 0.05 {
            utterance.pitchMultiplier = 1.2  // 更高
        }
        
        // 问号多时略微降低
        if text.contains("？") || text.contains("?") {
            utterance.pitchMultiplier = 0.95
        }
    }
    
    private func updateProgress() {
        guard totalCharacters > 0 else {
            progress = 0
            return
        }
        
        // 计算当前进度
        let currentChapterStart = chapterStartIndices[currentChapterIndex]
        let chapterLength = chapters[currentChapterIndex].chapterContent.count
        let spokenInChapter = spokenCharacters - currentChapterStart
        let chapterProgress = chapterLength > 0 ? Double(spokenInChapter) / Double(chapterLength) : 0
        
        // 整体进度
        progress = Double(currentChapterIndex) / Double(chapters.count) + 
                   chapterProgress / Double(chapters.count)
        progress = min(1.0, max(0.0, progress))
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TTSService: AVSpeechSynthesizerDelegate {
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = true
            isPaused = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            spokenCharacters = chapterStartIndices[currentChapterIndex] + 
                              chapters[currentChapterIndex].chapterContent.count
            
            // 自动进入下一章
            if currentChapterIndex < chapters.count - 1 {
                nextChapter()
            } else {
                // 全部读完
                isPlaying = false
                isPaused = false
                progress = 1.0
            }
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPaused = true
            isPlaying = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = true
            isPaused = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = false
            isPaused = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            let chapterStart = chapterStartIndices[currentChapterIndex]
            spokenCharacters = chapterStart + characterRange.location + characterRange.length
            updateProgress()
        }
    }
}

// MARK: - TTS 设置视图
struct TTSSettingsView: View {
    @ObservedObject var tts = TTSService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("声音") {
                    ForEach(tts.chineseVoices, id: \.identifier) { voice in
                        Button {
                            tts.voiceIdentifier = voice.identifier
                            tts.savePreferences()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(voice.name)
                                    Text(voice.language)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if tts.voiceIdentifier == voice.identifier {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section("语速") {
                    Slider(value: $tts.speechRate, in: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate)
                    Text("\(Int((tts.speechRate / AVSpeechUtteranceDefaultSpeechRate - 1) * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("音调") {
                    Slider(value: $tts.pitchMultiplier, in: 0.5...1.5)
                    Text(String(format: "%.1fx", tts.pitchMultiplier))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button("测试朗读") {
                        let testUtterance = AVSpeechUtterance(string: "你好，这是小c读书的语音测试。")
                        testUtterance.voice = AVSpeechSynthesisVoice(identifier: tts.voiceIdentifier)
                        testUtterance.rate = tts.speechRate
                        testUtterance.pitchMultiplier = tts.pitchMultiplier
                        AVSpeechSynthesizer().speak(testUtterance)
                    }
                }
            }
            .navigationTitle("TTS 设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
