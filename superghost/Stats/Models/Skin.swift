//
//  Skin.swift
//  superghost
//
//  Created by Hannes Nagel on 12/5/24.
//

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif
import GameKit

struct Skin : Identifiable, Equatable{
    var id = UUID()
    var image: String

    var unlockBy: UnlockReason

    enum UnlockReason: Equatable {
        case widget, score(at: Int), rank(at: Int), playedMatches(count: Int), winInMessages, superghost

        var lockedDescription: String {
            switch self {
            case .widget:
                "Add a Widget"
            case .score(let score):
                "Earn a score of \(score)"
            case .rank(let rank):
                "Become \(rank.ordinalString()) on the Leaderboard"
            case .playedMatches(let count):
                "Play \(count) matches"
            case .winInMessages:
                "Win a Game In Messages"
            case .superghost:
                "Become a superghost to unlock"
            }
        }
    }
    static let skin = Skin(image: "Skin/Cowboy", unlockBy: .score(at: 0))
    static let cowboy = Skin(image: "Skin/Cowboy", unlockBy: .score(at: 0))
    static let sailor = Skin(image: "Skin/Sailor", unlockBy: .widget)
    static let doctor = Skin(image: "Skin/Doctor", unlockBy: .playedMatches(count: 20))
    static let knight = Skin(image: "Skin/Knight", unlockBy: .winInMessages)
    static let engineer = Skin(image: "Skin/Engineer", unlockBy: .rank(at: 2))
    static let samurai = Skin(image: "Skin/Samurai", unlockBy: .score(at: 1700))
    static let christmas = Skin(image: "Skin/Christmas", unlockBy: .superghost)

    static let skins = [
        cowboy,
        sailor,
        doctor,
        knight,
        engineer,
        samurai,
        christmas
    ]
}

extension Int {
    func ordinalString() -> String {
        let suffix: String

        // Handle special cases like 11th, 12th, 13th
        let lastTwoDigits = self % 100
        if lastTwoDigits >= 11 && lastTwoDigits <= 13 {
            suffix = "th"
        } else {
            // Otherwise use 1st, 2nd, 3rd, etc.
            switch self % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }

        return "\(self)\(suffix)"
    }
}
