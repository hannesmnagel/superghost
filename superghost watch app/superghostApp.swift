//
//  superghostApp.swift
//  superghost Watch App
//
//  Created by Hannes Nagel on 6/28/24.
//

import SwiftUI
import RevenueCat

@main
struct superghost_Watch_AppApp: App {
    init(){
        Purchases.logLevel = .error
        try! Purchases.configure(withAPIKey: String(contentsOf: Bundle.main.resourceURL!.appending(path: "revenuecatkey.txt")).trimmingCharacters(in: .whitespacesAndNewlines))
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: GameStat.self)
        }
    }
}
