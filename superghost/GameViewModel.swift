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
    @AppStorage("user") private var userData: Data?

    @Published var game: Game? {
        willSet {
            checkIfGameIsOver()
            //check the game status

            if newValue == nil { updateGameStatus(.playerLeft) } else {
                newValue?.player2Id == "" ? updateGameStatus(.waitingForPlayer) : updateGameStatus(.started)
            }
        }
    }

    @Published var gameStatusText = GameStatusText.waitingForPlayer
    @Published var currentUser: User!
    @Published var alertItem: AlertItem?


    private var cancellables: Set<AnyCancellable> = []

    var withInvitation = false

    init() {
        retriveUser()
        if currentUser == nil {
            saveUser()
        }
    }


    func getTheGame() async throws {
        try await ApiLayer.shared.startGame(with: currentUser.id)

        withInvitation = false
        ApiLayer.shared.$game
            .assign(to: \.game, on: self)
            .store(in: &cancellables)
    }
    func joinGame(with gameId: String) async throws {
        try await ApiLayer.shared.joinGame(with: currentUser.id, in: gameId, isPrivate: true)

        withInvitation = true
        ApiLayer.shared.$game
            .assign(to: \.game, on: self)
            .store(in: &cancellables)
    }
    func hostGame() async throws {
        try await ApiLayer.shared.hostGame(with: currentUser.id)

        withInvitation = true
        ApiLayer.shared.$game
            .assign(to: \.game, on: self)
            .store(in: &cancellables)
    }

    func processPlayerMove(for letter: String) async throws {

        guard game != nil else { return }
        game!.moves.append(Move(isPlayer1: isPlayerOne(), word: letter))

        game!.blockMoveForPlayerId = currentUser.id

        if try await isWord(letter){
            game?.winningPlayerId = isPlayerOne() ? game!.player2Id : game!.player1Id
            updateGameStatus(.lost)
        }

        try await ApiLayer.shared.updateGame(game!, isPrivate: withInvitation)
    }

    func quitGame() async throws {
        try await ApiLayer.shared.quitGame(isPrivate: withInvitation)
        alertItem = nil
    }


    func isPlayerOne() -> Bool {
        return game != nil ? game!.player1Id == currentUser.id : false
    }

    @MainActor
    func checkIfGameIsOver() {

        guard game != nil else {
            alertItem = nil
            return
        }

        if game!.winningPlayerId != "" {

            if game!.winningPlayerId == currentUser.id {
                alertItem = .won
            } else {
                alertItem = .lost
            }
        }
    }

    func resetGame() async throws {
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

        try await ApiLayer.shared.updateGame(game!, isPrivate: withInvitation)
    }


    private func updateGameStatus(_ state: GameStatus) {
        switch state{
        case .waitingForPlayer:
            gameStatusText = .waitingForPlayer
        case .started:
            gameStatusText = .started
        case .lost:
            alertItem = .lost
        case .won:
            alertItem = .won
        case .playerLeft:
            alertItem = .playerLeft
        }
    }

    //MARK: - User object
    func saveUser() {
        currentUser = User()
        do {
            let data = try JSONEncoder().encode(currentUser)
            userData = data
        } catch {
        }

    }

    func retriveUser() {

        guard let userData = userData else { return }

        do {
            currentUser = try JSONDecoder().decode(User.self, from: userData)
        } catch {
        }
    }
}

