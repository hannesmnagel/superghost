//
//  GameStat.swift
//  superghost
//
//  Created by Hannes Nagel on 7/10/24.
//

import Foundation
import SwiftData

@Model
class GameStat: Hashable, Identifiable {
    let player2: String
    let won: Bool
    let word: String
    let withInvitation: Bool
    let createdAt = Date()
    @Attribute(.unique) public var id = UUID()

    init(player2: String, withInvitation: Bool, won: Bool, word: String, id: String) {
        self.id = UUID(uuidString: id) ?? UUID()
        self.player2 = player2
        self.won = won
        self.word = word
        self.withInvitation = withInvitation
    }
}
