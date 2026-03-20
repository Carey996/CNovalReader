//
//  CNovalReaderApp.swift
//  CNovalReader
//
//  Created by 陈凯瑞 on 2026/2/2.
//

import SwiftUI
import SwiftData

@main
struct CNovalReaderApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Book.self])
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storeURL = documentsURL.appendingPathComponent("default.store")

        // 删除所有可能的旧 store 相关文件（避免 SwiftData Schema 变化后崩溃）
        let storeDirectory = documentsURL
        if let files = try? FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix("default.store") {
                try? FileManager.default.removeItem(at: file)
            }
        }

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none  // 禁用 iCloud，避免 iOS 26 云同步问题
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
