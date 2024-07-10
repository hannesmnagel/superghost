//
//  Move.swift
//  superghost
//
//  Created by Hannes Nagel on 7/10/24.
//

import Foundation

struct Game: Codable, Equatable {
    let id: String
    var player1Id: String
    var player2Id: String

    var blockMoveForPlayerId: String
    var winningPlayerId: String = ""
    var challengingUserId: String = ""
    var rematchPlayerId: [String]

    var moves: [Move]

    var createdAt : String = Date().ISO8601Format()
}

struct Move: Codable, Equatable {

    let isPlayer1: Bool
    let word: String
}
