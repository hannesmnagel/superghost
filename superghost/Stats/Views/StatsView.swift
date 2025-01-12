//
//  StatsView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI
import UserNotifications

struct StatsView: View {

    @CloudStorage("winRate") private var winningRate = 0.0
    @CloudStorage("winStreak") private var winningStreak = 0
    @CloudStorage("wordToday") private var wordToday = "-----"
    @CloudStorage("winsToday") private var winsToday = 0
    @CloudStorage("score") private var score = 1000
    @CloudStorage("rank") private var rank = -1
    @CloudStorage("superghostTrialEnd") var superghostTrialEnd = (Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now)

    @Binding var selection: GameStat?

    @State private var expandingList = false

    @ObservedObject private var gkStore = GKStore.shared

    @State private var maxGames = 6

    var body: some View {
#if os(macOS)
        VStack{}
            .toolbar {
                summary
            }

        Text("Recent Games")
            .font(AppearanceManager.leaderboardTitle)
            .frame(maxWidth: .infinity, alignment: .center)
            .opacity(gkStore.games.isEmpty ? 0 : 1)
#else
        Text("Recent Games")
            .font(AppearanceManager.leaderboardTitle)
            .frame(maxWidth: .infinity, alignment: .center)
            .opacity(gkStore.games.isEmpty ? 0 : 1)

        summary
#endif
        LazyVGrid(columns: [.init(.adaptive(minimum: 150, maximum: 200))]){
            ForEach(gkStore.games.prefix(max(6, maxGames))){game in
                Button{selection = game} label: {
                    MinimizedGameView(game: game)
                        .padding(5)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        HStack {
            if gkStore.games.count > maxGames {
                Button{
                    withAnimation(.smooth){maxGames += 10}
                } label: {
                    HStack{
                        Text("More")
                        Image(systemName: "plus.circle")
                    }
                    .contentShape(.rect)
                }
            }
            if maxGames > 6 {
                Button{
                    withAnimation(.smooth){maxGames -= 10}
                } label: {
                    HStack{
                        Text("Less")
                        Image(systemName: "minus.circle")
                    }
                    .contentShape(.rect)
                }
            }
        }
        .foregroundStyle(.accent)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .frame(maxWidth: .infinity)
    }
    @ViewBuilder var wordTodayView: some View {
        VStack{
            Text(wordToday)
                .font(AppearanceManager.statsValue)
            Text("Word Today")
                .font(AppearanceManager.statsLabel)
        }
        .frame(maxWidth: 300)
    }
    @ViewBuilder var winStreakView: some View {
        VStack{
            Text(winningStreak, format: .number)
                .font(AppearanceManager.statsValue)
            Text("Win Streak")
                .font(AppearanceManager.statsLabel)
        }
        .frame(maxWidth: 300)
    }
    @ViewBuilder var winRateView: some View {
        VStack{
            Text(winningRate, format: .percent.precision(.fractionLength(0)))
                .font(AppearanceManager.statsValue)
            Text("Win Rate")
                .font(AppearanceManager.statsLabel)
        }
        .frame(maxWidth: 300)
    }
    @ViewBuilder var winsTodayView: some View {
        VStack{
            Text(winsToday, format: .number)
                .font(AppearanceManager.statsValue)
            Text("Wins Today")
                .font(AppearanceManager.statsLabel)
        }
        .frame(maxWidth: 300)
    }
    @ViewBuilder var scoreView: some View {
        VStack{
            Text(score, format: .number)
                .font(AppearanceManager.statsValue)
            Text("XP")
                .font(AppearanceManager.statsLabel)
        }
        .frame(maxWidth: 300)
    }
    @ViewBuilder var rankView: some View {
        VStack{
            if rank >= 0{
                Text(rank, format: .number)
                    .font(AppearanceManager.statsValue)
            } else {
                Text("No")
                    .font(AppearanceManager.statsValue)
            }
            Text("Rank")
                .font(AppearanceManager.statsLabel)
        }
        .frame(maxWidth: 300)
    }

    @ViewBuilder @MainActor
    var summary: some View {
        Grid{
            GridRow{
                scoreView
                    .padding(4)
                    .background(.white.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 15))
                rankView
                    .padding(4)
                    .background(.white.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 15))
            }
            GridRow{
                winStreakView
                    .padding(4)
                    .background(.white.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 15))
                winRateView
                    .padding(4)
                    .background(.white.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 15))
            }

        }
        .multilineTextAlignment(.center)
        .padding()
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 20))
        .padding()
    }
}

#Preview {
    StatsView(selection: .constant(nil))
        .modifier(PreviewModifier())
}
