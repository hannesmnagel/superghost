//
//  GameViewModel.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import Combine

public struct GameStat: RawRepresentable, Hashable, Identifiable {
    let player2: String
    let won: Bool
    let word: String
    public var id = UUID()

    init(player2: String, won: Bool, word: String) {
        self.player2 = player2
        self.won = won
        self.word = word
    }
    public var rawValue: String {
        // Encode the properties as a JSON string
        let dict: [String: Any] = ["player2": player2, "won": won, "word": word]
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return ""
    }

    public init?(rawValue: String) {
        // Decode the JSON string back into properties
        if let jsonData = rawValue.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
           let player2 = dict["player2"] as? String,
           let won = dict["won"] as? Bool,
           let word = dict["word"] as? String {
            self.player2 = player2
            self.won = won
            self.word = word
        } else {
            return nil
        }
    }
}

extension Array: RawRepresentable where Element == GameStat {
    public var rawValue: String {
        (try? JSONEncoder().encode(self.map({$0.rawValue})).base64EncodedString()) ?? ""
    }

    public init?(rawValue: String) {
        if let data = Data(base64Encoded: rawValue),
           let decoded = try? JSONDecoder().decode([String].self, from: data){
            self = decoded.compactMap({.init(rawValue: $0)})
        } else {return nil}
    }
}


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

    init() {
        retriveUser()
        if currentUser == nil {
            saveUser()
        }
    }


    func getTheGame() async throws {
        try await ApiLayer.shared.startGame(with: currentUser.id)

        ApiLayer.shared.$game
            .assign(to: \.game, on: self)
            .store(in: &cancellables)
    }
    func joinGame(with gameId: String) async throws {
        try await ApiLayer.shared.joinGame(with: currentUser.id, in: gameId)

        ApiLayer.shared.$game
            .assign(to: \.game, on: self)
            .store(in: &cancellables)
    }
    func hostGame() async throws {
        try await ApiLayer.shared.hostGame(with: currentUser.id)

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

    func checkIfGameIsOver() {

        guard game != nil else {
            alertItem = nil
            return
        }

        if game!.winningPlayerId != "" {

            if game!.winningPlayerId == currentUser.id {
                alertItem = .youWin
            } else {
                alertItem = .youLost
            }
        }
    }

    func resetGame() async throws {
        guard game != nil else {
            alertItem = .quit
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
            print("encoding user object")
            let data = try JSONEncoder().encode(currentUser)
            userData = data
        } catch {
            print("couldnt same user object")
        }

    }

    func retriveUser() {

        guard let userData = userData else { return }

        do {
            print("decoding user")
            currentUser = try JSONDecoder().decode(User.self, from: userData)
        } catch {
            print("no user saved")
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

