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
    @ObservedObject var viewModel: GameViewModel
    @Binding var isGameViewPresented: Bool
    @Query(sort: [SortDescriptor(\GameStat.createdAt, order: .reverse)]) var games : [GameStat]

    var body: some View {
        GeometryReader{geo in
            VStack {
                List{
                    Section{
                        StatsView(selection: $gameStatSelection, isSuperghost: isSuperghost)
                    } header: {
                        VStack{

                            HStack{
                                if let showTrialEndsIn {
                                    Spacer()
                                    Group{
                                        Text("Trial ends in \(showTrialEndsIn, format: .number) days. \n")
                                            .foregroundStyle(.red)
                                            .font(ApearanceManager.headline) + Text("Upgrade now!")
                                            .foregroundStyle(.accent)
                                            .font(.subheadline)
                                            .underline()
                                    }.onTapGesture {
                                        viewModel.showPaywall = true
                                    }
                                    .multilineTextAlignment(.center)
                                }
                                Spacer()
                                SettingsButton(viewModel: viewModel, isSuperghost: isSuperghost)
                                    .font(ApearanceManager.title)
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
                            .font(ApearanceManager.title)

                            AsyncButton {
                                try await viewModel.hostGame()
                                isGameViewPresented = true
                            } label: {
                                Text("Host a Game")
                            }
                            .font(ApearanceManager.title)
                        }
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
    }
}

#Preview {
    HomeView(isSuperghost: true, showTrialEndsIn: nil, viewModel: GameViewModel(), isGameViewPresented: .constant(false))
        .modifier(PreviewModifier())
}
