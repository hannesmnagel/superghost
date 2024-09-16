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
    @CloudStorage("superghostTrialEnd") var superghostTrialEnd = (Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now)
    @State var isGameViewPresented = false
    @State private var showTrialEndsIn : Int?
    @CloudStorage("isSuperghost") private var isSuperghost = false

    @CloudStorage("winRate") private var winningRate = 0.0
    @CloudStorage("winStreak") private var winningStreak = 0
    @CloudStorage("wordToday") private var wordToday = "-----"
    @CloudStorage("winsToday") private var winsToday = 0
    @CloudStorage("score") private var score = 1000
    @CloudStorage("rank") private var rank = -1
    
    @Environment(\.scenePhase) var scenePhase

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
        .sheet(isPresented: $viewModel.showPaywall) {
            Logger.userInteraction.info("Dismissed Paywall")
            Task{
                do{
                    try await fetchSubscription()
                } catch {
                    Logger.subscription.error("Error fetching subscription: \(error, privacy: .public)")
                }
            }
        } content: {
            PaywallView()
#if os(macOS)
                .frame(minWidth: 500, minHeight: 500)
#endif
        }
        .fontDesign(.rounded)
        .background(Color.black, ignoresSafeAreaEdges: .all)

        .task(id: viewModel.games) {
            await refreshScore()
            if !viewModel.games.isEmpty, await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined{
                _ = try? await UNUserNotificationCenter.current().requestAuthorization()
            }
        }
        .task(id: isSuperghost) {
            do{
                try await fetchSubscription()
            } catch {
                Logger.subscription.error("Error fetching subscription: \(error, privacy: .public)")
            }
        }
        .task{
            if NSUbiquitousKeyValueStore.default.double(forKey: Achievement.widgetAdd.rawValue) == 100.0{
                Task.detached{
                    try await reportAchievement(.widgetAdd, percent: 100)
                }
            }
        }
        .onAppear{
            Task{
                await promptUserForAction()
            }
        }
    }

    nonisolated func fetchSubscription() async throws {
        let info = try await Purchases.shared.customerInfo()
        let timeSinceTrialEnd = await Date().timeIntervalSince(superghostTrialEnd)
        let daysSinceTrialEnd = timeSinceTrialEnd / (Calendar.current.dateInterval(of: .day, for: .now)?.duration ?? 1)
        await MainActor.run{
            isSuperghost = (info.entitlements["superghost"]?.isActive ?? false) || timeSinceTrialEnd < 0
        }

#if os(iOS)
        if await !isSuperghost && AppearanceManager.shared.appIcon != .standard{
            try? await UIApplication.shared.setAlternateIconName("AppIcon.standard")
        }
#endif


        //is in trial:
        if !(info.entitlements["superghost"]?.isActive ?? false) && timeSinceTrialEnd < 0 {
            await MainActor.run{
                showTrialEndsIn = Int(-daysSinceTrialEnd+0.5)
            }
        } else {
            await MainActor.run{
                showTrialEndsIn = nil
            }
        }
    }
    nonisolated func promptUserForAction() async {
        let timeSinceTrialEnd = await Date().timeIntervalSince(superghostTrialEnd)
        let daysSinceTrialEnd = timeSinceTrialEnd / (Calendar.current.dateInterval(of: .day, for: .now)?.duration ?? 1)

        let isSunday = Calendar.current.component(.weekday, from: .now) == 1

        while await isFirstUse {
            try? await Task.sleep(for: .seconds(2))
        }
        let isDoubleXP : Bool
        if let data = NSUbiquitousKeyValueStore.default.data(forKey: "doubleXPuntil"),
           let date = try? JSONDecoder().decode(Date.self, from: data),
           date > .now{
            isDoubleXP = true
        } else {isDoubleXP = false}


        if isSunday && isDoubleXP {
            await requestAction(.show4xXP)
        } else if isSunday {
            await requestAction(.showSunday)
        } else if isDoubleXP {
            await requestAction(.showDoubleXP)
        } else
        //is not superghost, every 4 days:
        if await !isSuperghost,
           (Int(daysSinceTrialEnd) % 4 == 0 || daysSinceTrialEnd < 3)
        {
            await MainActor.run{
                viewModel.showPaywall = true
            }
            Logger.userInteraction.info("presenting paywall")
        } else if Int.random(in: 0...2) == 0,
                  await UNUserNotificationCenter.current().notificationSettings().authorizationStatus != .authorized{
            await requestAction(.enableNotifications)
        }
        else if Int.random(in: 0...3) == 0,
                let friends = try? await GKLocalPlayer.local.loadFriends() {
            if friends.isEmpty {
                await requestAction(.addFriends)
            } else {
                Task.detached{
                    try? await reportAchievement(.friendAdd, percent: 100)
                }
            }
        } else if Int.random(in: 0...3) == 0 && NSUbiquitousKeyValueStore.default.double(forKey: Achievement.widgetAdd.rawValue) != 100 {
            await requestAction(.addWidget)
        } else if Int.random(in: 0...5) == 0 {
            Logger.userInteraction.info("Play in Messages feature tip")
            Logger.remoteLog("Play in Messages feature tip")
            await showMessage("Did you know, you can play against friends in Messages?")
            await showMessage("Just tap the plus Button in Messages and then choose Superghost")
        }
    }

    nonisolated func refreshScore() async {
        if await viewModel.games.isEmpty{
            try? await Task.sleep(for: .seconds(2))
        }

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

#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }
}

#Preview {
    ContentView()
        .modifier(PreviewModifier())
}
