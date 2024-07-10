//
//  superghostApp.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import SwiftData

@main
struct superghostApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: GameStat.self)
        }
    }
}