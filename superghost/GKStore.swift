//
//  GKStore.swift
//  superghost
//
//  Created by Hannes Nagel on 9/18/24.
//

import SwiftUI
import GameKit

@MainActor
class GKStore: ObservableObject {
    static let shared = GKStore()
    @Published var leaderboardData : [GKLeaderboard.Entry]?
    @Published var localPlayerEntry : GKLeaderboard.Entry?
    @Published var leaderboardTitle : String?
    @Published var leaderboardImage: Image?
    @Published var hasUnlockedLeaderboard = false
    private var leaderboard: GKLeaderboard?
    //--------------------------------
    @CloudStorage("score") private var score = 1000
    @CloudStorage("rank") private var rank = -1
    //--------------------------------
    @Published var achievements: [GKAchievement]?
    @Published var achievedAchievements: [(GKAchievementDescription, GKAchievement)]?
    @Published var unachievedAchievements: [(GKAchievementDescription, GKAchievement?)]?



    private func checkIfLeaderboardIsUnlocked() async {
        guard !hasUnlockedLeaderboard else {return}
        self.hasUnlockedLeaderboard = (try? await GKAchievement.loadAchievements().first(where: { $0.identifier == Achievement.leaderboardUnlock.rawValue })?.percentComplete) == 100
    }
    nonisolated private func loadInitialData() async throws {
        //starting achievements task because it doesn't need anything else
        let achievementsTask = Task {
            try await loadAchievements()
        }

        guard let leaderboard = try await GKLeaderboard.loadLeaderboards(IDs: ["global.score"]).first else {throw HKStoreError.noLeaderboard}
        guard let leaderboardTitle = leaderboard.title else {throw HKStoreError.noLeaderboardTitle}
        let leaderboardImage = try await withCheckedThrowingContinuation{con in
            leaderboard.loadImage { image, error in
                if let image {
                    con.resume(returning: Image(uiImage: image))
                } else {
                    con.resume(throwing: error!)
                }
            }

        }

        await MainActor.run{
            self.leaderboard = leaderboard
            self.leaderboardTitle = leaderboardTitle
            self.leaderboardImage = leaderboardImage
        }
        try await loadData()
        try await achievementsTask.value
    }
    nonisolated func loadAchievements() async throws {
        let achievements = try await GKAchievement.loadAchievements()
        let achievementDescriptions = try await GKAchievementDescription.loadAchievementDescriptions()

        let achieved = achievementDescriptions.compactMap{achievementDescription in
            if let achievement = achievements.first(where: {$0.identifier == achievementDescription.identifier}),
               achievement.isCompleted{
                (achievementDescription, achievement)
            } else { nil }
        }
        let unachieved = achievementDescriptions.compactMap{achievementDescription in
            let achievement = achievements.first(where: {$0.identifier == achievementDescription.identifier})
            if achievement?.isCompleted == true {
                return nil as (GKAchievementDescription, GKAchievement?)?
            } else {
                return (achievementDescription, achievement)
            }
        }
        await MainActor.run {
            self.achievedAchievements = achieved
            self.unachievedAchievements = unachieved
        }
    }
    nonisolated func loadData() async throws {
        await checkIfLeaderboardIsUnlocked()
        if await leaderboardImage == nil {
            try await loadInitialData()
        }

        let entries = try await leaderboard?.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...5))

        await MainActor.run{
            self.rank = localPlayerEntry?.rank ?? -1
            self.localPlayerEntry = entries?.0
            self.leaderboardData = entries?.1
        }
    }

    private init(){
        Task.detached(priority: .medium) {
            do {
                let timeout = Date() + 10
                while !GKLocalPlayer.local.isAuthenticated,
                      timeout > Date() {
                    try? await Task.sleep(for: .seconds(2))
                }
                try await self.loadInitialData()
            } catch {
                Logger.general.error("Failed to load initial leaderboard data: \(error)")
            }
        }
    }

    enum HKStoreError: Error {
        case noLeaderboard, noLeaderboardTitle, noLeaderboardImage
    }
}
