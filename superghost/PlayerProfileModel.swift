//
//  PlayerProfileModel.swift
//  superghost
//
//  Created by Hannes Nagel on 10/4/24.
//

import SwiftUI
import GameKit

final class PlayerProfileModel: ObservableObject {
    @Published var player: PlayerProfile {
        didSet {
            if let data = try? JSONEncoder().encode(player){
                NSUbiquitousKeyValueStore.default.set(data, forKey: "playerProfile")
            }

        }
    }

    static let shared = PlayerProfileModel()

    private init() {
        if let data = NSUbiquitousKeyValueStore.default.data(forKey: "playerProfile"),
           let player = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            self.player = player
        } else {
            self.player = .init(name: GKLocalPlayer.local.alias)
        }
    }
}
