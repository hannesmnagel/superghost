//
//  InstancePlaceholders.swift
//  gamestatsWidgetExtension
//
//  Created by Hannes Nagel on 9/18/24.
//

import Foundation

final class GKStore: ObservableObject {
    static let shared = GKStore()

    func loadAchievements() async throws {}
}
