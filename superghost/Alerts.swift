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

    let dismissParent: (() -> Void)?
    let isSuperghost: Bool
    let quitGame: (() async throws -> Void)?
    let rematch: (() async throws -> Void)?
    let word: String
    let player2Id: String

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
            ScoreChangeView()
            if alertItem == .playerLeft {
                if let quitGame{
                    Spacer()
                    AsyncButton{
                        dismissParent?()
                        try await quitGame()
                    } label: {
                        Text("Quit")
                    }
                    .buttonStyle(AppearanceManager.QuitRematch(isPrimary: true))
                    Spacer()
                }
            } else {
                Spacer()
                WordDefinitionView(word: word)
                HStack{
                    if let quitGame{
                        Spacer()
                        AsyncButton{
                            dismissParent?()
                            try await quitGame()
                        } label: {
                            Text("   Quit    ")
                        }
                        .buttonStyle(AppearanceManager.QuitRematch(isPrimary: player2Id == "botPlayer"))
                        .keyboardShortcut(.cancelAction)
                    }
                    if let rematch, player2Id != "botPlayer" {
                        Spacer()
                        AsyncButton{
                            try await rematch()
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
        .interactiveDismissDisabled()
    }
}


struct ScoreChangeView: View {
    @CloudStorage("score") private var score = 1000

    var body: some View {
        let transition : ContentTransition =
        if #available(iOS 17.0, macOS 14.0, *){
            .numericText(value: Double(score))
        } else {
            .numericText()
        }
        Text(score, format: .number)
            .font(.system(size: 70))
            .contentTransition(transition)
    }
}
#Preview{
    ScoreChangeView()
        .task{
            try? await Task.sleep(for: .seconds(1))
            await MessageModel.shared.changeScore(by: Bool.random() ? 10 : -10)
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
                    .frame(maxWidth: .infinity, alignment: .center)
            case .loading:
                ProgressView()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            case .success(let definitions):
                if definitions.isEmpty{
                    ContentPlaceHolderView("This is not a word", systemImage: "character.book.closed")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .frame(maxWidth: .infinity, alignment: .center)
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
    AlertView(alertItem: .lost, dismissParent: {}, isSuperghost: true, quitGame: {}, rematch: {}, word: "word", player2Id: "player2Id")
}
#Preview{
    AlertView(alertItem: .playerLeft, dismissParent: {}, isSuperghost: true, quitGame: {}, rematch: {}, word: "word", player2Id: "player2Id")
}
#Preview{
    AlertView(alertItem: .won, dismissParent: {}, isSuperghost: true, quitGame: {}, rematch: {}, word: "word", player2Id: "player2Id")
}
