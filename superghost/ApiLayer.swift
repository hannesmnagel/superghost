//
//  ApiLayer.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import Combine
import StoreKit



typealias Player = (id: String, profile: PlayerProfile)


@globalActor
actor ApiLayerActor: GlobalActor {
    static let shared = ApiLayerActor()
}

@ApiLayerActor
final class ApiLayer: ObservableObject {

    func startGame(as player: Player) async throws {
        do{
            let id = try await ApiCaller.openGame()
            await setGameVar(to: .init(id: id, player2Id: player.id, player2profile: player.profile))
            try await joinGame(with: id, as: player)
        } catch {
            let id = try await ApiCaller.createGame(player1Id: player.id, player1Profile: player.profile, isPrivate: false)
            await setGameVar(to: .init(id: id, player1Id: player.id, player1profile: player.profile))
            await connectToWebSocket(gameId: id)
        }
    }


    func joinGame(with gameId: String, as player: Player) async throws {
        await setGameVar(to: .init(id: gameId, player2Id: player.id, player2profile: player.profile))
        await connectToWebSocket(gameId: gameId)
        
        try await ApiCaller.joinGame(gameId: gameId, playerId: player.id, playerProfile: player.profile)
    }

    func hostGame(as player: Player) async throws {
        let gameId = try await ApiCaller.createGame(player1Id: player.id, player1Profile: player.profile, isPrivate: true)
        await setGameVar(to: .init(id: gameId, player1Id: player.id, player1profile: player.profile, player2Id: "privateGame"))
        await connectToWebSocket(gameId: gameId)
    }

    func rematchGame(as player: Player) async throws {
        let oldGameId = await GameViewModel.shared.game?.id ?? ""
        disconnectWebSocket()
        let id = try await ApiCaller.createGame(player1Id: player.id, player1Profile: player.profile, isPrivate: true)
        await setGameVar(to: .init(id: id, player1Id: player.id, player1profile: player.profile))
        await connectToWebSocket(gameId: id)
        
        try await ApiCaller.rematchGame(oldGameId: oldGameId, newGameId: id)
    }

    func appendLetter(letter: String) async throws {
        guard let gameId = await GameViewModel.shared.game?.id else { return }
        try await ApiCaller.appendLetter(letter: letter, gameId: gameId)
    }
    func prependLetter(letter: String) async throws {
        guard let gameId = await GameViewModel.shared.game?.id else { return }
        try await ApiCaller.prependLetter(letter: letter, gameId: gameId)
    }

    func loseWithWord(word: String, playerId: String) async throws {
        guard let gameId = await GameViewModel.shared.game?.id else { return }
        try await ApiCaller.loseWithWord(word: word, playerId: playerId, gameId: gameId)
    }

    func challenge(playerId: String) async throws {
        guard let gameId = await GameViewModel.shared.game?.id else { return }
        try await ApiCaller.challenge(playerId: playerId, gameId: gameId)
    }

    func submitWordAfterChallenge(word: String, playerId: String) async throws {
        guard let gameId = await GameViewModel.shared.game?.id else { return }
        try await ApiCaller.submitWordAfterChallenge(playerId: playerId, word: word, gameId: gameId)
    }

    func yesILiedAfterChallenge(playerId: String) async throws {
        guard let gameId = await GameViewModel.shared.game?.id else { return }
        try await ApiCaller.yesILiedAfterChallenge(playerId: playerId, gameId: gameId)
    }

    func quitGame() async throws {
        guard let gameId = await GameViewModel.shared.game?.id else { return }
        try await ApiCaller.deleteGame(gameId: gameId)
        await setGameVar(to: nil)
        disconnectWebSocket()
    }

    static let shared = ApiLayer()

    @MainActor
    private func setGameVar(to game: Game?) async {
        GameViewModel.shared.game = game
    }

    //MARK: WebSocket
    private var webSocketTask: (URLSessionWebSocketTask)?

    private func connectToWebSocket(gameId: String) async {
            let urlSession = URLSession(configuration: .default)
        let url = URL(string: "wss://superghost.hannesnagel.com/v3/game/subscribe/\(gameId)")!

            webSocketTask = urlSession.webSocketTask(with: url)
            await withCheckedContinuation{con in
                webSocketTask?.delegate = WebSocketDelegateOnClose{
                    con.resume()
                } onClose: {[weak self] in
                    Task{[weak self] in
                        await self?.setGameVar(to: nil)
                    }
                }
                webSocketTask?.resume()
            }
            receiveMessage(for: gameId)
        
        Task{
            while let webSocketTask{
                webSocketTask.sendPing{ error in
                    if let error{
                        print("Error receiving pong: \(error)")
                    } else {print("received pong")}
                }
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }
    nonisolated private func updateGame(with updatedGame: GameMove) {
        Task{@MainActor in
            if var game = GameViewModel.shared.game {
                game.player1Id = updatedGame.player1Id ?? game.player1Id
                game.player2Id = updatedGame.player2Id ?? game.player2Id
                game.player1profile = updatedGame.player1Profile ?? game.player1profile
                game.player2profile = updatedGame.player2Profile ?? game.player2profile
                game.isBlockingMoveForPlayerOne = updatedGame.isBlockingMoveForPlayerOne
                game.player1Challenges = updatedGame.player1Challenges ?? game.player1Challenges
                game.player1Wins = updatedGame.player1Wins ?? game.player1Wins
                game.rematchGameId = updatedGame.rematchGameId ?? game.rematchGameId
                game.word = updatedGame.word ?? game.word
                game.lastMoveAt = .now
                GameViewModel.shared.game = game
            }
        }
    }
    private func receiveMessage(for gameId: String) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(.string(let text)):
                print("Received text: \(text)")
                if let data = Data(base64Encoded: text),
                   let updatedGame = try? JSONDecoder().decode(GameMove.self, from: data) {
                    self?.updateGame(with: updatedGame)
                }
                Task{@ApiLayerActor in
                    self?.receiveMessage(for: gameId) // Continue to receive next message
                }
            default:
                print("Error receiving message: \(result)")
                Task{[weak self] in
                    await self?.setGameVar(to: nil)
                }
                Task{@ApiLayerActor in
                    self?.disconnectWebSocket()
                }
            }
        }
    }

    private func disconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    private final class WebSocketDelegateOnClose: NSObject, URLSessionWebSocketDelegate{
        let onClose: @Sendable ()->Void
        let onOpen: @Sendable ()->Void

        init(onOpen: @escaping @Sendable () -> Void, onClose: @escaping @Sendable () -> Void) {
            self.onClose = onClose
            self.onOpen = onOpen
        }
        func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
            onOpen()
        }
        func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
            onClose()
        }
    }
}


private enum ApiCaller {
    enum APIError: Error {
        case requestFailed
    }
    static let baseURL = "https://superghost.hannesnagel.com/v3"

    // MARK: - Create Game
    struct CreateGameRequest: Codable {
        let player1Id: String
        let player1profile: PlayerProfile
        let isPrivate: Bool
        var isSuperghost: Bool = true
    }

    static func createGame(player1Id: String, player1Profile: PlayerProfile, isPrivate: Bool) async throws -> String {
        let url = URL(string: "\(baseURL)/game/create")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let createGameRequest = CreateGameRequest(player1Id: player1Id, player1profile: player1Profile, isPrivate: isPrivate)
        request.httpBody = try JSONEncoder().encode(createGameRequest)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let gameId = String(data: data, encoding: .utf8) else {
            throw APIError.requestFailed
        }

        return gameId
    }

    // MARK: - Open Game
    static func openGame() async throws -> String {
        let url = URL(string: "\(baseURL)/game/open")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpBody = try JSONEncoder().encode(true)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let gameId = String(data: data, encoding: .utf8) else {
            throw APIError.requestFailed
        }

        return gameId
    }

    // MARK: - Join Game
    struct JoinGameRequest: Codable {
        let gameId: String
        let playerId: String
        let playerProfile: PlayerProfile
    }

    static func joinGame(gameId: String, playerId: String, playerProfile: PlayerProfile) async throws {
        let url = URL(string: "\(baseURL)/game/join")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let joinGameRequest = JoinGameRequest(gameId: gameId, playerId: playerId, playerProfile: playerProfile)
        request.httpBody = try JSONEncoder().encode(joinGameRequest)

        _ = try await URLSession.shared.data(for: request)
    }

    // MARK: - Append Letter
    struct AppendRequest: Codable {
        let letter: String
        let gameId: String
    }

    static func appendLetter(letter: String, gameId: String) async throws {
        try await requestUpdate(route: "append", params: AppendRequest(letter: letter, gameId: gameId))
    }

    // MARK: - Prepend Letter
    struct PrependRequest: Codable {
        let letter: String
        let gameId: String
    }

    static func prependLetter(letter: String, gameId: String) async throws {
        try await requestUpdate(route: "prepend", params: PrependRequest(letter: letter, gameId: gameId))
    }

    // MARK: - Lose With Word
    struct LooseWithWordRequest: Codable {
        let word: String
        let playerId: String
        let gameId: String
    }

    static func loseWithWord(word: String, playerId: String, gameId: String) async throws {
        try await requestUpdate(route: "looseWithWord", params: LooseWithWordRequest(word: word, playerId: playerId, gameId: gameId))
    }

    // MARK: - Challenge
    struct ChallengeRequest: Codable {
        let playerId: String
        let gameId: String
    }

    static func challenge(playerId: String, gameId: String) async throws {
        try await requestUpdate(route: "challenge", params: ChallengeRequest(playerId: playerId, gameId: gameId))
    }

    // MARK: - Submit Word After Challenge
    struct WordSubmitRequest: Codable {
        let playerId: String
        let word: String
        let gameId: String
    }

    static func submitWordAfterChallenge(playerId: String, word: String, gameId: String) async throws {
        try await requestUpdate(route: "submitWordAfterChallenge", params: WordSubmitRequest(playerId: playerId, word: word, gameId: gameId))
    }

    // MARK: - Yes I Lied After Challenge
    struct YesILiedRequest: Codable {
        let playerId: String
        let gameId: String
    }
    static func yesILiedAfterChallenge(playerId: String, gameId: String) async throws {
        try await requestUpdate(route: "yesIliedAfterChallenge", params: YesILiedRequest(playerId: playerId, gameId: gameId))
    }

    // MARK: - rematch
    struct RematchRequest: Codable {
        let oldGameId: String
        let newGameId: String
    }

    static func rematchGame(oldGameId: String, newGameId: String) async throws {
        try await requestUpdate(route: "rematchGame", params: RematchRequest(oldGameId: oldGameId, newGameId: newGameId))
    }

    // MARK: - Delete Game
    static func deleteGame(gameId: String) async throws {
        let url = URL(string: "\(baseURL)/game")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(gameId)

        _ = try await URLSession.shared.data(for: request)
    }

    // Helper for PUT requests
    static private func requestUpdate<T: Codable>(route: String, params: T) async throws {
        let url = URL(string: "\(baseURL)/game/\(route)")!

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(params)

        let (_, _) = try await URLSession.shared.data(for: request)
    }
}

struct GameMove: Codable {
    var word: String?

    var player1Id: String?
    var player1Profile: PlayerProfile?

    var player2Id: String?
    var player2Profile: PlayerProfile?

    var isBlockingMoveForPlayerOne : Bool

    var player1Wins = Bool?.none

    var player1Challenges = Bool?.none

    var rematchGameId = String?.none
}
