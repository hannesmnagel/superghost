//
//  GameViewModel.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import Combine
import SwiftData

enum GameStatusText {
    case waitingForPlayer, started
}
private enum GameStatus {
    case waitingForPlayer, started, lost, won, playerLeft
}

@MainActor
final class GameViewModel: ObservableObject {

    @Published var showPaywall = false
    @CloudStorage("userData") private var userData: User = User()

    @Published var game: Game? {
        willSet {
            //check the game status
            if let newValue {
                if newValue.winningPlayerId != "" {

                    if newValue.winningPlayerId == currentUser.id {
                        alertItem = .won
                    } else {
                        alertItem = .lost
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
    @Published var currentUser: User!
    @Published var alertItem: AlertItem?


    private var cancellables: Set<AnyCancellable> = []

    var withInvitation = false

    init() {
        userData = userData
        currentUser = userData
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
            updateGameStatus(.lost)
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

