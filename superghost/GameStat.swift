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
    var player2profile: PlayerProfile?
    var won: Bool = Bool.random()
    var word: String = "sth went wrong"
    var withInvitation: Bool = Bool.random()
    var createdAt = Date()
    public var id = UUID()

    init(player2: (id: String, profile: PlayerProfile?), withInvitation: Bool, won: Bool, word: String, id: String) {
        self.id = UUID(uuidString: id) ?? UUID()
        self.player2 = player2.id
        self.player2profile = player2.profile
        self.won = won
        self.word = word
        self.withInvitation = withInvitation
    }
    func save() throws {
        let data = try JSONEncoder().encode(self)
        GKLocalPlayer.local.saveGameData(data, withName: id.uuidString)
    }
    static func loadAll() async throws -> [GameStat] {
        do{
            let fetchedGames = try await GKLocalPlayer.local.fetchSavedGames()
            let games = await fetchedGames.asyncMap {
                do{
                    let data = try await $0.loadData()
                    let decoded = try? JSONDecoder().decode(Self.self, from: data)
                    return decoded
                } catch {
                    return nil
                }
            }
            return games.compactMap{$0}
        } catch {
            Logger.score.error("Could not load saved games: \(error)")
            Logger.trackEvent("game_loading_failed", with: ["error" : String(describing: error)])
            throw error
        }
    }

    static func submitScore(_ score: Int) async throws {
        guard GKLocalPlayer.local.isAuthenticated else {Logger.general.error("\(#function, privacy: .public) failed: Not authenticated"); return}

        let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: ["global.score"])
        for leaderboard in leaderboards{
            try await leaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local)
        }
        Task.detached{
            try await reportAchievement(.lowScore, percent: Double(score)/2000.0 * 100)
            try await reportAchievement(.midScore, percent: Double(score)/2500.0 * 100)
            try await reportAchievement(.highScore, percent: Double(score)/3000.0 * 100)
            try await reportAchievement(.leaderboardUnlock, percent: Double(score)/1050.0 * 100)
            try await GKStore.shared.loadAchievements()
            try await GKStore.shared.loadData()
            try? await Task.sleep(for: .seconds(3))
            try await GKStore.shared.loadAchievements()
            try await GKStore.shared.loadData()
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

enum Achievement: String, CaseIterable {
    case lowScore = "score.low", midScore = "score.mid", highScore = "score.high", longWord = "word.long", friendAdd = "friend.add", leaderboardUnlock = "leaderboard.unlock", widgetAdd = "widget.add"
}

nonisolated func reportAchievement(_ achievement: Achievement, percent: Double) async throws {
    do{
        guard Bundle.main.bundleIdentifier == "com.nagel.superghost" else {
            NSUbiquitousKeyValueStore.default.set(percent, forKey: achievement.rawValue)
            Logger.achievements.warning("Player not authenticated. Achievement stored for later reporting.")
            return
        }
        guard GKLocalPlayer.local.isAuthenticated else {Logger.general.error("\(#function, privacy: .public) failed: Not authenticated"); return}
        
        let achievements = try await GKAchievement.loadAchievements()
        guard !achievements.contains(where: {$0.isCompleted && $0.identifier == achievement.rawValue}) else {return}

        let achievement = GKAchievement(identifier: achievement.rawValue)
        achievement.showsCompletionBanner = true
        achievement.percentComplete = percent
        NSUbiquitousKeyValueStore.default.set(percent, forKey: achievement.identifier)
        try await GKAchievement.report([achievement])

        guard percent >= 100 else {return}
        await showMessage("You earned an Achievement!")
        
        let achievementId = achievement.identifier
        Task{
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run{
                if #available(iOSApplicationExtension 18.0, macOSApplicationExtension 15.0, *) {
                    GKAccessPoint.shared.trigger(achievementID: achievementId){}
                }
            }
        }
        Logger.achievements.info("Logged achievement \(achievement.identifier, privacy: .public)")
    } catch {
        Logger.achievements.error("Failed to log achievement \(achievement.rawValue, privacy: .public) with error: \(error, privacy: .public)")
        throw error
    }
}
