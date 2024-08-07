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
    @CloudStorage("score") private var score = 0
    @CloudStorage("rank") private var rank = -1
    @CloudStorage("superghostTrialEnd") var superghostTrialEnd = (Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now)

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
            Button{
                withAnimation(.smooth){expandingList.toggle()}
            } label: {
                HStack{
                    Text(expandingList ? "Less" : "More")
                    Image(systemName: "ellipsis")
                }
                .contentShape(.rect)
            }
                .buttonStyle(.bordered)
                .buttonBorderShape(.bcCapsule)
                .frame(maxWidth: .infinity)
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
            Divider()
            VStack{
                Text(score, format: .number)
                    .font(AppearanceManager.statsValue)
                Text("Score")
                    .font(AppearanceManager.statsLabel)
            }
            .frame(maxWidth: .infinity)
            Divider()
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
            .frame(maxWidth: .infinity)
        }
        .onChange(of: winningStreak) { newValue, oldValue in
            if Int(oldValue/5) < Int(newValue/5) && (oldValue + 1) == newValue {
                superghostTrialEnd = Calendar.current.date(byAdding: .day, value: 1, to: max(Date(), superghostTrialEnd)) ?? superghostTrialEnd
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
    }
}

#Preview {
    StatsView(selection: .constant(nil), isSuperghost: true)
        .modifier(PreviewModifier())
}
