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
    @Published var games = [GameStat]()

    @Published var showPaywall = false

    @Published var game: Game? {
        willSet {
            //check the game status
            if let newValue {
                if newValue.winningPlayerId != "" {
                    if game?.winningPlayerId != newValue.winningPlayerId {
                        if newValue.winningPlayerId == currentUser.id {
                            alertItem = .won

                            let stat = GameStat(
                                player2: isPlayerOne() ? newValue.player2Id : newValue.player1Id,
                                withInvitation: withInvitation,
                                won: true,
                                word: newValue.moves.last?.word.uppercased() ?? "",
                                id: newValue.id
                            )
                            try? stat.save()
                            games.insert(stat, at: 0)
                            try? SoundManager.shared.play(.laughingGhost, loop: false)
                        } else {
                            alertItem = .lost

                            let stat = GameStat(
                                player2: isPlayerOne() ? newValue.player2Id : newValue.player1Id,
                                withInvitation: withInvitation,
                                won: false,
                                word: newValue.moves.last?.word.uppercased() ?? "",
                                id: newValue.id
                            )
                            try? stat.save()
                            games.insert(stat, at: 0)
                            try? SoundManager.shared.play(.scream, loop: false)
                        }
                        if (newValue.moves.last?.word.count ?? 0) > 5 {
                            let achievement = GKAchievement(identifier: "word.long")
                            achievement.percentComplete += 100
                            GKAchievement.report([achievement])
                            showMessage("You earned an Achievement!\nLook at it in the Game Center Dashboard")
                        }
                    }
                } else {
                    if newValue.rematchPlayerId.count != 1 {
                        newValue.player2Id == "" ? updateGameStatus(.waitingForPlayer) : updateGameStatus(.started)
                    }
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

    init() {
        GKLocalPlayer.local.authenticateHandler = {vc, error in
            if let error{
                print(error)
            }
        }
        currentUser = User(id: GKLocalPlayer.local.gamePlayerID)
        Task{
            games = ((try? await GameStat.loadAll()) ?? []).sorted{$0.createdAt > $1.createdAt}
        }
    }


    func getTheGame(isSuperghost: Bool) async throws {
        try await ApiLayer.shared.startGame(with: currentUser.id, isSuperghost: isSuperghost)

        withInvitation = false
        ApiLayer.shared.$game
            .assign(to: \.game, on: self)
            .store(in: &cancellables)
    }
    func joinGame(with gameId: String, isSuperghost: Bool) async throws {
        try await ApiLayer.shared.joinGame(with: currentUser.id, in: gameId, isPrivate: true, isSuperghost: isSuperghost)

        withInvitation = true
        ApiLayer.shared.$game
            .assign(to: \.game, on: self)
            .store(in: &cancellables)
    }
    func hostGame() async throws {
        try await ApiLayer.shared.hostGame(with: currentUser.id, isSuperghost: true)

        withInvitation = true
        ApiLayer.shared.$game
            .assign(to: \.game, on: self)
            .store(in: &cancellables)
    }

    func processPlayerMove(for letter: String, isSuperghost: Bool) async throws {

        guard game != nil else { return }
        game!.moves.append(Move(isPlayer1: isPlayerOne(), word: letter))

        game!.blockMoveForPlayerId = currentUser.id

        if try await isWord(letter){
            game?.winningPlayerId = isPlayerOne() ? game!.player2Id : game!.player1Id
        }

        try await ApiLayer.shared.updateGame(game!, isPrivate: withInvitation, isSuperghost: isSuperghost)
    }

    func quitGame(isSuperghost: Bool) async throws {
        try await ApiLayer.shared.quitGame(isPrivate: withInvitation, isSuperghost: isSuperghost)
    }


    func isPlayerOne() -> Bool {
        return game != nil ? game!.player1Id == currentUser.id : false
    }

    func resetGame(isSuperghost: Bool) async throws {
        guard game != nil else {
            alertItem = .playerLeft
            return
        }
        if game!.rematchPlayerId.count == 1 {
            //start new game
            game!.moves = []
            game!.winningPlayerId = ""
            game!.blockMoveForPlayerId = game!.player2Id
            game!.challengingUserId = ""
            game!.createdAt = Date().ISO8601Format()

        } else if game!.rematchPlayerId.count == 2 {
            game!.rematchPlayerId = []
        }

        game!.rematchPlayerId.append(currentUser.id)
        alertItem = nil

        try await ApiLayer.shared.updateGame(game!, isPrivate: withInvitation, isSuperghost: isSuperghost)
    }


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

