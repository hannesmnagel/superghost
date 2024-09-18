//
//  HomeView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI

struct HomeView: View {
    let isSuperghost: Bool
    let showTrialEndsIn: Int?
    @State private var gameStatSelection: GameStat?
    @EnvironmentObject var viewModel: GameViewModel
    @Binding var isGameViewPresented: Bool
    @CloudStorage("wordToday") private var wordToday = "-----"
    @AppStorage("startPopoverPresented") var startPopoverPresented = true
    @CloudStorage("isFirstUse") var isFirstUse = true

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
                ScrollViewReader{scroll in
                    List{
                        Section{
                            header
                                .onAppear{
                                    scroll.scrollTo("wordtoday")
                                }
                                .listRowBackground(Color.clear)
                                .listRowInsets(.none)
                                .listItemTint(ListItemTint?.none)
                                .listRowSeparator(.hidden)
                        }
                        Section{
                            {
                                var resultingText = Text("")
                                for letter in wordToday {
                                    resultingText = resultingText + ((letter == "-") ? Text(String(letter)).foregroundColor(.secondary) : Text(String(letter)).foregroundColor(.accent))
                                }
                                return resultingText
                            }()
                                .font(.largeTitle.bold())
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity)
                        }
                        .id("wordtoday")
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
                }
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
                    Logger.remoteLog("universal link open command: \(command)")
                    if command == "instructions" {
                        isFirstUse = true
                    } else if command == "paywall" {
                        viewModel.showPaywall = true
                    } else if command == "start" {
                        Task{
                            try await viewModel.getTheGame(isSuperghost: isSuperghost)
                            isGameViewPresented = true
                        }
                    } else if command == "host" {
                        Task{
                            try await viewModel.hostGame()
                            isGameViewPresented = true
                        }
                    }
                }else {
                    Task{
                        let gameId = url.lastPathComponent
                        
                        Logger.userInteraction.info("Opened link to gameid: \(gameId, privacy: .public)")
                        Logger.remoteLog("Opened link to gameid: \(gameId)")
                        
                        try await viewModel.joinGame(with: gameId, isSuperghost: isSuperghost)
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
            WaitingGhost()
                .frame(maxHeight: 300)

            AsyncButton {
                try await viewModel.getTheGame(isSuperghost: isSuperghost)
                isGameViewPresented = true
            } label: {
                Text("Start")
            }
            .disabled(viewModel.games.today.lost.count >= (isSuperghost ? 10 : 5))
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
                if !isSuperghost && viewModel.games.today.lost.count >= 5{
                    viewModel.showPaywall = true
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(AppearanceManager.StartGame())

            AsyncButton {
                try await viewModel.hostGame()
                isGameViewPresented = true
            } label: {
                Text("Host a Game")
            }
            .buttonStyle(AppearanceManager.HostGame())


                if let showTrialEndsIn {
                    TrialEndsInView(days: showTrialEndsIn)
                        .transition(.move(edge: .top))
                        .animation(.smooth, value: showTrialEndsIn)
                        .padding()
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 30)
        .textCase(nil)
    }
}

#Preview {
    HomeView(isSuperghost: true, showTrialEndsIn: 2, isGameViewPresented: .constant(false))
        .modifier(PreviewModifier())
}
