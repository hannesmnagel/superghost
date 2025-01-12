//
//  HomeView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI

struct HomeView: View {
    @State private var gameStatSelection: GameStat?
    @ObservedObject var gkStore = GKStore.shared
    @Binding var isGameViewPresented: Bool
    @CloudStorage("wordToday") private var wordToday = "----------"
    @AppStorage("startPopoverPresented") var startPopoverPresented = true
    @CloudStorage("showOnBoarding") var isFirstUse = true
    @ObservedObject private var playerModel = PlayerProfileModel.shared

    var body: some View {
        HStack {
#if os(macOS)
            List{
                StatsView(selection: $gameStatSelection)
            }
            .frame(maxWidth: 300)
#endif
            VStack {
                ScrollView{
                    PlayerProfileView()
                        .padding(.vertical, 50)

                    ({
                        var resultingText = Text("")
                        for (index, letter) in wordToday.enumerated() {
                            resultingText = resultingText + (
                                (letter == "-") ? Text(
                                    String(Array("SUPERGHOST")[index])
                                )
                                .foregroundColor(.secondary.opacity(0.5)) : Text(String(letter))
                                .foregroundColor(.accent)
                            )
                        }
                        return resultingText
                            .font(.largeTitle.bold())
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity)
                    }())

                    Text("\(wordToday.count(where: {$0 == "-"})) losses left today")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .center)

                        header



                    EventView()
                        LeaderboardView()
                        .padding()
#if !os(macOS)
                    StatsView(selection: $gameStatSelection)
#endif

                    AchievementsView()
                        .padding(.vertical)

                        SettingsButton()
                            .frame(maxWidth: .infinity)
                }
                .scrollContentBackground(.hidden)
#if os(macOS)
                .overlay{
                    if let gameStat = gameStatSelection{
                        WordDefinitionView(word: gameStat.word, game: gameStat)
                            .padding(.top)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background((gameStat.won ? Color.green.brightness(0.5).opacity(0.1) : Color.red.brightness(0.5).opacity(0.1)).ignoresSafeArea())
                            .overlay(alignment: .topTrailing){
                                Button{gameStatSelection = nil} label: {
                                    Image(systemName: "xmark")
                                }
                                .keyboardShortcut(.cancelAction)
                                .buttonBorderShape(.capsule)
                                .padding(.top)
                                .padding(.trailing)
                            }
                            .id(gameStat)
                    }
                }
#endif
            }
            .onOpenURL { url in
                if url.absoluteString.hasPrefix("https://hannesnagel.com/open/ghost/") {
                    let command = url.absoluteString.replacingOccurrences(of: "https://hannesnagel.com/open/ghost/", with: "")
                    Logger.trackEvent("link_open", with: ["command": command])
                    Logger.userInteraction.info("universal link open command: \(command, privacy: .public)")

                    if command == "instructions" {
                        isFirstUse = true
                    } else if command == "start" {
                        Task{
                            try await GameViewModel.shared.getTheGame()
                            isGameViewPresented = true
                        }
                    } else if command == "host" {
                        Task{
                            try await GameViewModel.shared.hostGame()
                            isGameViewPresented = true
                        }
                    }
                }else {
                    Task{
                        let gameId = url.lastPathComponent

                        Logger.userInteraction.info("Opened link to gameid: \(gameId, privacy: .public)")

                        try await GameViewModel.shared.joinGame(with: gameId)
                        gameStatSelection = nil
                        isGameViewPresented = true
                    }
                }
            }
        }
#if !os(macOS)
        .fullScreenCover(item: $gameStatSelection) { gameStat in
            NavigationStack{
                WordDefinitionView(word: gameStat.word, game: gameStat)
                    .toolbar{
                        ToolbarItem(placement: .cancellationAction){
                            Button{gameStatSelection = nil} label: {
                                Image(systemName: "xmark")
                            }
                            .keyboardShortcut(.cancelAction)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.bcCircle)
                        }
                    }
                    .background((gameStat.won ? Color.green.brightness(0.5).opacity(0.1) : Color.red.brightness(0.5).opacity(0.1)).ignoresSafeArea())
            }
        }
        .background(playerModel.player.color.gradient
            , ignoresSafeAreaEdges: .all)
#endif
    }
    @MainActor @ViewBuilder
    var header: some View {

        VStack{
            AsyncButton {
                try await GameViewModel.shared.getTheGame()
                isGameViewPresented = true
            } label: {
                Text("Start")
                    .font(.largeTitle)
            }
            .disabled(gkStore.games.today.lost.count >= 10)
            .popover(isPresented: $startPopoverPresented) {
                VStack{
                    Text("What are you waiting for?")
                    Text("Let's go!!!")
                }
                .padding()
                .presentationCompactAdaptation(.popover)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))

            AsyncButton {
                try await GameViewModel.shared.hostGame()
                isGameViewPresented = true
            } label: {
                Text("Host a Game")
                    .font(.largeTitle)
            }
            .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: true))



            TrialEndsInView()
                .padding()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 30)
        .padding(.horizontal)
    }
}

#Preview {
    HomeView(isGameViewPresented: .constant(false))
        .modifier(PreviewModifier())
}
