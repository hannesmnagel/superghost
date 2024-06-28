//
//  GameView.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI

struct GameView: View {
    @ObservedObject var viewModel : GameViewModel
    @Binding var isPresented: Bool
    let namespace: Namespace.ID

    var body: some View {
        VStack {
            Text(viewModel.gameNotification.rawValue)

            AsyncButton{
                try await viewModel.quitGame()
                isPresented = false
            } label: {
                Text("Quit Game")
            }
            .keyboardShortcut(.cancelAction)


            Spacer()

            if (viewModel.game?.player2Id ?? "").isEmpty || viewModel.game?.player2Id == "privateGame" {
                LoadingView(namespace: namespace)
                if viewModel.game?.player2Id == "privateGame"{
                    if let url = URL(string: "superghost://superghost.dev/\(viewModel.game?.id ?? "")"){
                        Text("Send Invitation Link")
                        ShareLink(item: url)
                    }
                }
            }

            if let game = viewModel.game{

                VStack {
                    if game.challengingUserId.isEmpty {
                        LetterPicker(viewModel: viewModel)
                        if viewModel.game?.moves.last?.word.count ?? 0 > 2 {
                            AsyncButton{
                                viewModel.game?.challengingUserId = viewModel.currentUser.id
                                viewModel.game?.blockMoveForPlayerId = viewModel.currentUser.id
                                try await ApiLayer.shared.updateGame(viewModel.game!)
                            } label: {
                                Text("There is no such word")
                            }
                        }
                    } else if game.challengingUserId != viewModel.currentUser.id{
                        Text(game.moves.last?.word ?? "")
                            .font(.headline)
                        SayTheWordButton(viewModel: viewModel)
                        AsyncButton{
                            viewModel.game!.winningPlayerId = viewModel.game?.challengingUserId ?? ""
                            try await ApiLayer.shared.updateGame(viewModel.game!)
                        } label: {
                            Text("Yes, I lied")
                        }
                    } else {
                    }
                }
                .disabled(viewModel.checkForGameBoardStatus())
                .padding()
                .sheet(item: $viewModel.alertItem) { alertItem in
                    AlertView(alertItem: alertItem, viewModel: viewModel, isPresented: $isPresented)
                }
                Spacer()
            }
        }
        .buttonStyle(.borderedProminent)
        .animation(.snappy, value: viewModel.gameNotification)
        .animation(.snappy, value: viewModel.alertItem)
        .animation(.snappy, value: viewModel.game)
        .animation(.snappy, value: viewModel.game?.moves)
    }
}

struct LetterPicker: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var leadingLetter = ""
    @State private var trailingLetter = ""
    let allowedLetters = ["", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
    @State var disabled = false

    var body: some View {
        let word = viewModel.game?.moves.last?.word ?? ""
        HStack{
            Picker("", selection: $leadingLetter) {
                ForEach(allowedLetters, id: \.self){letter in
                    Text(letter)
                }
            }
            .disabled(!trailingLetter.isEmpty)
            if !word.isEmpty {
                Text(word)
                Picker("", selection: $trailingLetter) {
                    ForEach(allowedLetters, id: \.self){letter in
                        Text(letter)
                    }
                }
                .disabled(!leadingLetter.isEmpty)
            }
        }
        .font(.largeTitle)
        .pickerStyle(.wheel)

        AsyncButton{
            try await viewModel.processPlayerMove(for: "\(leadingLetter)\(word)\(trailingLetter)")
            trailingLetter = ""
            leadingLetter = ""
        } label: {
            Text("Submit Move")
        }
        .disabled(leadingLetter.isEmpty && trailingLetter.isEmpty)
    }
}

#Preview{
    @Namespace var namespace
    return GameView(viewModel: GameViewModel(), isPresented: .constant(true), namespace: namespace)
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
    @ObservedObject var viewModel: GameViewModel
    @State private var isExpanded = false
    @State private var word = ""
    var body: some View {
        if isExpanded{
            TextField("What word did you think of?", text: $word)
        }
        AsyncButton {
            if isExpanded {
                if try await isWord(word) && word.localizedCaseInsensitiveContains(viewModel.game?.moves.last?.word ?? "") {
                    viewModel.game?.moves.append(.init(isPlayer1: viewModel.isPlayerOne(), word: word))
                    viewModel.game!.winningPlayerId = viewModel.currentUser.id
                    try await ApiLayer.shared.updateGame(viewModel.game!)
                } else{
                    word = "This doesn't fit"
                }
            } else {
                isExpanded = true
            }
        } label: {
            Text(isExpanded ? "Confirm" : "There is a word")
        }
    }
}

struct ContentPlaceHolderView: View {
    @State var title: String
    @State var systemImage: String
    @State var description: String


    var body: some View {
        if #available(iOS 17.0, *){
            ContentUnavailableView(title, systemImage: systemImage, description: Text(description))
        } else {
            VStack{
                Image(systemName: systemImage)
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 7)
                Text(title)
                    .font(.title2.bold())
                Text(description)
                    .frame(width: 360)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 20)

        }
    }
}
func retry<R:Sendable>( _ action: () async throws ->R) async rethrows -> R {
    do {
        return try await action()
    } catch {

        return try await retry{
            try? await Task.sleep(nanoseconds: 700000000)
            return try await action()
        }

    }
}
