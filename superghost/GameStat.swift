//
//  GameStat.swift
//  superghost
//
//  Created by Hannes Nagel on 7/10/24.
//

import Foundation
import GameKit

struct GameStat: Codable, Hashable, Identifiable {
    var player2: String = "no player"
    var won: Bool = Bool.random()
    var word: String = "sth went wrong"
    var withInvitation: Bool = Bool.random()
    var createdAt = Date()
    public var id = UUID()

    init(player2: String, withInvitation: Bool, won: Bool, word: String, id: String) {
        self.id = UUID(uuidString: id) ?? UUID()
        self.player2 = player2
        self.won = won
        self.word = word
        self.withInvitation = withInvitation
    }
    func save() throws {
        let data = try JSONEncoder().encode(self)
        GKLocalPlayer.local.saveGameData(data, withName: id.uuidString)
    }
    static func loadAll() async throws -> [GameStat] {
        let games = try await GKLocalPlayer.local.fetchSavedGames().concurrentMap {
            do{
                let data = try await $0.loadData()
                let decoded = try? JSONDecoder().decode(Self.self, from: data)
                return decoded
            } catch {
                return nil
            }
        }
        return games.compactMap{$0}
    }

    static func submitScore(_ score: Int) async throws {
        let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: ["global.score"])
        for leaderboard in leaderboards{
            try await leaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local)
        }
    }
}

extension Array where Element == GameStat {
    var won: Self {filter{$0.won}}
    var lost: Self {filter{!$0.won}}
    var winningRate: Double {
        isEmpty ? 0.0 : Double(won.count)/Double(count)
    }
    var winningStreak : Int { sorted{$0.createdAt > $1.createdAt}.firstIndex(where: {!$0.won}) ?? count}
    var today: Self {filter{Calendar.current.isDateInToday($0.createdAt)}}
    var recent: Self {filter{Calendar.current.isDate($0.createdAt, equalTo: Date(), toGranularity: .month)}}
    var withInvitation: Self {filter{$0.withInvitation}}

}
