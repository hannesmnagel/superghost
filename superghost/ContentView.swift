//
//  ContentView.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import GameKit
import StoreKit
#if os(iOS)
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
    @CloudStorage("superghostTrialEnd") var superghostTrialEnd = (Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now)
    @State var isGameViewPresented = false

    @CloudStorage("winRate") private var winningRate = 0.0
    @CloudStorage("winStreak") private var winningStreak = 0
    @CloudStorage("wordToday") private var wordToday = "-----"
    @CloudStorage("winsToday") private var winsToday = 0
    @CloudStorage("score") private var score = 1000
    @CloudStorage("rank") private var rank = -1
    @AppStorage("showingSettings") private var settings = false
    @AppStorage("showingScoreChange") private var showingScoreChange = false
    @AppStorage("showingFiveWinsStreak") private var showingFiveWinsStreak = false
    
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        NavigationStack{
            if showingFiveWinsStreak{
                FiveWinsStreakView()
                    .transition(.scale)
            } else if showingScoreChange {
                ScoreChangeView()
                    .transition(.move(edge: .bottom))
            } else if isGameViewPresented{
                GameView(isPresented: $isGameViewPresented)
                    .transition(.move(edge: .bottom))
            } else if settings {
                SettingsView(){settings = false}
                    .transition(.move(edge: .bottom))
            } else {
                HomeView(isGameViewPresented: $isGameViewPresented)
                    .transition(.move(edge: .top))
            }
        }
        .animation(.smooth, value: isGameViewPresented)
        .preferredColorScheme(.dark)
        .fontDesign(.rounded)
        .background(Color.black, ignoresSafeAreaEdges: .all)
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
    nonisolated func promptUserForAction() async {
        let isSunday = Calendar.current.component(.weekday, from: .now) == 1

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
        if Int.random(in: 0...2) == 0,
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
#if !os(visionOS)
            await requestAction(.addWidget)
#endif
        } else if Int.random(in: 0...5) == 0 {
            Logger.userInteraction.info("Play in Messages feature tip")
            Logger.trackEvent("messages_tip")
            await showMessage("Did you know, you can play against friends in Messages?")
            await showMessage("Just tap the plus Button in Messages and then choose Superghost")
        }
    }

    func updateLocalWinningRate() {
        winningRate = GKStore.shared.games.winningRate
    }
    func updateLocalWinningStreak() {
        winningStreak = GKStore.shared.games.winningStreak
    }
    func updateLocalWinCount(_ count: Int) {
        winsToday = count
    }
    func updateLocalWordTo(_ string: String) {
        wordToday = string
    }

    nonisolated func refreshScore() async {
        if await GKStore.shared.games.isEmpty{
            try? await Task.sleep(for: .seconds(2))
        }

        await updateLocalWinningRate()
        await updateLocalWinningStreak()

        let gamesToday = await GKStore.shared.games.today
        await updateLocalWinCount(gamesToday.won.count)
        let gamesLostToday = gamesToday.lost

        let word = "SUPERGHOST"
        let lettersOfWord = word.prefix(gamesLostToday.count)
        let placeHolders = Array(repeating: "-", count: word.count).joined()
        let actualPlaceHolders = placeHolders.prefix(max(0, word.count-gamesLostToday.count))
        await updateLocalWordTo(lettersOfWord.appending(actualPlaceHolders))

#if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }
}

#Preview {
    ContentView()
        .modifier(PreviewModifier())
}
