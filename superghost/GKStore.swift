//
//  GKStore.swift
//  superghost
//
//  Created by Hannes Nagel on 9/18/24.
//

import SwiftUI
import GameKit
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
        self.hasUnlockedLeaderboard = (try? await GKAchievement.loadAchievements().first(where: { $0.identifier == Achievement.leaderboardUnlock.rawValue })?.percentComplete) == 100
    }
    nonisolated func loadInitialData() async throws {
        //starting achievements task because it doesn't need anything else
        let achievementsTask = Task {
            try await loadAchievements()
        }
        
        let gamesTask = Task{
            let games = ((try? await GameStat.loadAll()) ?? []).sorted{$0.createdAt > $1.createdAt}
            await MainActor.run {
                self.games = games
            }
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
        await gamesTask.value
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
    
    private init(){}
    
    enum HKStoreError: Error {
        case noLeaderboard, noLeaderboardTitle, noLeaderboardImage
    }
    
    nonisolated func refreshScore() async {
        if await games.isEmpty{
            try? await Task.sleep(for: .seconds(2))
        }
        
        if await !games.isEmpty, await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined{
            _ = try? await UNUserNotificationCenter.current().requestAuthorization()
        }
        await MainActor.run{
            winningRate = games.winningRate
            
            if Int(winningStreak/5) < Int(games.winningStreak/5) && (winningStreak + 1) == games.winningStreak {
                superghostTrialEnd = Calendar.current.date(byAdding: .day, value: 1, to: max(Date(), superghostTrialEnd)) ?? superghostTrialEnd
                UserDefaults.standard.set(true, forKey: "showingFiveWinsStreak")
                Task{
                    try? await fetchSubscription()
                }
            }
            winningStreak = games.winningStreak
        }
        let gamesToday = await games.today
        await MainActor.run{
            winsToday = gamesToday.won.count
        }
        let gamesLostToday = gamesToday.lost
        
        let word = await isSuperghost ? "SUPERGHOST" : "GHOST"
        let lettersOfWord = word.prefix(gamesLostToday.count)
        let placeHolders = Array(repeating: "-", count: word.count).joined()
        let actualPlaceHolders = placeHolders.prefix(max(0, word.count-gamesLostToday.count))
        await MainActor.run{
            wordToday = lettersOfWord.appending(actualPlaceHolders)
        }
    }
    
    nonisolated func fetchSubscription() async throws {
        let hasSubscribed = await {
            for await entitlement in Transaction.currentEntitlements {
                if let _ = try? entitlement.payloadValue{
                    return true
                }
            }
            return false
        }()
        await MainActor.run {
            self.isPayingSuperghost = hasSubscribed
        }
        let timeSinceTrialEnd = await Date().timeIntervalSince(superghostTrialEnd)
        let daysSinceTrialEnd = timeSinceTrialEnd / (Calendar.current.dateInterval(of: .day, for: .now)?.duration ?? 1)
        let wasSuperghost = await isSuperghost
        await MainActor.run{
            isSuperghost = hasSubscribed || timeSinceTrialEnd < 0
        }

#if os(iOS)
        if await !isSuperghost && AppearanceManager.shared.appIcon != .standard{
            try? await UIApplication.shared.setAlternateIconName("AppIcon.standard")
            AppearanceManager.shared.appIcon = .standard
        }
#endif


        //is in trial:
        if !hasSubscribed && timeSinceTrialEnd < 0 {
            await MainActor.run{
                showTrialEndsIn = Int(-daysSinceTrialEnd+0.5)
            }
        } else {
            await MainActor.run{
                showTrialEndsIn = nil
            }
        }
        if await isSuperghost != wasSuperghost {
            await refreshScore()
        }
    }
}
