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
    @CloudStorage("superghostTrialEnd") var superghostTrialEnd = (Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now)
    @CloudStorage("isSuperghost") private var isSuperghost = false
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
        //starting achievements task because it doesn't need anything else
        let achievementsTask = Task {
            try await loadAchievements()
        }
        
        let gamesTask = Task{
            self.games = ((try? await GameStat.loadAll()) ?? []).sorted{$0.createdAt > $1.createdAt}
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

        self.leaderboard = leaderboard
        self.leaderboardTitle = leaderboardTitle
        self.leaderboardImage = leaderboardImage
        PlayerProfileModel.shared.player.name = GKLocalPlayer.local.alias

        try await loadData()
        try await achievementsTask.value
        await gamesTask.value
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
        let entries = try await leaderboard?.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...5))


        self.localPlayerEntry = entries?.0
        self.leaderboardData = entries?.1
        self.rank = localPlayerEntry?.rank ?? -1
        PlayerProfileModel.shared.player.rank = self.rank

    }
    
    private init(){}
    
    enum HKStoreError: Error {
        case noLeaderboard, noLeaderboardTitle, noLeaderboardImage
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

        if Int(winningStreak/5) < Int(games.winningStreak/5) && (winningStreak + 1) == games.winningStreak {
            superghostTrialEnd = Calendar.current.date(byAdding: .day, value: 1, to: max(Date(), superghostTrialEnd)) ?? superghostTrialEnd
            UserDefaults.standard.set(true, forKey: "showingFiveWinsStreak")
            Task{
                try? await fetchSubscription()
            }
        }
        winningStreak = games.winningStreak

        let gamesToday = games.today

        winsToday = gamesToday.won.count

        let gamesLostToday = gamesToday.lost

        let word = isSuperghost ? "SUPERGHOST" : "GHOST"
        let lettersOfWord = word.prefix(gamesLostToday.count)
        let placeHolders = Array(repeating: "-", count: word.count).joined()
        let actualPlaceHolders = placeHolders.prefix(max(0, word.count-gamesLostToday.count))

        wordToday = lettersOfWord.appending(actualPlaceHolders)

    }
    
    func fetchSubscription() async throws {
        let hasSubscribed = await !StoreManager.shared.purchasedProductIDs.isEmpty


        self.isPayingSuperghost = hasSubscribed
        let timeSinceTrialEnd = Date().timeIntervalSince(superghostTrialEnd)
        let daysSinceTrialEnd = timeSinceTrialEnd / (Calendar.current.dateInterval(of: .day, for: .now)?.duration ?? 1)
        let wasSuperghost = isSuperghost

        isSuperghost = hasSubscribed || timeSinceTrialEnd < 0

        if isSuperghost,
           UserDefaults.standard.bool(forKey: "showingPaywall") {
            UserDefaults.standard.set(false, forKey: "showingPaywall")
        }



#if os(iOS)
        if !isSuperghost,
           AppearanceManager.shared.appIcon != .standard{
            Task{
                try? await UIApplication.shared.setAlternateIconName("AppIcon.standard")
                AppearanceManager.shared.appIcon = .standard
            }
        }
#endif


        //is in trial:
        if !hasSubscribed && timeSinceTrialEnd < 0 {
            showTrialEndsIn = Int(-daysSinceTrialEnd+0.5)
        } else {
            showTrialEndsIn = nil
        }
        if isSuperghost != wasSuperghost {
            await refreshScore()
        }
    }
}
