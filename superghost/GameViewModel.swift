//
//  GameViewModel.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import Combine
import SwiftData


@MainActor
final class GameViewModel: ObservableObject {

    @AppStorage("user") private var userData: Data?

    @Published var game: Game? {
        didSet {
            checkIfGameIsOver()
            //check the game status

            if game == nil { updateGameNotificationFor(.finished) } else {
                game?.player2Id == "" ? updateGameNotificationFor(.waitingForPlayer) : updateGameNotificationFor(.started)
            }
        }
    }

    @Published var gameNotification = GameNotification.waitingForPlayer
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
        try await ApiLayer.shared.joinGame(with: currentUser.id, in: gameId)

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
            print("is word....")
            game?.winningPlayerId = isPlayerOne() ? game!.player2Id : game!.player1Id
        }

        try await ApiLayer.shared.updateGame(game!)
    }

    func quitGame() async throws {
        try await ApiLayer.shared.quitGame()
        alertItem = nil
    }

    func checkForGameBoardStatus() -> Bool {
        return game != nil ? game!.blockMoveForPlayerId == currentUser.id : false
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

        try await ApiLayer.shared.updateGame(game!)
    }


    func updateGameNotificationFor(_ state: GameNotification) {
        gameNotification = state
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


struct Move: Codable, Equatable {

    let isPlayer1: Bool
    let word: String
}


struct Game: Codable, Equatable {
    let id: String
    var player1Id: String
    var player2Id: String

    var blockMoveForPlayerId: String
    var winningPlayerId: String = ""
    var challengingUserId: String = ""
    var rematchPlayerId: [String]

    var moves: [Move]

    var createdAt : String = Date().ISO8601Format()
}

struct User: Codable {
    var id = UUID().uuidString
}


