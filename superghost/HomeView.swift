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

    var body: some View {
            VStack {
                List{
                    Section{
                        header
                            .listRowBackground(Color.clear)
                            .listRowInsets(.none)
                            .listItemTint(ListItemTint?.none)
                            .listRowSeparator(.hidden)
                    }
                    Section{
                        LeaderboardView(isSuperghost: isSuperghost)
                    }
                    Section{
                        StatsView(selection: $gameStatSelection, isSuperghost: isSuperghost)
                    }
                    Section{
                        SettingsButton(isSuperghost: isSuperghost)
                            .listRowBackground(Color.clear)
                            .frame(maxWidth: .infinity)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .onOpenURL { url in
                Task{
                    let gameId = url.lastPathComponent

                    try await viewModel.joinGame(with: gameId, isSuperghost: isSuperghost)
                    gameStatSelection = nil
                    isGameViewPresented = true
                }
            }
            .sheet(item: $gameStatSelection) { gameStat in
                NavigationStack{
                    WordDefinitionView(word: gameStat.word, game: gameStat)
                        .padding(.top)
                        .toolbar{
                            ToolbarItem(placement: .cancellationAction){
#if os(iOS) || os(visionOS)
                                Button{gameStatSelection = nil} label: {
                                    Image(systemName: "xmark")
                                }
#elseif os(macOS)
                                Button("Done"){gameStatSelection = nil}

#endif
                            }
                        }
                        .background((gameStat.won ? Color.green.brightness(0.5).opacity(0.1) : Color.red.brightness(0.5).opacity(0.1)).ignoresSafeArea())
#if os(macOS)
                        .frame(minWidth: 500, minHeight: 500)
#endif
                }
            }
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
