//
//  GameView.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI

struct GameView: View {
    @ObservedObject var viewModel = GameViewModel.shared
    @Binding var isPresented: Bool
    let appearingDate = Date()
    @Namespace var namespace

    var body: some View {
        if let alertItem = viewModel.alertItem {
            
            AlertView(
                alertItem: alertItem,
                dismissParent: {isPresented = false},
                quitGame: {
                    try await viewModel.quitGame()
                },
                rematch: {
                    try await viewModel.resetGame()
                },
                word: viewModel.game?.word ?? "",
                player2Id: viewModel.game?.player2Id ?? ""
            )
            .frame(maxWidth: .infinity)
        } else {
            VStack {
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
                        if let url = URL(string: "https://hannesnagel.com/api/v2/superghost/private/\(viewModel.game?.id ?? "")"){
                            Text("Send Invitation Link")
                            ShareLink(item: url)
                                .buttonStyle(AppearanceManager.HapticStlyeCustom(buttonStyle: AppearanceManager.FullWidthButtonStyle(isSecondary: false)))
                        }
                    }
                    //MARK: Playing:
                } else if let game = viewModel.game{
                    VStack {
                        VStack{
                            let profile = viewModel.isPlayerOne() ? game.player2profile : game.player1profile
                            Image(profile?.image ?? Skin.cowboy.image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(.circle)
                                .padding(5)
                                .overlay(Circle().stroke(.red, lineWidth: 5))
                                .frame(maxWidth: 200)
                            Text(profile?.name ?? "")
                                .font(.title.bold())
                            if let rank = profile?.rank, rank > 0 {
                                Text("Rank \(rank.formatted())")
                            } else {
                                Text("Not ranked")
                            }
                        }
                        .modifier(FlippingModifier(isActive: game.challengingUserId == viewModel.currentUser.id))
                        .scaleEffect(game.isBlockingMoveForPlayerOne == viewModel.isPlayerOne() ? 1 : 0.5)
                        VStack{
                            let profile = viewModel.isPlayerOne() ? game.player1profile : game.player2profile
                            Image(profile?.image ?? Skin.cowboy.image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(.circle)
                                .padding(5)
                                .overlay(Circle().stroke(.blue, lineWidth: 5))
                                .frame(maxWidth: 200)
                            Text(profile?.name ?? "")
                                .font(.title.bold())
                            if let rank = profile?.rank, rank > 0 {
                                Text("Rank \(rank.formatted())")
                            } else {
                                Text("Not ranked")
                            }
                        }
                        .scaleEffect(game.isBlockingMoveForPlayerOne == viewModel.isPlayerOne() ? 0.5 : 1)
                        if game.player1Challenges == nil {
                            if game.blockMoveForPlayerId != viewModel.currentUser.id {
                                if GKStore.shared.games.isEmpty{
                                    if !game.word.isEmpty {
                                        Text("Can you think of a word that \(game.isSuperghost ? "contains" : "starts with") \(game.word)?")
                                        Text("Select a letter so that this still is the case or challenge your opponent")
                                    } else {
                                        Text("Select any Letter you want")
                                    }
                                }
                            }
                            LetterPicker(isSuperghost: game.isSuperghost, word: viewModel.game?.word ?? "")
                            if viewModel.game?.word.count ?? 0 > 1 {
                                AsyncButton{
                                    try await viewModel.challenge()
                                } label: {
                                    Text("There is no such word")
                                }
                                .buttonStyle(AppearanceManager.HapticStlyeCustom(buttonStyle: AppearanceManager.FullWidthButtonStyle(isSecondary: true)))
                            }
                            //MARK: When you are challenged
                        } else if game.challengingUserId != viewModel.currentUser.id{
                            ContentPlaceHolderView("Uhhh, you got challenged!", systemImage: "questionmark.square.dashed", description: "Are you sure you didn't lie?!")
                            Text(game.word)
                                .font(AppearanceManager.wordInGame)
                            SayTheWordButton(isSuperghost: game.isSuperghost)
                            AsyncButton{
                                try await viewModel.yesIlied()
                            } label: {
                                Text("Yes, I lied")
                            }
                            .buttonStyle(AppearanceManager.HapticStlyeCustom(buttonStyle: AppearanceManager.FullWidthButtonStyle(isSecondary: true)))
                            //MARK: When you challenged
                        } else {
                            Text("Waiting for player response...")
                        }
                    }
                    .animation(.smooth, value: game.isBlockingMoveForPlayerOne)
                    .disabled(game.blockMoveForPlayerId == viewModel.currentUser.id)
                    .padding()
                    .animation(.bouncy, value: game)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .navigationTitle(viewModel.gameStatusText == .waitingForPlayer ? "Waiting for Player" : "Game started")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction){
                    Menu{
                        AsyncButton{

                            if let createdAt = viewModel.game?.createdAt, let duration = ISO8601DateFormatter().date(from: createdAt)?.timeIntervalSinceNow.magnitude {
                                Logger.remoteLog(.gameCancelled(duration: Int(duration)))
                            }
                            isPresented = false
                            try await viewModel.quitGame()
                        } label: {
                            Text("Quit Game")
                        }
                        .buttonStyle(.plain)
                    } label: {
                        Button{} label: {
                            Image(systemName: "xmark")
                                .font(AppearanceManager.quitGame)
                        }
                        .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .bordered))
                        .buttonBorderShape(.bcCircle)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.bcCircle)
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
    }
}

#Preview{
    GameView(isPresented: .constant(true))
        .modifier(PreviewModifier())
}
#Preview{
    LetterPicker(isSuperghost: true, word: "word")
        .modifier(PreviewModifier())
}

func isWord(_ word: String) async throws -> Bool {
    if word.count < 4 {return false}
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
    let isSuperghost: Bool
    @State private var isExpanded = false
    @State private var word = ""
    @FocusState var focused : Bool
    var body: some View {
        if isExpanded{
            TextField("What word did you think of?", text: $word)
                .focused($focused)
                .onAppear{
                    focused = true
                }
        }
        AsyncButton {
            if isExpanded {
                if try await isWord(word) && (
                    (GameViewModel.shared.withInvitation || isSuperghost) ? word.localizedCaseInsensitiveContains(GameViewModel.shared.game?.word ?? "") : word.uppercased().hasPrefix((GameViewModel.shared.game?.word ?? "").uppercased())
                ) {
                    try await GameViewModel.shared.submitWordAfterChallenge(word: word)
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


struct FlippingModifier: ViewModifier {
    let isActive : Bool
    @State private var trigger = CGFloat(0)
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(isActive ? .degrees(trigger*360) : .zero, axis: (x: trigger, y: trigger, z: trigger))
            .onAppear{
                if isActive {
                    trigger += 1
                }
            }
            .animation(.bouncy.repeatForever(), value: trigger)
    }
}
