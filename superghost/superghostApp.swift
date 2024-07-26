//
//  superghostApp.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import SwiftData
import RevenueCat

@main
struct superghostApp: App {
    init(){
        Purchases.logLevel = .error
        try! Purchases.configure(withAPIKey: String(contentsOf: Bundle.main.resourceURL!.appending(path: "revenuecatkey.txt")).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @CloudStorage("isSuperghost") private var isSuperghost = false
    @StateObject var viewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: GameStat.self)
                .environmentObject(viewModel)
#if os(macOS)
                .frame(minHeight: 500)
#endif
        }
#if os(macOS)
        Settings {
            SettingsView(isSuperghost: isSuperghost) {
                NSApp.keyWindow?.close()
                NSApp.mainWindow?.becomeFirstResponder()

            }
            .modelContainer(for: GameStat.self)
            .environmentObject(viewModel)

        }
#endif
    }
}
