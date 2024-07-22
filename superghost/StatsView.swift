//
//  StatsView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

struct StatsView: View {
    @Query(sort: [SortDescriptor(\GameStat.createdAt, order: .reverse)]) var games : [GameStat]

    @AppStorage("winRate", store: UserDefaults(suiteName: "group.com.nagel.superghost") ?? .standard) private var winningRate = 0.0
    @AppStorage("winStreak", store: UserDefaults(suiteName: "group.com.nagel.superghost") ?? .standard) private var winningStreak = 0
    @AppStorage("wordToday", store: UserDefaults(suiteName: "group.com.nagel.superghost") ?? .standard) private var wordToday = "-----"
    @AppStorage("winsToday", store: UserDefaults(suiteName: "group.com.nagel.superghost") ?? .standard) private var winsToday = 0

    @Binding var selection: GameStat?
    let isSuperghost : Bool

    @State private var expandingList = false

    var body: some View {
#if os(macOS)
        VStack{}
            .toolbar {
                summary
            }
#else
        summary
#endif
        ForEach(games.prefix(expandingList ? .max : 5)){game in
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
        if games.count > 5 {
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
            .frame(width: 100)
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
        .task(id: games.debugDescription) {
            winningRate = games.winningRate
            winningStreak = games.winningStreak
            let gamesToday = games.today
            winsToday = gamesToday.won.count
            let gamesLostToday = gamesToday.lost

            let word = isSuperghost ? "SUPERGHOST" : "GHOST"
            let lettersOfWord = word.prefix(gamesLostToday.count)
            let placeHolders = Array(repeating: "-", count: word.count).joined()
            let actualPlaceHolders = placeHolders.prefix(max(0, word.count-gamesLostToday.count))
            wordToday = lettersOfWord.appending(actualPlaceHolders)
#if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
#endif
        }
        .multilineTextAlignment(.center)
        .listRowBackground(
            HStack{
                GeometryReader{geo in
#if os(watchOS)
                    UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10)
                        .fill(.red.opacity(0.5 + 0.1 * Double(games.today.lost.count)))
                        .frame(width:
                                geo.frame(in: .named("rowbackground")).width * CGFloat(games.today.lost.count) / CGFloat(wordToday.count)
                        )
#else
                    Rectangle()
                        .fill(.red.opacity(0.5 + 0.1 * Double(games.today.lost.count)))
                        .frame(width:
                                geo.frame(in: .named("rowbackground")).width * CGFloat(games.today.lost.count) / CGFloat(wordToday.count)
                        )
#endif
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
#if os(watchOS)
                        UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10)
                            .fill(.red.opacity(0.5 + 0.1 * Double(games.today.lost.count)))
                            .frame(width:
                                    geo.frame(in: .named("rowbackground")).width * CGFloat(games.today.lost.count) / CGFloat(wordToday.count)
                            )
#else
                        Rectangle()
                            .fill(.red.opacity(0.5 + 0.1 * Double(games.today.lost.count)))
                            .frame(width:
                                    geo.frame(in: .named("rowbackground")).width * CGFloat(games.today.lost.count) / CGFloat(wordToday.count)
                            )
#endif
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
