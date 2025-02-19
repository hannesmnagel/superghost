//
//  GameViewModel.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import Combine
import GameKit
import UserNotifications

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

                            UNUserNotificationCenter.current().getNotificationSettings { settings in
                                if settings.authorizationStatus == .notDetermined {
                                    Task{
                                        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                                        await Logger.checkForNotificationStatusChange()
                                    }
                                }
                            }
                            Logger.trackEvent("game_won", with: ["word": newValue.word, "games" : GKStore.shared.games.count])
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
                            Logger.trackEvent("game_lost", with: ["word": newValue.word, "games" : GKStore.shared.games.count])
                        }
                        if (newValue.word.count) > 5 {
                            Task.detached{
                                try? await reportAchievement(.longWord, percent: 100)
                            }
                        }
                        Task.detached {
                            try? await reportAchievement(.leaderboardUnlock, percent: 100)
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
        currentUser = User(id: UUID().uuidString)
    }


    func getTheGame() async throws {
        try await ApiLayer.shared.startGame(as: (id: currentUser.id, profile: PlayerProfileModel.shared.player))

        Logger.userInteraction.info("Started Game")
        Logger.trackEvent("game_start")
        withInvitation = false
    }
    func joinGame(with gameId: String) async throws {
        try await ApiLayer.shared.joinGame(with: gameId, as: (id: currentUser.id, profile: PlayerProfileModel.shared.player))

        withInvitation = true

        Logger.trackEvent("game_join_private")
        Logger.userInteraction.info("Joined Game with ID: \(gameId)")
    }
    func hostGame() async throws {
        try await ApiLayer.shared.hostGame(as: (id: currentUser.id, profile: PlayerProfileModel.shared.player))

        withInvitation = true
        Logger.trackEvent("game_host")
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

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        Logger.trackEvent("game_quit")
        Logger.userInteraction.info("Quit Game")
    }


    func isPlayerOne() -> Bool {
        return (game?.player1Id ?? currentUser.id) == currentUser.id
    }

    func resetGame() async throws {
        guard let game else {
            alertItem = .playerLeft
            return
        }
        alertItem = nil
        if let rematchGameId = game.rematchGameId {
            try await quitGame()
            try await joinGame(with: rematchGameId)
        } else {
            try await ApiLayer.shared.rematchGame(as: (id: currentUser.id, profile: PlayerProfileModel.shared.player))
        }

        Logger.trackEvent("game_rematch")
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

