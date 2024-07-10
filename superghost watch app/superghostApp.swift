//
//  superghostApp.swift
//  superghost Watch App
//
//  Created by Hannes Nagel on 6/28/24.
//

import SwiftUI

@main
struct superghost_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: GameStat.self)
        }
    }
}
