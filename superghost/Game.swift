//
//  Move.swift
//  superghost
//
//  Created by Hannes Nagel on 7/10/24.
//

import Foundation

struct Game: Equatable {
    var id: String = UUID().uuidString

    var player1Id = ""
    var player1profile: PlayerProfile?

    var player2Id = ""
    var player2profile: PlayerProfile = [
        PlayerProfile(image: Skin.christmas.image, name: "Heinz Gustav"),
        PlayerProfile(image: Skin.doctor.image, name: "Otto128"),
        PlayerProfile(image: Skin.samurai.image, name: "TressG"),
        PlayerProfile(image: Skin.engineer.image, name: "ShitHappens")
    ].randomElement()!

    var isBlockingMoveForPlayerOne = true

    var player1Wins = Bool?.none

    var player1Challenges = Bool?.none

    var rematchGameId = String?.none
    
    var isSuperghost: Bool

    var word = ""

    var createdAt: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter.string(from: Date())
    }()

    var lastMoveAt = Date()

    var winningPlayerId: String? {
        if let player1Wins {
            player1Wins ? player1Id : player2Id
        } else {
            nil
        }
    }
    var challengingUserId: String? {
        if let player1Challenges {
            player1Challenges ? player1Id : player2Id
        } else {
            nil
        }
    }

    var blockMoveForPlayerId: String {
        isBlockingMoveForPlayerOne ? player1Id : player2Id
    }

    var status: Status {
        if player2Id.isEmpty {
            return .open
        } else if rematchGameId != nil {
            return .rematch
        } else if let player1Wins {
            return player1Wins ? .player1Wins : .player2Wins
        } else if let player1Challenges {
            return player1Challenges ? .player1Challenges : .player2Challenges
        } else if isBlockingMoveForPlayerOne {
            return .player2Turn
        } else {
            return .player1Turn
        }
    }
    enum Status{
        case open, player1Turn, player2Turn, player1Wins, player2Wins, rematch, player1Challenges, player2Challenges
    }
}

import SwiftUI

struct PlayerProfile: Equatable, Codable, Hashable {
    var image: String?
    var rank: Int?
    var name: String

    var imageView: Image {
#if os(macOS)
        return Image(nsImage: .init(named: image ?? "Skin/Cowboy") ?? .init(named: "Skin/Cowboy")!)
#else
        return Image(uiImage: .init(named: image ?? "Skin/Cowboy") ?? .init(named: "Skin/Cowboy")!)
#endif
    }
    var color: Color {
        switch image ?? ""{
        case Skin.christmas.image:
                .red.opacity(0.5)
        case Skin.doctor.image:
                .gray.opacity(0.2)
        case Skin.samurai.image:
                .gray
        case Skin.sailor.image:
                .blue.opacity(0.2)
        case Skin.knight.image:
                .gray.opacity(0.3)
        default:
                .brown.opacity(0.4)
        }
    }
}
