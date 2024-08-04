//
//  StatsView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif
import UserNotifications

struct StatsView: View {

    @CloudStorage("winRate") private var winningRate = 0.0
    @CloudStorage("winStreak") private var winningStreak = 0
    @CloudStorage("wordToday") private var wordToday = "-----"
    @CloudStorage("winsToday") private var winsToday = 0
    @CloudStorage("score") private var score = 0
    @CloudStorage("superghostTrialEnd") var superghostTrialEnd = (Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now)
    @CloudStorage("notificationsAllowed") var notificationsAllowed = false

    @Binding var selection: GameStat?
    let isSuperghost : Bool

    @State private var expandingList = false

    @EnvironmentObject var viewModel: GameViewModel

    var body: some View {
#if os(macOS)
        VStack{}
            .toolbar {
                summary
            }
#else
        summary
#endif
        ForEach(viewModel.games.prefix(expandingList ? .max : 5)){game in
            Button{selection = game} label: {
                HStack{
                    Text(game.word)
                    Spacer()
                    Image(systemName: game.won ? "crown.fill" : "xmark")
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .listRowBackground(game.won ? Color.green.brightness(0.5).opacity(0.1) : Color.red.brightness(0.5).opacity(0.1))
        }
        if viewModel.games.count > 5 {
            Button(expandingList ? "Less" : "More"){withAnimation(.smooth){expandingList.toggle()}}
        }
    }
    @ViewBuilder @MainActor
    var summary: some View {
        HStack(alignment: .top){
#if os(macOS)
            VStack{
                Text(wordToday)
                    .font(AppearanceManager.statsValue)
                Text("Word Today")
                    .font(AppearanceManager.statsLabel)
            }
            .frame(width: 200)
            Divider()
#endif
            VStack{
                Text(winningStreak, format: .number)
                    .font(AppearanceManager.statsValue)
                Text("Win Streak")
                    .font(AppearanceManager.statsLabel)
            }
            .frame(maxWidth: .infinity)
            Divider()
            VStack{
                Text(winningRate, format: .percent.precision(.fractionLength(0)))
                    .font(AppearanceManager.statsValue)
                Text("Win Rate")
                    .font(AppearanceManager.statsLabel)
            }
            .frame(maxWidth: .infinity)
            Divider()
            VStack{
                Text(winsToday, format: .number)
                    .font(AppearanceManager.statsValue)
                Text("Wins Today")
                    .font(AppearanceManager.statsLabel)
            }
            .frame(maxWidth: .infinity)
        }
        .onChange(of: winningStreak) { oldValue, newValue in
            if Int(oldValue/5) < Int(newValue/5) {
                superghostTrialEnd = Calendar.current.date(byAdding: .day, value: 1, to: max(Date(), superghostTrialEnd)) ?? superghostTrialEnd
            }
        }
        .task(id: viewModel.games.debugDescription.appending(isSuperghost.description)) {
            winningRate = viewModel.games.winningRate
            winningStreak = viewModel.games.winningStreak
            let gamesToday = viewModel.games.today
            winsToday = gamesToday.won.count
            let gamesLostToday = gamesToday.lost

            let word = isSuperghost ? "SUPERGHOST" : "GHOST"
            let lettersOfWord = word.prefix(gamesLostToday.count)
            let placeHolders = Array(repeating: "-", count: word.count).joined()
            let actualPlaceHolders = placeHolders.prefix(max(0, word.count-gamesLostToday.count))
            wordToday = lettersOfWord.appending(actualPlaceHolders)

            let recentGames = viewModel.games.recent
            let recentWinningRate = recentGames.winningRate
            let recentWins = recentGames.won.count
            let totalWins = viewModel.games.won.count

            let baseScore = 1000
            let totalWinRateFactor = Int(500 * winningRate)
            let recentWinRateFactor = Int(500 * recentWinningRate)
            let recentWinCountFactor = 10 * recentWins
            let totalWinCountFactor = 1 * totalWins

            score = baseScore + totalWinRateFactor + recentWinRateFactor + recentWinCountFactor + totalWinCountFactor

            Task{
                try? await GameStat.submitScore(score)
            }
#if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
#endif

            if !viewModel.games.isEmpty {
                do{
                    if notificationsAllowed {
                        guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) else {notificationsAllowed = false; return}
                    }
                } catch {
                    notificationsAllowed = false
                }
            }
        }
        .multilineTextAlignment(.center)
        .listRowBackground(
            HStack{
                GeometryReader{geo in
                    Rectangle()
                        .fill(.red.opacity(0.5 + 0.1 * Double(viewModel.games.today.lost.count)))
                        .frame(width:
                                geo.frame(in: .named("rowbackground")).width * CGFloat(viewModel.games.today.lost.count) / CGFloat(wordToday.count)
                        )
                }
            }
                .coordinateSpace(name: "rowbackground")
                .ignoresSafeArea()
                .background(Color.green.opacity(0.5))
        )
        .clipped()

#if !os(macOS)
        LabeledContent("Today", value: wordToday)
            .listRowBackground(
                HStack{
                    GeometryReader{geo in
                        Rectangle()
                            .fill(.red.opacity(0.5 + 0.1 * Double(viewModel.games.today.lost.count)))
                            .frame(width:
                                    geo.frame(in: .named("rowbackground")).width * CGFloat(viewModel.games.today.lost.count) / CGFloat(wordToday.count)
                            )
                    }
                }
                    .coordinateSpace(name: "rowbackground")
                    .ignoresSafeArea()
                    .background(Color.green.opacity(0.5))
            )
#endif
    }
}

#Preview {
    StatsView(selection: .constant(nil), isSuperghost: true)
        .modifier(PreviewModifier())
}
