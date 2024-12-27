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
                /*
                 //MARK: Private Game Share Link Screen
                 if (viewModel.game?.player2Id ?? "").isEmpty || viewModel.game?.player2Id == "privateGame" {

                 Image(PlayerProfileModel.shared.player.image ?? Skin.cowboy.image)
                 .resizable()
                 .scaledToFit()
                 .clipShape(.circle)
                 .frame(maxWidth: 300)
                 .matchedGeometryEffect(id: "pp", in: namespace)
                 .modifier(FlippingModifier(isActive: true))

                 if viewModel.game?.player2Id == "privateGame"{
                 if let url = URL(string: "https://hannesnagel.com/api/v2/superghost/private/\(viewModel.game?.id ?? "")"){
                 Text("Send Invitation Link")
                 ShareLink(item: url)
                 .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
                 }
                 }
                 //MARK: Playing:
                 }
                 */

                if let game = viewModel.game{
                    VStack {
                        AppearingAnimationView(after: 7){trigger in

                            let profile = (game.player2Id.isEmpty || game.player2Id == "privateGame") ? nil : viewModel.isPlayerOne() ? game.player2profile : game.player1profile
                            Group {
                                if let profile {
                                    Image(profile.image ?? Skin.cowboy.image)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    Image(systemName: "questionmark")
                                        .font(.largeTitle)
                                        .imageScale(.large)
                                        .padding()
                                        .modifier(FlippingModifier(isActive: true))
                                }
                            }
                            .onChange(of: profile == nil) { _, _ in
                                Task{try? await SoundManager.shared.play(.gameStart, loop: false)}
                            }
                            .clipShape(.circle)
                            .padding(5)
                            .overlay(Circle().stroke(.red, lineWidth: 5))
                            .frame(maxWidth: (trigger ? (game.isBlockingMoveForPlayerOne == viewModel.isPlayerOne() ? 1 : 0.5) : 1)*200)
                            Text(profile?.name ?? "")
                                .font((trigger ? (game.isBlockingMoveForPlayerOne == viewModel.isPlayerOne() ? .title.bold() : .caption.bold()) : .title.bold()))

                            if let profile,
                               game.isBlockingMoveForPlayerOne == viewModel.isPlayerOne() || !trigger{
                                if let rank = profile.rank, rank > 0 {
                                    Text("Rank \(rank.formatted())")
                                } else {
                                    Text("Not ranked")
                                }
                            }

                            if (game.player2Id.isEmpty || game.player2Id != "privateGame") || trigger {
                                Spacer()
                            }

                            VStack{
                                let profile = PlayerProfileModel.shared.player
                                Image(profile.image ?? Skin.cowboy.image)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(.circle)
                                    .padding(5)
                                    .overlay(Circle().stroke(.blue, lineWidth: 5))
                                    .frame(maxWidth: (trigger ? (game.isBlockingMoveForPlayerOne == viewModel.isPlayerOne() ? 0.5 : 1) : 1) * 200)
                                    .matchedGeometryEffect(id: "pp", in: namespace)
                                Text(profile.name)
                                    .font((trigger ? (game.isBlockingMoveForPlayerOne == viewModel.isPlayerOne() ? .caption.bold() : .title.bold()) : .title.bold()))
                                if !(game.player2Id.isEmpty || game.player2Id != "privateGame"),
                                    game.isBlockingMoveForPlayerOne != viewModel.isPlayerOne() || !trigger {
                                    if let rank = profile.rank, rank > 0 {
                                        Text("Rank \(rank.formatted())")
                                    } else {
                                        Text("Not ranked")
                                    }
                                }
                            }
                        }
                        Spacer()
                        VStack{
                            if game.blockMoveForPlayerId == viewModel.currentUser.id {
                                TimelineView(.periodic(from: .now, by: 1)){_ in
                                    if game.lastMoveAt.timeIntervalSinceNow.magnitude > 15 {
                                        Group{
                                            Text("Timeout in ") + Text(game.lastMoveAt.addingTimeInterval(45), style: .timer)
                                        }
                                        .monospacedDigit()
                                        .task{
                                            try? await Task.sleep(for: .seconds(game.lastMoveAt.addingTimeInterval(45).timeIntervalSinceNow))
                                            if game.blockMoveForPlayerId == viewModel.currentUser.id {
                                                try? await viewModel.submitWordAfterChallenge(word: game.word)
                                            }
                                        }
                                        .transition(.scale.animation(.smooth))
                                    }
                                }
                            }
                            if game.player1Challenges == nil {
                                if game.blockMoveForPlayerId != viewModel.currentUser.id {
                                    if GKStore.shared.games.count < 4 {
                                        if !game.word.isEmpty {
                                            Text("Can you think of a word that \(game.isSuperghost ? "contains" : "starts with") \(game.word)?")
                                                Text("Select a letter so the sequence can still become that word or challenge your opponent")
                                            if game.word.count > 2 {
                                                Text("Careful if it is a word you will loose")
                                            }
                                        } else {
                                            Text("Select any Letter you want")
                                        }
                                    }
                                }
                                AppearingAnimationView(after: 7){trigger in
                                    if game.player2Id == "privateGame" {
                                        if let url = URL(string: "https://superghost.hannesnagel.com/v3/private/\(viewModel.game?.id ?? "")") {
                                            Text("Send Invitation Link")
                                            ShareLink(item: url)
                                                .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))

                                        }
                                    } else
                                    if trigger {
                                        LetterPicker(isSuperghost: game.isSuperghost, word: viewModel.game?.word ?? "")
                                            .transition(.scale(scale: 0.01, anchor: .bottom).animation(.easeIn))
                                            .disabled(game.blockMoveForPlayerId == viewModel.currentUser.id)
                                    } else if !game.player2Id.isEmpty{
                                        Text("Let's go!")
                                            .font(.largeTitle.bold())
                                            .padding(.top)
                                            .transition(.scale)
                                    }
                                }
                                if game.word.count > 1 {
                                    AsyncButton{
                                        try await viewModel.challenge()
                                    } label: {
                                        Text("There is no such word")
                                    }
                                    .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: true))
                                    .disabled(viewModel.game?.blockMoveForPlayerId == viewModel.currentUser.id)
                                }
                                //MARK: When you are challenged
                            } else if game.challengingUserId != viewModel.currentUser.id{
                                ContentPlaceHolderView(
                                    "Uhhh, you got challenged!",
                                    systemImage: "questionmark.square.dashed",
                                    description: "Are you sure you didn't lie?!"
                                )
                                Text(game.word)
                                    .font(AppearanceManager.wordInGame)
                                SayTheWordButton(isSuperghost: game.isSuperghost)
                                    .disabled(game.blockMoveForPlayerId == viewModel.currentUser.id)
                                AsyncButton{
                                    try await viewModel.yesIlied()
                                } label: {
                                    Text("Yes, I lied")
                                }
                                .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: true))
                                .disabled(game.blockMoveForPlayerId == viewModel.currentUser.id)
                                //MARK: When you challenged
                            } else {
                                Text("Waiting for player response...")
                            }
                        }
                    }
                    Spacer()
                }
            }
            .animation(.smooth, value: viewModel.game?.isBlockingMoveForPlayerOne)
            .animation(.bouncy, value: viewModel.game)
            .frame(maxWidth: .infinity)
            .navigationTitle(viewModel.gameStatusText == .waitingForPlayer ? "Waiting for Player" : "Game started")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction){
                    Menu{
                        AsyncButton{
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
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.bcCircle)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.bcCircle)
                    .keyboardShortcut(.cancelAction)
                }
            }
            .background(PlayerProfileModel.shared.player.color.gradient, ignoresSafeAreaEdges: .all)
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
    let text: String?
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
