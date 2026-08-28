//
//  hypertensionApp.swift
//  hypertension
//
//  Created by Haoyu Zuo on 2026/6/27.
//

import SwiftUI
import SwiftData

@main
struct hypertensionApp: App {
    @StateObject private var languageStore = AppLanguageStore()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            BloodPressureReading.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.light)
                .environmentObject(languageStore)
                .environment(\.locale, languageStore.locale)
                .id(languageStore.selectedLanguage)
        }
        .modelContainer(sharedModelContainer)
    }
}
