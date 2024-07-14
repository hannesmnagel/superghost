//
//  StatsView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: [SortDescriptor(\GameStat.createdAt, order: .reverse)]) var games : [GameStat]

    @Binding var selection: GameStat?
    let isSuperghost : Bool

    var body: some View {
#if os(macOS)
        VStack{}
            .toolbar {
                summary
            }
#else
        summary
#endif
        ForEach(games){game in
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
    }
    @ViewBuilder @MainActor
    var summary: some View {
        let winningRate = games.winningRate
        let winningStreak = games.winningStreak
        let gamesToday = games.today
        let wonToday = gamesToday.won.count
        let gamesLostToday = gamesToday.lost
        let word = isSuperghost ? "SUPERGHOST" : "GHOST"
        let lettersOfWord = word.prefix(gamesLostToday.count)
        let placeHolders = Array(repeating: "-", count: word.count).joined()
        let actualPlaceHolders = placeHolders.prefix(word.count-gamesLostToday.count)
        let wordToday = lettersOfWord.appending(actualPlaceHolders)
        HStack(alignment: .top){
#if os(macOS)
            VStack{
                Text(wordToday)
                Text("word today")
                    .font(ApearanceManager.footnote)
            }
            .frame(maxWidth: .infinity)
            Divider()
#endif
            VStack{
                Text(winningStreak, format: .number)
                Text("Winning Streak")
                    .font(ApearanceManager.footnote)
            }
            .frame(maxWidth: .infinity)
            Divider()
            VStack{
                Text(winningRate, format: .percent.precision(.fractionLength(0)))
                Text("Winning Rate")
                    .font(ApearanceManager.footnote)
            }
            .frame(maxWidth: .infinity)
            Divider()
            VStack{
                Text(wonToday, format: .number)
                Text("Wins Today")
                    .font(ApearanceManager.footnote)
            }
            .frame(maxWidth: .infinity)
        }
#if os(watchOS)
        .font(ApearanceManager.headline)
#else
        .font(ApearanceManager.title)
#endif
        .multilineTextAlignment(.center)
        .listRowBackground(
            HStack{
                GeometryReader{geo in
#if os(watchOS)
                    UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10)
                        .fill(.red.opacity(0.5 + 0.1 * Double(gamesLostToday.count)))
                        .frame(width:
                                geo.frame(in: .named("rowbackground")).width * CGFloat(gamesLostToday.count) / 5.0
                        )
#else
                    Rectangle()
                        .fill(.red.opacity(0.5 + 0.1 * Double(gamesLostToday.count)))
                        .frame(width:
                                geo.frame(in: .named("rowbackground")).width * CGFloat(gamesLostToday.count) / 5.0
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
                            .fill(.red.opacity(0.5 + 0.1 * Double(gamesLostToday.count)))
                            .frame(width:
                                    geo.frame(in: .named("rowbackground")).width * CGFloat(gamesLostToday.count) / 5.0
                            )
#else
                        Rectangle()
                            .fill(.red.opacity(0.5 + 0.1 * Double(gamesLostToday.count)))
                            .frame(width:
                                    geo.frame(in: .named("rowbackground")).width * CGFloat(gamesLostToday.count) / 5.0
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
