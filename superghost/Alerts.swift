//
//  Alerts.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import SwiftData

enum AlertItem: String, Equatable, Identifiable {
    var id: String {self.rawValue}
    case won, lost, playerLeft
}

enum GameNotification: String {
    case waitingForPlayer = "Waiting for player"
    case started = "Game has started"
    case finished = "Player left the game"
}

struct AlertView: View {
    @State var alertItem: AlertItem
    @EnvironmentObject var viewModel: GameViewModel
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss


    @Query private var games : [GameStat]
    @Environment(\.modelContext) var context

    var body: some View {
        ViewThatFits{
            content
            ScrollView{
                content
            }
        }
    }
    @ViewBuilder @MainActor
    var content: some View {

        VStack{
            Text(alertItem == .won ? "You won!" : "You lost!")
                .font(ApearanceManager.largeTitle.bold())
            Text(alertItem == .won ? "Can you win another one?" : "Get a revenge!")
                .font(ApearanceManager.headline)
                .padding(.bottom)
            if alertItem == .playerLeft {
                AsyncButton{
                    try await viewModel.quitGame()
                    isPresented = false
                } label: {
                    Text("Quit")
                }
            } else {
                Spacer()
                let word = viewModel.game?.moves.last?.word.uppercased() ?? ""
                WordDefinitionView(word: word)
                HStack{
                    Spacer()
                    AsyncButton{
                        try await viewModel.quitGame()
                        isPresented = false
                    } label: {
                        Text("Quit        ")
                    }
#if !os(watchOS)
                    .keyboardShortcut(.cancelAction)
#endif
                    if viewModel.game?.player2Id != "botPlayer"{
                        Spacer()
                        AsyncButton{
                            viewModel.game?.winningPlayerId.removeAll()
                            viewModel.alertItem = nil
                            try await viewModel.resetGame()
                        } label: {
                            Text("Rematch")
                        }
#if !os(watchOS)
                        .keyboardShortcut(.defaultAction)
#endif
                    }

                    Spacer()
                }
                .onAppear{
                    let isPlayerOne = viewModel.isPlayerOne()
                    guard let game = viewModel.game else {return}
                    let playerId = isPlayerOne ? game.player1Id : game.player2Id
                    context.insert(
                        GameStat(
                            player2: isPlayerOne ? game.player2Id : game.player1Id,
                            withInvitation: viewModel.withInvitation,
                            won: game.winningPlayerId == playerId,
                            word: game.moves.last?.word.uppercased() ?? "",
                            id: game.id
                        )
                    )
                }
                Spacer()
            }
        }
        .padding()
        .buttonStyle(.bordered)
        .interactiveDismissDisabled(viewModel.alertItem != nil)
    }
}


struct WordDefinitionView: View {
    let word: String
    @State var game: GameStat? = nil
    @State private var definitions = [WordEntry]()

    var body: some View {

        List{
            Section{
                Text(word)
                    .padding(.leading)
                    .font(ApearanceManager.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .task {
                        definitions = (try? await define(word)) ?? []
                    }
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
                #if !os(watchOS)
                    .padding()
                    .padding(.vertical, 50)
                #endif
            }
            ForEach(definitions, id: \.self) { entry in
                viewFor(entry: entry)
            }
            if let game{
                Section{
                    #if os(watchOS)
                    let alignment = HorizontalAlignment.leading
                    #else
                    let alignment = HorizontalAlignment.center
                    #endif

                    VStack(alignment: alignment){
                        if game.withInvitation {Text(game.won ? "You won against a friend at" : "You lost against a friend at")}
                        Text(game.createdAt, format: .dateTime)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    #if !os(watchOS)
                    .padding(.top, 30)
                    #endif
                }
            }
        }
        .listStyle(.plain)
        #if os(watchOS)
        .scrollClipDisabled()
        #endif
        .overlay{
            if definitions.isEmpty{
                ContentPlaceHolderView(title: "Couldn't get definitions!", systemImage: "character.book.closed", description: "")
            }
        }
    }
    @MainActor @ViewBuilder
    func viewFor(entry: WordEntry) -> some View {
        ForEach(entry.meanings, id: \.self) { meaning in
            Section{
                ForEach(meaning.definitions, id: \.self) { definition in
                    GridRow{
                        VStack(alignment: .leading, spacing: 2) {
                            Text(definition.definition)
                                .font(ApearanceManager.body)

                            if !definition.synonyms.isEmpty {
                                Text("Synonyms: \(definition.synonyms.joined(separator: ", "))")
                                    .font(ApearanceManager.footnote)
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
