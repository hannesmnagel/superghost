//
//  Alerts.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI

enum AlertItem: String, Equatable, Identifiable {
    var id: String {self.rawValue}
    case won, lost, playerLeft
}


struct AlertView: View {
    @State var alertItem: AlertItem
    @EnvironmentObject var viewModel: GameViewModel
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss
    let isSuperghost: Bool

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
            Text(alertItem == .won ? "You won!" : alertItem == .playerLeft ? "Player left": "You lost!")
                .font(AppearanceManager.youWonOrLost)
            Text(alertItem == .won ? "Can you win another one?" : alertItem == .playerLeft ? "Play a new game" : "Get revenge!")
                .font(AppearanceManager.youWonOrLostSubtitle)
                .padding(.bottom)
            if alertItem == .playerLeft {
                Spacer()
                AsyncButton{
                    isPresented = false
                    try await viewModel.quitGame(isSuperghost: isSuperghost)
                } label: {
                    Text("Quit")
                }
                .buttonStyle(AppearanceManager.QuitRematch(isPrimary: true))
                Spacer()
            } else {
                Spacer()
                let word = viewModel.game?.moves.last?.word.uppercased() ?? ""
                WordDefinitionView(word: word)
                HStack{
                    Spacer()
                    AsyncButton{
                        isPresented = false
                        try await viewModel.quitGame(isSuperghost: isSuperghost)
                    } label: {
                        Text("   Quit    ")
                    }
                    .buttonStyle(AppearanceManager.QuitRematch(isPrimary: viewModel.game?.player2Id == "botPlayer"))
                    .keyboardShortcut(.cancelAction)
                    if viewModel.game?.player2Id != "botPlayer"{
                        Spacer()
                        AsyncButton{
                            viewModel.game?.winningPlayerId.removeAll()
                            viewModel.alertItem = nil
                            try await viewModel.resetGame(isSuperghost: isSuperghost)
                        } label: {
                            Text("Rematch")
                        }
                        .buttonStyle(AppearanceManager.QuitRematch(isPrimary: true))
                        .keyboardShortcut(.defaultAction)
                    }

                    Spacer()
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
    @State private var definitions = LoadingState.loading

    private enum LoadingState{
        case failed, loading, success(definitions: [WordEntry])
    }

    var body: some View {

        List{
            Section{
                Text(word)
                    .padding(.leading)
                    .font(AppearanceManager.wordInDefinitionView)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .task {
                        do {
                            let loadedDefinitions = try await define(word)
                            definitions = .success(definitions: loadedDefinitions)
                        } catch let error as DecodingError {
                            let _ = error
                            definitions = .success(definitions: [])
                        } catch {
                            definitions = .failed
                        }
                    }
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
                    .padding()
                    .padding(.vertical, 50)
                    .listRowSeparator(.hidden)
            }
            switch definitions {
            case .failed:
                ContentPlaceHolderView("Couldn't get definitions!", systemImage: "network.slash")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            case .loading:
                ProgressView()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            case .success(let definitions):
                if definitions.isEmpty{
                    ContentPlaceHolderView("This is not a word", systemImage: "character.book.closed")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(definitions, id: \.self) { entry in
                        viewFor(entry: entry)
                    }
                }
            }

            if let game{
                Section{
                    VStack(alignment: .center){
                        if game.withInvitation {Text(game.won ? "You won against a friend on \(game.createdAt, format: .dateTime)" : "You lost against a friend on \(game.createdAt, format: .dateTime)")}
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.top, 30)
                }
            }
        }
        .listStyle(.plain)
    }
    @MainActor @ViewBuilder
    func viewFor(entry: WordEntry) -> some View {
        ForEach(entry.meanings, id: \.self) { meaning in
            Section{
                ForEach(meaning.definitions, id: \.self) { definition in
                    GridRow{
                        VStack(alignment: .leading, spacing: 2) {
                            Text(definition.definition)
                                .font(AppearanceManager.definitions)

                            if !definition.synonyms.isEmpty {
                                Text("Synonyms: \(definition.synonyms.joined(separator: ", "))")
                                    .font(AppearanceManager.synonyms)
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

#Preview{
    AlertView(alertItem: .lost, isPresented: .constant(true), isSuperghost: true)
        .modifier(PreviewModifier())
}
#Preview{
    AlertView(alertItem: .playerLeft, isPresented: .constant(true), isSuperghost: true)
        .modifier(PreviewModifier())
}
#Preview{
    AlertView(alertItem: .won, isPresented: .constant(true), isSuperghost: true)
        .modifier(PreviewModifier())
}
