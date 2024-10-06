//
//  GameViewModel.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import Combine
import GameKit

enum GameStatusText {
    case waitingForPlayer, started
}
private enum GameStatus {
    case waitingForPlayer, started, lost, won, playerLeft
}

@MainActor
final class GameViewModel: ObservableObject {
    @CloudStorage("score") private var score = 1000

    @Published var game: Game? {
        willSet {
            //check the game status
            if let newValue {
                if newValue.player1Wins != nil{
                    if game?.player1Wins != newValue.player1Wins {
                        if newValue.winningPlayerId == currentUser.id {
                            alertItem = .won

                            let stat = GameStat(
                                player2: isPlayerOne() ? (newValue.player2Id, newValue.player2profile) : (newValue.player1Id, newValue.player1profile),
                                withInvitation: withInvitation,
                                won: true,
                                word: newValue.word,
                                id: UUID().uuidString
                            )
                            try? stat.save()
                            GKStore.shared.games.insert(stat, at: 0)
                            Task{
                                await changeScore(by: .random(in: 48...52))
                            }
                            Logger.remoteLog(
                                .gameWon(
                                    duration:
                                        Int(ISO8601DateFormatter()
                                        .date(from: newValue.createdAt)?.timeIntervalSinceNow.magnitude ?? 0))
                            )
                        } else {
                            alertItem = .lost

                            let stat = GameStat(
                                player2: isPlayerOne() ? (newValue.player2Id, newValue.player2profile) : (newValue.player1Id, newValue.player1profile),
                                withInvitation: withInvitation,
                                won: false,
                                word: newValue.word,
                                id: UUID().uuidString
                            )
                            try? stat.save()
                            GKStore.shared.games.insert(stat, at: 0)
                            Task{
                                await changeScore(by: -.random(in: 48...52))
                            }
                            Logger.remoteLog(
                                .gameLost(
                                    duration:
                                        Int(ISO8601DateFormatter()
                                            .date(from: newValue.createdAt)?.timeIntervalSinceNow.magnitude ?? 0))
                            )
                        }
                        if (newValue.word.count) > 5 {
                            Task.detached{
                                try? await reportAchievement(.longWord, percent: 100)
                            }
                        }
                    }
                } else {
                    newValue.player2Id == "" ? updateGameStatus(.waitingForPlayer) : updateGameStatus(.started)
                }
            } else {
                updateGameStatus(.playerLeft)
            }
        }
    }

    @Published var gameStatusText = GameStatusText.waitingForPlayer
    @Published var currentUser: User
    @Published var alertItem: AlertItem?


    private var cancellables: Set<AnyCancellable> = []

    var withInvitation = false

    static let shared = GameViewModel()
    
    private init() {
        currentUser = User(id: GKLocalPlayer.local.gamePlayerID)
    }


    func getTheGame(isSuperghost: Bool) async throws {
        try await ApiLayer.shared.startGame(isSuperghost: isSuperghost, as: (id: currentUser.id, profile: PlayerProfileModel.shared.player))

        Logger.userInteraction.info("Started Game")
        
        withInvitation = false
        ApiLayer.shared.$game
            .assign(to: \.game, on: self)
            .store(in: &cancellables)
    }
    func joinGame(with gameId: String, isSuperghost: Bool) async throws {
        try await ApiLayer.shared.joinGame(with: gameId, as: (id: currentUser.id, profile: PlayerProfileModel.shared.player))

        withInvitation = true
        ApiLayer.shared.$game
            .assign(to: \.game, on: self)
            .store(in: &cancellables)

        Logger.userInteraction.info("Joined Game with ID: \(gameId)")
        Logger.remoteLog(.joinedPrivateGame)
    }
    func hostGame() async throws {
        try await ApiLayer.shared.hostGame(isSuperghost: true, as: (id: currentUser.id, profile: PlayerProfileModel.shared.player))

        withInvitation = true
        ApiLayer.shared.$game
            .assign(to: \.game, on: self)
            .store(in: &cancellables)
        Logger.userInteraction.info("Hosted Game")
    }
    func submitWordAfterChallenge(word: String) async throws {
        try await ApiLayer.shared.submitWordAfterChallenge(word: word, playerId: currentUser.id)
    }
    func append(letter: String) async throws {
        guard let game else {return}
        let newWord = game.word.appending(letter)
        if try await isWord(newWord) {
            try await ApiLayer.shared.loseWithWord(word: newWord, playerId: currentUser.id)
        } else {
            try await ApiLayer.shared.appendLetter(letter: letter)
        }
    }
    func prepend(letter: String) async throws {
        guard let game else {return}
        let newWord = "\(letter)\(game.word)"
        if try await isWord(newWord) {
            try await ApiLayer.shared.loseWithWord(word: newWord, playerId: currentUser.id)
        } else {
            try await ApiLayer.shared.prependLetter(letter: letter)
        }
    }

    func quitGame() async throws {
        try await ApiLayer.shared.quitGame()
        Logger.userInteraction.info("Quit Game")
    }


    func isPlayerOne() -> Bool {
        return game != nil ? game!.player1Id == currentUser.id : false
    }

    func resetGame() async throws {
        guard let game else {
            alertItem = .playerLeft
            return
        }
        alertItem = nil
        if let rematchGameId = game.rematchGameId {
            try await quitGame()
            try await joinGame(with: rematchGameId, isSuperghost: game.isSuperghost)
        } else {
            try await ApiLayer.shared.rematchGame(isSuperghost: game.isSuperghost, as: (id: currentUser.id, profile: PlayerProfileModel.shared.player))
        }

        Logger.userInteraction.info("rematching")
    }
    func challenge() async throws {
        try await ApiLayer.shared.challenge(playerId: currentUser.id)
    }
    func yesIlied() async throws {
        try await ApiLayer.shared.yesILiedAfterChallenge(playerId: currentUser.id)
    }

    @MainActor
    private func updateGameStatus(_ state: GameStatus?) {
        switch state{
        case .waitingForPlayer:
            gameStatusText = .waitingForPlayer
            alertItem = nil
        case .started:
            gameStatusText = .started
            alertItem = nil
        case .lost:
            alertItem = .lost
        case .won:
            alertItem = .won
        case .playerLeft:
            alertItem = .playerLeft
        case .none:
            alertItem = nil
        }
    }
}

