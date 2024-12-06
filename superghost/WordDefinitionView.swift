//
//  WordDefinitionView.swift
//  superghost
//
//  Created by Melanie Nagel   on 9/24/24.
//

import SwiftUI
extension View {

    @ViewBuilder
    func stretchable(in geo: GeometryProxy) -> some View {
        let width = geo.size.width
        let height = geo.size.height
        let minY = geo.frame(in: .named("list")).minY - 70
        let useStandard = minY <= 0
        self.frame(width: width, height: height + (useStandard ? 0 : minY))
            .offset(y: useStandard ? 0 : -minY)
    }
}

struct WordDefinitionView: View {
    let word: String
    @State var game: GameStat? = nil
    @State private var definitions = LoadingState.loading

    private enum LoadingState{
        case failed, loading, success(definitions: [WordEntry])
    }

    @State private var offset: CGFloat = 0

    var body: some View {

        List{
            if let game{
                Section{

                    GeometryReader{geo in
                        VStack{
                            game.player2profile?.imageView
                                .resizable()
                                .scaledToFit()
                                .clipShape(.circle)

                            Text(game.won ? "Victory against" : "Defeated by")
                                .bold()
                                .foregroundStyle(game.won ? .accent : .orange)
                            VStack{
                                Text(game.player2profile?.name ?? "Gustav")
                                if let rank = game.player2profile?.rank{
                                    Text("\(rank.ordinalString()) place")
                                } else {
                                    Text("Not ranked")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(minWidth: 100)
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(.rect(cornerRadius: 20))
                            .overlay{
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(game.won ? Color.accent : .orange)
                            }
                        }
                        .stretchable(in: geo)
                    }
                    .frame(minHeight: 230)

                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
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
                ContentPlaceHolderView(
                    "Couldn't get definitions!",
                    systemImage: "network.slash"
                )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .frame(maxWidth: .infinity, alignment: .center)
            case .loading:
                ProgressView()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            case .success(let definitions):
                if definitions.isEmpty{
                    ContentPlaceHolderView(
                        "This is not a word",
                        systemImage: "character.book.closed"
                    )
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
        .coordinateSpace(name: "list")
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
    NavigationStack{
        WordDefinitionView(word: "word", game:
                .init(
                    player2: (
                        id: "playerid",
                        profile: .init(
                            rank: 4,
                            name: "Gustav"
                        )
                    ),
                    withInvitation: true,
                    won: true,
                    word: "word",
                    id: UUID().uuidString
                )
        )
        .toolbar{

        }
    }
}
