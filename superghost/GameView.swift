//
//  GameView.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI

struct GameView: View {
    @EnvironmentObject var viewModel : GameViewModel
    @Binding var isPresented: Bool
    let isSuperghost: Bool
    let appearingDate = Date()

    var body: some View {

        VStack {
            HStack{
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(AppearanceManager.quitGame)
                    .hidden()
                Spacer()
                switch viewModel.gameStatusText {
                case .waitingForPlayer:
                    Text("Waiting for Player")
                case .started:
                    Text("Game started")
                }
                Spacer()
                AsyncButton{
                    isPresented = false
                    try await viewModel.quitGame(isSuperghost: isSuperghost)
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(AppearanceManager.quitGame)
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
            }
            if viewModel.gameStatusText == .waitingForPlayer{
                Text(appearingDate, style: .timer)
                    .monospacedDigit()
                + Text(" elapsed - ETA:") + Text(appearingDate.addingTimeInterval(.random(in: 3...6)), style: .relative)
                    .monospacedDigit()
            }
            Spacer()

            //MARK: Private Game Share Link Screen
            if (viewModel.game?.player2Id ?? "").isEmpty || viewModel.game?.player2Id == "privateGame" {
                LoadingView()
                if viewModel.game?.player2Id == "privateGame"{
                    if let url = URL(string: "https://hannesnagel.com/superghost/private/\(viewModel.game?.id ?? "")"){
                        Text("Send Invitation Link")
                        ShareLink(item: url)
                    }
                }
                //MARK: Playing:
            } else if let game = viewModel.game{
                VStack {
                    if game.challengingUserId.isEmpty {
                        if game.blockMoveForPlayerId != viewModel.currentUser.id {
                            ContentPlaceHolderView("It's your turn", systemImage: "scribble", description: "Make your move!")
                                .transition(.scale(scale: 0.1, anchor: .bottom))
                            if viewModel.games.isEmpty{
                                if let word = game.moves.last?.word,
                                   !word.isEmpty {
                                    Text("Can you think of a word that \(isSuperghost ? "contains" : "starts with") \(word)?")
                                    Text("Select a letter so that this still is the case or challenge your opponent")
                                } else {
                                    Text("Select any Letter you want")
                                }
                            }
                        } else {
                            ContentPlaceHolderView("Waiting for Player", systemImage: "ellipsis.curlybraces", description: "Bla, Bla, Bla...")
                                .transition(.scale(scale: 0.1, anchor: .bottom))
                        }
                        LetterPicker(isSuperghost: isSuperghost)
                        if viewModel.game?.moves.last?.word.count ?? 0 > 1 {
                            AsyncButton{
                                viewModel.game?.challengingUserId = viewModel.currentUser.id
                                viewModel.game?.blockMoveForPlayerId = viewModel.currentUser.id
                                try await ApiLayer.shared.updateGame(viewModel.game!, isPrivate: viewModel.withInvitation, isSuperghost: isSuperghost)
                            } label: {
                                Text("There is no such word")
                            }
                            .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: true))
                        }
                        //MARK: When you are challenged
                    } else if game.challengingUserId != viewModel.currentUser.id{
                        ContentPlaceHolderView("Uhhh, you got challenged!", systemImage: "questionmark.square.dashed", description: "Are you sure you didn't lie?!")
                        Text(game.moves.last?.word ?? "")
                            .font(AppearanceManager.wordInGame)
                        SayTheWordButton(isSuperghost: isSuperghost)
                        AsyncButton{
                            viewModel.game!.winningPlayerId = viewModel.game?.challengingUserId ?? ""
                            try await ApiLayer.shared.updateGame(viewModel.game!, isPrivate: viewModel.withInvitation, isSuperghost: isSuperghost)
                        } label: {
                            Text("Yes, I lied")
                        }
                        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: true))
                        //MARK: When you challenged
                    } else {
                        LoadingView()
                        Text("Waiting for player response...")
                    }
                }
                .disabled(game.blockMoveForPlayerId == viewModel.currentUser.id)
                .padding()
                .animation(.bouncy, value: game)
                Spacer()
            }
        }
        .sheet(item: $viewModel.alertItem) { alertItem in
            AlertView(
                alertItem: alertItem,
                dismissParent: {isPresented = false},
                isSuperghost: isSuperghost,
                quitGame: {
                    try await viewModel.quitGame(isSuperghost: isSuperghost)
                },
                rematch: {
                    viewModel.game?.winningPlayerId.removeAll()
                    viewModel.alertItem = nil
                    try await viewModel.resetGame(isSuperghost: isSuperghost)
                },
                word: viewModel.game?.moves.last?.word ?? "",
                player2Id: viewModel.game?.player2Id ?? ""
            )
#if os(macOS) || os(visionOS)
                .frame(minWidth: 500, minHeight: 500)
#endif
        }
        .animation(.snappy, value: viewModel.gameStatusText)
        .animation(.snappy, value: viewModel.alertItem)
        .animation(.snappy, value: viewModel.game)
        .animation(.snappy, value: viewModel.game?.moves)
    }
}

#Preview{
    GameView(isPresented: .constant(true), isSuperghost: true)
        .modifier(PreviewModifier())
}
#Preview{
    let vm = {
        let result = GameViewModel()
        result.game = Game(id: "", player1Id: "", player2Id: "", blockMoveForPlayerId: "", rematchPlayerId: [], moves: [Move(isPlayer1: true, word: "WORD")])
        return result
    }()
    return LetterPicker(isSuperghost: true)
        .environmentObject(vm)
        .modifier(PreviewModifier())
}

func isWord(_ word: String) async throws -> Bool {
    if word.count < 3 {return false}
    let (data, _) = try await retry{try await URLSession.shared.data(from: URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)")!)}
    if let _ = try? JSONDecoder().decode([WordEntry].self, from: data){
        return true
    }
    return false
}
func define(_ word: String) async throws -> [WordEntry] {
    let (data, _) = try await retry{try await  URLSession.shared.data(from: URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)")!)}
    return try JSONDecoder().decode([WordEntry].self, from: data)
}

struct WordEntry: Codable, Hashable {
    let word: String
    let phonetic: String?
    let phonetics: [Phonetic]
    let origin: String?
    let meanings: [Meaning]
}

struct Phonetic: Codable, Hashable {
    let text: String
    let audio: String?
}

struct Meaning: Codable, Hashable {
    let partOfSpeech: String
    let definitions: [Definition]
}

struct Definition: Codable, Hashable {
    let definition: String
    let example: String?
    let synonyms: [String]
    let antonyms: [String]
}

struct SayTheWordButton: View {
    @EnvironmentObject var viewModel: GameViewModel
    let isSuperghost: Bool
    @State private var isExpanded = false
    @State private var word = ""
    var body: some View {
        if isExpanded{
            TextField("What word did you think of?", text: $word)
        }
        AsyncButton {
            if isExpanded {
                if try await isWord(word) && (
                    (viewModel.withInvitation || isSuperghost) ? word.localizedCaseInsensitiveContains(viewModel.game?.moves.last?.word ?? "") : word.uppercased().hasPrefix((viewModel.game?.moves.last?.word ?? "").uppercased())
                ) {
                    viewModel.game?.moves.append(.init(isPlayer1: viewModel.isPlayerOne(), word: word))
                    viewModel.game!.winningPlayerId = viewModel.currentUser.id
                    try await ApiLayer.shared.updateGame(viewModel.game!, isPrivate: viewModel.withInvitation, isSuperghost: isSuperghost)
                } else{
                    word = "This doesn't fit"
                }
            } else {
                isExpanded = true
            }
        } label: {
            Text(isExpanded ? "Confirm" : "There is a word")
        }
        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
    }
}

func retry<R:Sendable>(count: Int = 3, _ action: () async throws ->R) async rethrows -> R {
    do {
        return try await action()
    } catch {
        guard count > 0 else {throw error}
        return try await retry(count: count-1){
            try? await Task.sleep(for: .seconds(1))
            return try await action()
        }

    }
}
