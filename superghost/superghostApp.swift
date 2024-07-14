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
        Purchases.logLevel = .debug
        try! Purchases.configure(withAPIKey: String(contentsOf: Bundle.main.resourceURL!.appending(path: "revenuecatkey.txt")))
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: GameStat.self)
        }
    }
}
