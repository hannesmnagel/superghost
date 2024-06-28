//
//  Alerts.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI

struct AlertItem: Identifiable, Equatable, Hashable {
    let id = UUID()
    var isForQuit = false
    var title: String
    var message: String
    var buttonTitle: String

    static let youWin = AlertItem(title: "You Win!", message: "You are good at this game!", buttonTitle: "Rematch")

    static let youLost = AlertItem(title: "You Lost!", message: "Get a revenge!", buttonTitle: "Rematch")

    static let quit = AlertItem(isForQuit: true, title: "GameOver", message: "Other player left.", buttonTitle: "Quit")
}

enum GameNotification: String {
    case waitingForPlayer = "Waiting for player"
    case started = "Game has started"
    case finished = "Player left the game"
}


struct AlertView: View {
    @State var alertItem: AlertItem
    @ObservedObject var viewModel: GameViewModel
    @Binding var isPresented: Bool
    @State var definitions = [WordEntry]()
    @Environment(\.dismiss) var dismiss


    @AppStorage("gameStats") private var games = [GameStat]()

    var body: some View {
        VStack{
            Text(alertItem.title)
                .font(.largeTitle.bold())
            Text(alertItem.message)
                .font(.headline)
                .padding(.bottom)
            if alertItem.isForQuit{
                AsyncButton{
                    try await viewModel.quitGame()
                    isPresented = false
                } label: {
                    Text(alertItem.buttonTitle)
                }
            } else {
                Spacer()
                let word = viewModel.game?.moves.last?.word ?? ""
                Text(word)
                    .padding(.leading)
                    .font(.largeTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .task {
                        definitions = (try? await define(word)) ?? []
                    }
                List{
                    ForEach(definitions, id: \.self) { entry in
                        ForEach(entry.meanings, id: \.self) { meaning in
                            Section{
                                ForEach(meaning.definitions, id: \.self) { definition in
                                    GridRow{
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(definition.definition)
                                                .font(.body)

                                            if !definition.synonyms.isEmpty {
                                                Text("Synonyms: \(definition.synonyms.joined(separator: ", "))")
                                                    .font(.footnote)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }

                                }
                            } header: {
                                Text(entry.word) + Text(" - ") + Text(meaning.partOfSpeech.capitalized)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .overlay{
                    if definitions.isEmpty{
                        ContentPlaceHolderView(title: "This is not a word!", systemImage: "character.book.closed", description: "")
                    }
                }
                HStack{
                    Spacer()
                    AsyncButton{
                        try await viewModel.quitGame()
                        isPresented = false
                    } label: {
                        Text("Quit        ")
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    AsyncButton{
                        viewModel.game?.winningPlayerId.removeAll()
                        viewModel.alertItem = nil
                        try await viewModel.resetGame()
                    } label: {
                        Text(alertItem.buttonTitle)
                    }
                    .keyboardShortcut(.defaultAction)

                    Spacer()
                }
                .onAppear{
                    let isPlayerOne = viewModel.isPlayerOne()
                    guard let game = viewModel.game else {return}
                    let playerId = isPlayerOne ? game.player1Id : game.player2Id
                    games.append(
                        .init(
                            player2: isPlayerOne ? game.player2Id : game.player1Id,
                            won: game.winningPlayerId == playerId,
                            word: game.moves.last?.word ?? ""
                        )
                    )
                }
                Spacer()
            }
        }
        .padding()
        .buttonStyle(.borderedProminent)
        .interactiveDismissDisabled(viewModel.alertItem != nil)
    }
}
