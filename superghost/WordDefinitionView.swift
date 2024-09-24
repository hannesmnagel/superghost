//
//  WordDefinitionView.swift
//  superghost
//
//  Created by Melanie Nagel   on 9/24/24.
//

import SwiftUI

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

#Preview {
    WordDefinitionView(word: "word")
}
