//
//  HomeView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var gameStatSelection: GameStat?
    @State var isSuperghost: Bool
    @State var showTrialEndsIn: Int?
    @ObservedObject var viewModel: GameViewModel
    @Binding var isGameViewPresented: Bool
    @Query(sort: [SortDescriptor(\GameStat.createdAt, order: .reverse)]) var games : [GameStat]

    var body: some View {
        GeometryReader{geo in
            VStack {
                List{
                    Section{
                        StatsView(selection: $gameStatSelection, isSuperghost: isSuperghost)
                            .id(isSuperghost.description.appending(gameStatSelection.debugDescription))
                    } header: {
                        VStack{

                            HStack{
                                if let showTrialEndsIn {
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
                                SettingsButton()
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

#Preview {
    HomeView(gameStatSelection: .constant(nil), isSuperghost: true, viewModel: GameViewModel(), isGameViewPresented: .constant(false))
}
