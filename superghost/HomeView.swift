//
//  HomeView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI

struct HomeView: View {
    let isSuperghost: Bool
    @State private var gameStatSelection: GameStat?
    @ObservedObject var gkStore = GKStore.shared
    @Binding var isGameViewPresented: Bool
    @CloudStorage("wordToday") private var wordToday = "-----"
    @AppStorage("startPopoverPresented") var startPopoverPresented = true
    @CloudStorage("showOnBoarding") var isFirstUse = true

    var body: some View {
        HStack {
#if os(macOS)
            List{
                Text("Recent Games")
                    .font(.title.bold())
                StatsView(selection: $gameStatSelection, isSuperghost: isSuperghost)
            }
            .frame(maxWidth: 300)
#endif
            VStack {
                List{
                    PlayerProfileView()
                    Section{
                        header
                            .listRowBackground(Color.clear)
                            .listRowInsets(.none)
                            .listItemTint(ListItemTint?.none)
                            .listRowSeparator(.hidden)
                    }
                    Section{
                        {
                            var resultingText = Text("")
                            for (index, letter) in wordToday.enumerated() {
                                resultingText = resultingText + ((letter == "-") ? Text(String(Array("SUPERGHOST")[index])).foregroundColor(.secondary.opacity(0.5)) : Text(String(letter)).foregroundColor(.accent))
                            }
                            return resultingText
                        }()
                            .font(.largeTitle.bold())
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity)
                        Text("\(wordToday.count(where: {$0 == "-"}), format: .number) losses left today")
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    EventView()
                    Section{
                        LeaderboardView(isSuperghost: isSuperghost)
                    }
                    Section{
                        AchievementsView()
                    }
#if !os(macOS)
                    Section{
                        StatsView(selection: $gameStatSelection, isSuperghost: isSuperghost)
                    }
#endif
                    Section{
                        SettingsButton(isSuperghost: isSuperghost)
                            .listRowBackground(Color.clear)
                            .frame(maxWidth: .infinity)
                    }
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
                                .buttonBorderShape(.bcCapsule)
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
                    Logger.userInteraction.info("universal link open command: \(command, privacy: .public)")

                    if command == "instructions" {
                        isFirstUse = true
                    } else if command == "paywall" {
                        UserDefaults.standard.set(true, forKey: "showingPaywall")
                    } else if command == "start" {
                        Task{
                            try await GameViewModel.shared.getTheGame(isSuperghost: isSuperghost)
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

                        try await GameViewModel.shared.joinGame(with: gameId, isSuperghost: isSuperghost)
                        gameStatSelection = nil
                        isGameViewPresented = true
                    }
                }
            }
        }
#if !os(macOS)
        .sheet(item: $gameStatSelection) { gameStat in
            NavigationStack{
                WordDefinitionView(word: gameStat.word, game: gameStat)
                    .padding(.top)
                    .toolbar{
                        ToolbarItem(placement: .cancellationAction){
                            Button{gameStatSelection = nil} label: {
                                Image(systemName: "xmark")
                            }
                            .keyboardShortcut(.cancelAction)
                        }
                    }
                    .background((gameStat.won ? Color.green.brightness(0.5).opacity(0.1) : Color.red.brightness(0.5).opacity(0.1)).ignoresSafeArea())
            }
        }
#endif
    }
    @MainActor @ViewBuilder
    var header: some View {

        VStack{
            AsyncButton {
                try await GameViewModel.shared.getTheGame(isSuperghost: isSuperghost)
                isGameViewPresented = true
            } label: {
                Text("Start")
                    .font(.largeTitle)
            }
            .disabled(gkStore.games.today.lost.count >= (isSuperghost ? 10 : 5))
            .popover(isPresented: $startPopoverPresented) {
                if #available(macOS 13.3, iOS 17.3, *) {
                    VStack{
                        Text("What are you waiting for?")
                        Text("Let's go!!!")
                    }
                    .padding()
                    .presentationCompactAdaptation(.popover)
                }
            }
            .onTapGesture {
                if !isSuperghost && gkStore.games.today.lost.count >= 5{
                    UserDefaults.standard.set(true, forKey: "showingPaywall")
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(AppearanceManager.HapticStlyeCustom(buttonStyle: AppearanceManager.FullWidthButtonStyle(isSecondary: false)))

            AsyncButton {
                try await GameViewModel.shared.hostGame()
                isGameViewPresented = true
            } label: {
                Text("Host a Game")
                    .font(.largeTitle)
            }
            .buttonStyle(AppearanceManager.HapticStlyeCustom(buttonStyle: AppearanceManager.FullWidthButtonStyle(isSecondary: true)))



            TrialEndsInView()
                .padding()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 30)
        .textCase(nil)
    }
}

#Preview {
    HomeView(isSuperghost: true, isGameViewPresented: .constant(false))
        .modifier(PreviewModifier())
}
