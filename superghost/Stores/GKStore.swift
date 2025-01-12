//
//  GKStore.swift
//  superghost
//
//  Created by Hannes Nagel on 9/18/24.
//

import SwiftUI
@preconcurrency import GameKit
import StoreKit
import UserNotifications

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
    @Published var achievedAchievements: [(GKAchievementDescription, GKAchievement)]?
    @Published var unachievedAchievements: [(GKAchievementDescription, GKAchievement?)]?
    //--------------------------------
    var executingRefreshScoreTask: Task<Void, Never>?
    @Published var games = [GameStat]() {
        didSet {
            executingRefreshScoreTask?.cancel()
            executingRefreshScoreTask = Task{
                await refreshScore()
            }
        }
    }
    //--------------------------------
    @CloudStorage("winRate") private var winningRate = 0.0
    @CloudStorage("winStreak") private var winningStreak = 0
    @CloudStorage("wordToday") private var wordToday = "-----"
    @CloudStorage("winsToday") private var winsToday = 0
    @CloudStorage("isPayingSuperghost") private var isPayingSuperghost = false
    @CloudStorage("showTrialEndsIn") private var showTrialEndsIn : Int? = nil
    
    
    
    private func checkIfLeaderboardIsUnlocked() async {
        guard !hasUnlockedLeaderboard else {return}
        self.hasUnlockedLeaderboard = (
            await withCheckedContinuation{ con in
                GKAchievement.loadAchievements { achievements, error in
                    con.resume(returning: achievements?.contains(where: {$0.identifier == Achievement.leaderboardUnlock.rawValue && $0.percentComplete == 100}) ?? false)
                }
            }
        )
    }
    func loadInitialData() async throws {

        actor ContinuationState {
            private var isResumed = false

            func tryResume<T: Sendable>(_ continuation: CheckedContinuation<T, Error>, with result: Result<T, Error>) throws(ContinuationStateError) {
                guard !isResumed else { throw .alreadyContinued }
                isResumed = true
                continuation.resume(with: result)
            }
            enum ContinuationStateError : Error {
                case alreadyContinued
            }
        }

        try await withCheckedThrowingContinuation { continuation in
            let continuationState = ContinuationState()

            let dataTask = Task {
                let start = Date()
                do {
                    let achievementsTask = Task {
                        try await loadAchievements()
                    }

                    let gamesTask = Task {
                        self.games = ((try? await GameStat.loadAll()) ?? []).sorted { $0.createdAt > $1.createdAt }
                    }

                    guard let leaderboard = try await GKLeaderboard.loadLeaderboards(IDs: ["global.score"]).first else {
                        throw GKStoreError.noLeaderboard
                    }
                    guard let leaderboardTitle = leaderboard.title else {
                        throw GKStoreError.noLeaderboardTitle
                    }

                    let leaderboardImage = try await withCheckedThrowingContinuation { innerContinuation in
                        leaderboard.loadImage { image, error in
                            if let image {
                                innerContinuation.resume(returning: Image(uiImage: image))
                            } else {
                                innerContinuation.resume(throwing: error!)
                            }
                        }
                    }

                    self.leaderboard = leaderboard
                    self.leaderboardTitle = leaderboardTitle
                    self.leaderboardImage = leaderboardImage
                    PlayerProfileModel.shared.player.name = GKLocalPlayer.local.alias

                    try await loadData()
                    try await achievementsTask.value
                    await gamesTask.value

                    do{
                        try await continuationState.tryResume(continuation, with: .success(()))
                    } catch {
                        Logger.trackEvent("game_store_loading_finally_finished", with: ["after":start.timeIntervalSinceNow.magnitude])
                    }
                } catch {
                    try await continuationState.tryResume(continuation, with: .failure(error))
                }
            }

            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(15))
                try await continuationState.tryResume(continuation, with: .failure(GKStoreError.loadingTimedOut))
                Logger.trackEvent("game_store_loading_timed_out")
            }
        }
    }
    func loadAchievements() async throws {
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
        self.achievedAchievements = achieved
        self.unachievedAchievements = unachieved
    }
    func loadData() async throws {
        await checkIfLeaderboardIsUnlocked()
        if leaderboardImage == nil {
            try await loadInitialData()
        }
        let _entries = try await leaderboard?.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...1))
        let entries = try await leaderboard?.loadEntries(for: .global, timeScope: .allTime, range: createRange(containing: _entries?.0?.rank ?? 1, maxAllowed: _entries?.2 ?? 10))


        self.localPlayerEntry = entries?.0
        self.leaderboardData = entries?.1
        self.rank = localPlayerEntry?.rank ?? -1
        PlayerProfileModel.shared.player.rank = self.rank

    }
    func createRange(containing value: Int, maxAllowed: Int, length: Int = 5) -> NSRange {
        // Calculate the ideal start to center `value` in the range
        let idealStart = value - length / 2

        // Ensure the range stays within valid bounds
        let start = max(1, min(idealStart, maxAllowed - length + 1))

        return NSRange(location: start, length: length)
    }

    private init(){}
    
    enum GKStoreError: Error {
        case noLeaderboard, noLeaderboardTitle, noLeaderboardImage, loadingTimedOut
    }
    
    func refreshScore() async {
        if games.isEmpty{
            try? await Task.sleep(for: .seconds(2))
        }

        if !games.isEmpty,
           await withCheckedContinuation({con in
               UNUserNotificationCenter.current().getNotificationSettings { settings in
                   con.resume(returning: settings.authorizationStatus == .notDetermined)
               }
           })
        {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization()
        }

        winningRate = games.winningRate

        winningStreak = games.winningStreak

        let gamesToday = games.today

        winsToday = gamesToday.won.count

        let gamesLostToday = gamesToday.lost

        let word = "SUPERGHOST"
        let lettersOfWord = word.prefix(gamesLostToday.count)
        let placeHolders = Array(repeating: "-", count: word.count).joined()
        let actualPlaceHolders = placeHolders.prefix(max(0, word.count-gamesLostToday.count))

        wordToday = lettersOfWord.appending(actualPlaceHolders)

    }
    
    func fetchSubscription() async throws {
        let hasSubscribed = await !StoreManager.shared.purchasedProductIDs.isEmpty
        self.isPayingSuperghost = hasSubscribed
    }
}
