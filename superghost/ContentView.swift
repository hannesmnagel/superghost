//
//  ContentView.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI

struct ContentView: View {

    @State var isGameViewPresented = false

    @StateObject var viewModel = GameViewModel()

    let date = Date()
    @Namespace var namespace

    @State var joinGame = false

    @State private var gameStatSelection: GameStat?

    @Query(sort: [SortDescriptor(\GameStat.createdAt, order: .reverse)]) var games : [GameStat]

    var body: some View {
        Group{
            if isGameViewPresented{
                GameView(viewModel: viewModel, isPresented: $isGameViewPresented, namespace: namespace)
            } else {
                GeometryReader{geo in
                    VStack {
                        List{
                            Section{
                                StatsView(selection: $gameStatSelection)
                            } header: {
                                VStack{
                                    waitingGhost

                                    AsyncButton {
                                        try await viewModel.getTheGame()
                                        isGameViewPresented = true
                                    } label: {
                                        Text("Start")
                                    }
                                    .disabled(games.today.lost.count == 5)
                                    #if !os(watchOS)
                                    .keyboardShortcut(.defaultAction)
                                    #endif

                                    AsyncButton {
                                        try await viewModel.hostGame()
                                        isGameViewPresented = true
                                    } label: {
                                        Text("Host a Game")
                                    }
                                }
                                .font(ApearanceManager.title)
                                .buttonStyle(.bordered)
                                .tint(.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: geo.size.height*0.7, alignment: .bottom)
                                .padding(.bottom, 30)
                            }
                        }
                        #if os(macOS)
                        .listStyle(.sidebar)
                        #endif
                        .scrollContentBackground(.hidden)
                    }
                    .onOpenURL { url in
                        Task{
                            guard url.scheme == "superghost" else {
                                return
                            }
                            let gameId = url.lastPathComponent

                            try await viewModel.joinGame(with: gameId)
                            gameStatSelection = nil
                            isGameViewPresented = true
                        }
                    }
                }
            }
        }
        .animation(.smooth, value: isGameViewPresented)
        .sheet(item: $gameStatSelection) { gameStat in
            VStack{
                WordDefinitionView(word: gameStat.word, game: gameStat)
                    .padding(.top)
                #if !os(watchOS)
                    .overlay(alignment: .topTrailing){
                        Button{gameStatSelection = nil} label: {
                            Image(systemName: "xmark")
                        }
                        .padding(.top.union(.trailing))
                    }
                #endif
            }
            .background((gameStat.won ? Color.green.brightness(0.5).opacity(0.1) : Color.red.brightness(0.5).opacity(0.1)).ignoresSafeArea())
            #if os(macOS)
            .frame(minWidth: 500, minHeight: 500)
            #endif
        }
        .preferredColorScheme(.dark)
    }

    @MainActor @ViewBuilder
    var waitingGhost: some View {
        TimelineView(.animation){context in

            let timeInterval = context.date.timeIntervalSince(date)
            let sineValue = sin(timeInterval * .pi / 2) // Adjust the frequency of the sine wave
            let cosineValue = cos(timeInterval * .pi / 2)

            let offsetX = CGFloat(sineValue)*30
            let rotationAngle = atan2(cosineValue, 1.0) * 20 / .pi

            Image(.ghost)
                .resizable()
                .scaledToFit()
                .visualEffect { content, geo in
                    content
                        .offset(x: offsetX)
                        .rotationEffect(.degrees(rotationAngle))
                        .offset(y: -geo.frame(in: .scrollView).minY*0.5 + geo.size.height/2)
                        .scaleEffect(1+geo.frame(in: .scrollView).minY/1000)
                }
                .matchedGeometryEffect(id: "ghost", in: namespace)
                .padding(.vertical, 60)
                .padding(.bottom, 60)
        }
    }
}

import SwiftData

struct StatsView: View {
    @Query(sort: [SortDescriptor(\GameStat.createdAt, order: .reverse)]) var games : [GameStat]

    @Binding var selection: GameStat?

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
        let wordToday = "GHOST".prefix(gamesLostToday.count).appending("-----".prefix(5-gamesLostToday.count))
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

extension Array where Element == GameStat {
    var won: Self {filter{$0.won}}
    var lost: Self {filter{!$0.won}}
    var winningRate: Double {
        isEmpty ? 0.0 : Double(won.count)/Double(count)
    }
    var winningStreak : Int { sorted{$0.createdAt > $1.createdAt}.firstIndex(where: {!$0.won}) ?? count}
    var today: Self {filter{Calendar.current.isDateInToday($0.createdAt)}}
    var withInvitation: Self {filter{$0.withInvitation}}

}

#Preview {
    ContentView()
        .modelContainer(for: GameStat.self, inMemory: false)
}

struct AsyncButton<Label:View>: View {

    let action: () async throws -> Void
    @ViewBuilder let label: Label

    @State private var state = AsyncButtonState.main

    enum AsyncButtonState{
        case main, inProgress, success, failed
    }

    var body: some View {
        Button{
            Task{
                do{
                    state = .inProgress
                    try await action()
                    state = .success
                    try? await Task.sleep(for: .seconds(1))
                    state = .main
                } catch {
                    print(error)
                    state = .failed
                    try? await Task.sleep(for: .seconds(1))
                    state = .main
                }
            }
        } label: {
            switch state {
            case .main:
                label
            case .inProgress:
                ProgressView()
            case .success:
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark")
                    .foregroundStyle(.red)
            }
        }
        .disabled(state == .inProgress)
    }
}
