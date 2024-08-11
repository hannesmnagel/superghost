//
//  ContentView.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import RevenueCat
import GameKit
#if canImport(WidgetKit)
import WidgetKit
#endif
import UserNotifications

extension Date: Swift.RawRepresentable{
    public var rawValue: String {ISO8601Format()}
    public init?(rawValue: String) {
        if let decoded = ISO8601DateFormatter().date(from: rawValue){
            self = decoded
        } else {
            return nil
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @CloudStorage("isFirstUse") var isFirstUse = true
    @CloudStorage("lastViewOfPaywall") var lastPaywallView = Date.distantPast
    @CloudStorage("superghostTrialEnd") var superghostTrialEnd = (Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now)
    @State var isGameViewPresented = false
    @State private var showTrialEndsIn : Int?
    @CloudStorage("isSuperghost") private var isSuperghost = false

    @CloudStorage("winRate") private var winningRate = 0.0
    @CloudStorage("winStreak") private var winningStreak = 0
    @CloudStorage("wordToday") private var wordToday = "-----"
    @CloudStorage("winsToday") private var winsToday = 0
    @CloudStorage("score") private var score = 0
    @CloudStorage("rank") private var rank = -1
    @CloudStorage("notificationsAllowed") var notificationsAllowed = false

    var body: some View {
        Group{
            if isFirstUse{
                FirstUseView()
                    .transition(.opacity)
            } else if isGameViewPresented{
                GameView(isPresented: $isGameViewPresented, isSuperghost: isSuperghost)
            } else {
                HomeView(isSuperghost: isSuperghost, showTrialEndsIn: showTrialEndsIn, isGameViewPresented: $isGameViewPresented)
            }
        }
        .animation(.smooth, value: isFirstUse)
        .animation(.smooth, value: isGameViewPresented)
        .preferredColorScheme(.dark)
        .task(id: superghostTrialEnd) {
            do{
                try await fetchSubscription()
            } catch {
                print(error)
            }
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            Task{try? await fetchSubscription()}
        } content: {
            PaywallView()
#if os(macOS)
                .frame(minWidth: 500, minHeight: 500)
#endif
        }
        .fontDesign(.rounded)
        .background(Color.black, ignoresSafeAreaEdges: .all)

        .task(id: viewModel.games.debugDescription.appending(isSuperghost.description)) {
            await refreshScore()
            await requestNotification()
        }
    }

    func fetchSubscription() async throws {
        let info = try await Purchases.shared.restorePurchases()
        let subscriptions = info.activeSubscriptions
        let timeSinceTrialEnd = Date().timeIntervalSince(superghostTrialEnd)
        let daysSinceTrialEnd = timeSinceTrialEnd / (Calendar.current.dateInterval(of: .day, for: .now)?.duration ?? 1)
        print(daysSinceTrialEnd)
        isSuperghost = (info.entitlements["superghost"]?.isActive ?? false) || timeSinceTrialEnd < 0

#if os(iOS)
        if !isSuperghost && AppearanceManager.shared.appIcon != .standard{
            try? await UIApplication.shared.setAlternateIconName("AppIcon.standard")
        }
#endif

        let showedPaywallToday = Calendar.current.isDateInToday(lastPaywallView)

        //is in trial:
        if !(info.entitlements["superghost"]?.isActive ?? false) && timeSinceTrialEnd < 0 {
            showTrialEndsIn = Int(-daysSinceTrialEnd+0.5)
        } else {
            showTrialEndsIn = nil
        }
        //is not superghost, every 4 days:
        if !showedPaywallToday && !isSuperghost && (Int(daysSinceTrialEnd) % 4 == 0 || daysSinceTrialEnd < 3) {
            viewModel.showPaywall = true
            lastPaywallView = Date()
        } else if !showedPaywallToday && Int.random(in: 0...3) == 0{
            showMessage("Add some friends and challenge them!")
            lastPaywallView = Date()
        }
    }

    nonisolated func refreshScore() async {
        await MainActor.run{
            winningRate = viewModel.games.winningRate
            winningStreak = viewModel.games.winningStreak
        }
        let gamesToday = await viewModel.games.today
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

        let recentGames = await viewModel.games.recent
        let recentWinningRate = recentGames.winningRate
        let recentWins = recentGames.won.count
        let recentLosses = recentGames.won.count
        let totalWins = await viewModel.games.won.count

        let baseScore = 1000
        let totalWinRateFactor = await Int(100 * winningRate)
        let recentWinRateFactor = Int(200 * recentWinningRate)
        let recentWinCountFactor = 40 * recentWins
        let totalWinCountFactor = 10 * totalWins
        let recentLostCountFactor = 10 * recentLosses

        let newScore = baseScore + totalWinRateFactor + recentWinRateFactor + recentWinCountFactor + totalWinCountFactor - recentLostCountFactor

        Task{
            try? await GameStat.submitScore(newScore)
            await MainActor.run{
                score = newScore
            }
        }
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }

    nonisolated func requestNotification() async {
        if await !viewModel.games.isEmpty {
            do{
                if await notificationsAllowed {
                    guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) else {
                        await MainActor.run{
                            notificationsAllowed = false
                        }
                        return
                    }
                }
            } catch {
                await MainActor.run{
                    notificationsAllowed = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modifier(PreviewModifier())
}
