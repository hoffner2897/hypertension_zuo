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
        }
        .modelContainer(sharedModelContainer)
    }
}
