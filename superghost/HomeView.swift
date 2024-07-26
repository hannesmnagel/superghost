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
                        header
                            .listRowBackground(Color.clear)
                            .listRowInsets(.none)
                            .listItemTint(ListItemTint?.none)
#if !os(watchOS)
                            .listRowSeparator(.hidden)
#endif
                    }
                    Section{
                        StatsView(selection: $gameStatSelection, isSuperghost: isSuperghost)
                    }
                }
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
                NavigationStack{
                    WordDefinitionView(word: gameStat.word, game: gameStat)
                        .padding(.top)
                        .toolbar{
                            ToolbarItem(placement: .cancellationAction){
#if os(iOS)
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

            HStack{
                if let showTrialEndsIn {
                    Spacer()
                    TrialEndsInView(days: showTrialEndsIn)
                        .transition(.move(edge: .top))
                }
                Spacer()
                SettingsButton(isSuperghost: isSuperghost)
            }
            .animation(.smooth, value: showTrialEndsIn)
            WaitingGhost()
                .frame(maxHeight: 400)

            AsyncButton {
                try await viewModel.getTheGame()
                isGameViewPresented = true
            } label: {
                Text("Start")
            }
            .disabled(games.today.lost.count >= (isSuperghost ? 10 : 5))
            .onTapGesture {
                if !isSuperghost && games.today.lost.count >= 5{
                    viewModel.showPaywall = true
                }
            }
#if !os(watchOS)
            .keyboardShortcut(.defaultAction)
#endif
            .buttonStyle(AppearanceManager.StartGame())

            AsyncButton {
                try await viewModel.hostGame()
                isGameViewPresented = true
            } label: {
                Text("Host a Game")
            }
            .buttonStyle(AppearanceManager.HostGame())
        }
        .tint(.accent)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 30)
        .textCase(nil)
    }
}

#Preview {
    HomeView(isSuperghost: true, showTrialEndsIn: 2, isGameViewPresented: .constant(false))
        .modifier(PreviewModifier())
}
