//
//  InstancePlaceholders.swift
//  Messages Extension
//
//  Created by Hannes Nagel on 9/18/24.
//

import Foundation

@MainActor
final class GKStore: ObservableObject {
    static let shared = GKStore()
    
    func loadAchievements() async throws {}
    func loadData() async throws {}
}
