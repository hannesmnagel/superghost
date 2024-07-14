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

        VStack {
            Text(viewModel.gameNotification.rawValue)

            AsyncButton{
                try await viewModel.quitGame()
                isPresented = false
            } label: {
                Text("Quit Game")
#if os(watchOS)
                    .padding(-15)
                    .font(.caption2)
#endif
            }
#if os(watchOS)
            .scaleEffect(0.5)
            .padding(.bottom, -15)
#else
            .keyboardShortcut(.cancelAction)
#endif


            Spacer()

            if (viewModel.game?.player2Id ?? "").isEmpty || viewModel.game?.player2Id == "privateGame" {
                LoadingView()
                if viewModel.game?.player2Id == "privateGame"{
                    if let url = URL(string: "superghost://hannesnagel.com/superghost/\(viewModel.game?.id ?? "")"){
                        Text("Send Invitation Link")
                        ShareLink(item: url)
                    }
                }
            } else {

                if let game = viewModel.game{

                    VStack {
                        if game.challengingUserId.isEmpty {
                            LetterPicker(viewModel: viewModel, isSuperghost: isSuperghost)
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
                                .font(ApearanceManager.headline)
                            SayTheWordButton(viewModel: viewModel)
                            AsyncButton{
                                viewModel.game!.winningPlayerId = viewModel.game?.challengingUserId ?? ""
                                try await ApiLayer.shared.updateGame(viewModel.game!, isPrivate: viewModel.withInvitation)
                            } label: {
                                Text("Yes, I lied")
                            }
                        } else {
                            LoadingView()
                            Text("Waiting for player response...")
                        }
                    }
                    .disabled(viewModel.checkForGameBoardStatus())
                    .padding()
                    .sheet(item: $viewModel.alertItem) { alertItem in
                        AlertView(alertItem: alertItem, viewModel: viewModel, isPresented: $isPresented)
                        #if os(macOS)
                            .frame(minWidth: 500, minHeight: 500)
                        #endif
                    }
                    Spacer()
                }
            }
        }
        .buttonStyle(.bordered)
        .animation(.snappy, value: viewModel.gameNotification)
        .animation(.snappy, value: viewModel.alertItem)
        .animation(.snappy, value: viewModel.game)
        .animation(.snappy, value: viewModel.game?.moves)
    }
}

struct LetterPicker: View {
    @ObservedObject var viewModel: GameViewModel
    let isSuperghost: Bool
    @State private var leadingLetter = ""
    @State private var trailingLetter = ""
    let allowedLetters = ["", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
    @State var disabled = false

    var body: some View {
        let word = viewModel.game?.moves.last?.word ?? ""
        VStackWatch{
            if !word.isEmpty {
                if viewModel.withInvitation || isSuperghost{
                    SingleLetterPicker(letter: $leadingLetter, allowedLetters: allowedLetters)
                        .disabled(!trailingLetter.isEmpty)
                }
                Text(word)
            }
            SingleLetterPicker(letter: $trailingLetter, allowedLetters: allowedLetters)
                .disabled(!leadingLetter.isEmpty)
        }
        .font(ApearanceManager.largeTitle)

        AsyncButton{
            try await viewModel.processPlayerMove(for: "\(leadingLetter)\(word)\(trailingLetter)")
            trailingLetter = ""
            leadingLetter = ""
        } label: {
            Text("Submit Move")
        }
        #if !os(watchOS)
        .keyboardShortcut(.defaultAction)
        #endif
        .disabled(leadingLetter.isEmpty && trailingLetter.isEmpty)
    }
    struct SingleLetterPicker: View {
        @Binding var letter: String
        let allowedLetters: [String]


        var body: some View {
#if !os(macOS)
            Picker("", selection: $letter) {
                ForEach(allowedLetters, id: \.self){letter in
                    Text(letter)
                }
            }
            .pickerStyle(.wheel)

#if os(watchOS)
            .frame(minHeight: 50)
#endif
#else
            TextField("Letter", text: .init(get: {
                letter
            }, set: {
                let newLetter = String($0.suffix(1))
                if allowedLetters.joined().localizedCaseInsensitiveContains(newLetter){
                    letter = newLetter.uppercased()
                }
            }))
            .font(.body)
#endif
        }
    }
}

struct VStackWatch<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View{
        #if os(watchOS)
        VStack{content}
        #else
        HStack{content}
        #endif
    }
}

#Preview{
    GameView(viewModel: GameViewModel(), isPresented: .constant(true), isSuperghost: true)
        .modifier(PreviewModifier())
}
#Preview{
    let vm = {
        let result = GameViewModel()
        result.game = Game(id: "", player1Id: "", player2Id: "", blockMoveForPlayerId: "", rematchPlayerId: [], moves: [Move(isPlayer1: true, word: "WORD")])
        return result
    }()
    return LetterPicker(viewModel: vm, isSuperghost: true)
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
                    try await ApiLayer.shared.updateGame(viewModel.game!, isPrivate: viewModel.withInvitation)
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
