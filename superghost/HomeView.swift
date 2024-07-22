//
//  HomeView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    let isSuperghost: Bool
    let showTrialEndsIn: Int?
    @State private var gameStatSelection: GameStat?
    @EnvironmentObject var viewModel: GameViewModel
    @Binding var isGameViewPresented: Bool
    @Query(sort: [SortDescriptor(\GameStat.createdAt, order: .reverse)]) var games : [GameStat]

    var body: some View {
            VStack {
                List{
                    Section{
                        StatsView(selection: $gameStatSelection, isSuperghost: isSuperghost)
                    } header: {
                        header
                    }
                }
#if os(macOS)
                .listStyle(.sidebar)
#endif
                .scrollContentBackground(.hidden)
            }
            .onOpenURL { url in
                Task{
                    let gameId = url.lastPathComponent

                    try await viewModel.joinGame(with: gameId)
                    gameStatSelection = nil
                    isGameViewPresented = true
                }
            }
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
    }
    @MainActor @ViewBuilder
    var header: some View {

        VStack{

            HStack{
                if let showTrialEndsIn {
                    Spacer()
                    TrialEndsInView(days: showTrialEndsIn)
                }
                Spacer()
                SettingsButton(isSuperghost: isSuperghost)
                    .font(ApearanceManager.settingsButton)
                    .textCase(nil)
            }
            WaitingGhost()

            AsyncButton {
                try await viewModel.getTheGame()
                isGameViewPresented = true
            } label: {
                Text("Start")
            }
            .disabled(games.today.lost.count >= (isSuperghost ? 10 : 5))
#if !os(watchOS)
            .keyboardShortcut(.defaultAction)
#endif
            .font(ApearanceManager.startGame)

            AsyncButton {
                try await viewModel.hostGame()
                isGameViewPresented = true
            } label: {
                Text("Host a Game")
            }
            .font(ApearanceManager.hostGame)
        }
        .buttonStyle(.bordered)
        .tint(.accent)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 30)
    }
}

#Preview {
    HomeView(isSuperghost: true, showTrialEndsIn: 2, isGameViewPresented: .constant(false))
        .modifier(PreviewModifier())
}
