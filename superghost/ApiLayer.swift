//
//  ApiLayer.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import Foundation
import Combine

protocol BackendCommunicator {
    func startGame(with: String) async throws
    func joinGame(with: String, in: String) async throws
    func hostGame(with: String) async throws
    func updateGame(_ : Game) async throws
    func quitGame() async throws
}

private func backendURL(_ option: RequestType) async -> String {
    "\(option.rawValue)://hannesnagel.com/ghost"
}
enum RequestType:String{case https, wss}
final class ApiLayer: ObservableObject, BackendCommunicator {

    func startGame(with: String) async throws {
        do{
            try await setGameVar(to: findEmptyGame())
            try await joinGame(with: with, in: game?.id ?? "")
        } catch {
            try await setGameVar(to: createGame(userId: with, isPrivate: false))
            connectToWebSocket(gameId: game?.id ?? "")
        }
    }

    func joinGame(with: String, in gameId: String) async throws {
        try await setGameVar(to: joinGame(userId: with, gameId: gameId))
        connectToWebSocket(gameId: gameId)
    }

    func hostGame(with: String) async throws {
        try await setGameVar(to: createGame(userId: with, isPrivate: true))
        connectToWebSocket(gameId: game?.id ?? "")
    }

    func updateGame(_ game: Game) async throws {
        try await setGameVar(to: updateGame(updatedGame: game))
    }

    func quitGame() async throws {
        try await deleteGame(gameId: game?.id ?? "")
        await setGameVar(to: nil)
        disconnectWebSocket()
    }

    static let shared = ApiLayer()
    @Published var game: Game?

    func createGame(userId: String, isPrivate: Bool) async throws -> Game {
        let url = await URL(string: "\(backendURL(.https))/game/create")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let json = Game(id: UUID().uuidString, player1Id: userId, player2Id: isPrivate ? "privateGame" : "", blockMoveForPlayerId: userId, rematchPlayerId: [], moves: [])
        request.httpBody = try JSONEncoder().encode(json)

        let (data, _) = try await URLSession.shared.data(for: request)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }

    func findEmptyGame() async throws -> Game {
        let url = await URL(string: "\(backendURL(.https))/game/findEmptyPlayer2Id")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }

    func joinGame(userId: String, gameId: String) async throws -> Game {
        let url = await URL(string: "\(backendURL(.https))/game/join/\(gameId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONEncoder().encode(userId)

        let (data, _) = try await URLSession.shared.data(for: request)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }

    func getGame(gameId: String) async throws -> Game {
        let url = await URL(string: "\(backendURL(.https))/game/\(gameId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }

    private func deleteGame(gameId: String) async throws {
        let url = await URL(string: "\(backendURL(.https))/game/\(gameId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, _) = try await URLSession.shared.data(for: request)
    }

    func updateGame(updatedGame: Game) async throws -> Game {
        let url = await URL(string: "\(backendURL(.https))/game")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonData = try JSONEncoder().encode(updatedGame)
        request.httpBody = jsonData

        let (data, _) = try await URLSession.shared.data(for: request)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }

    private func setGameVar(to game: Game?) async {
        await MainActor.run {
            self.game = game
        }
    }
    //MARK: WebSocket
#if os(watchOS)
    var subscribedToGameId : String?

    func connectToWebSocket(gameId: String) {
        subscribedToGameId = gameId
        Task{
            do{
                try await receive()
            } catch {
                subscribedToGameId = nil
                Task{[weak self] in
                    await self?.setGameVar(to: nil)
                }
            }
        }
    }
    private func receive() async throws {
        if let subscribedToGameId {
            try await setGameVar(to: self.getGame(gameId: subscribedToGameId))
            try? await Task.sleep(for: .seconds(1))
            try await receive()
        } else {
            await setGameVar(to: nil)
        }
    }
    func disconnectWebSocket() {
        subscribedToGameId = nil
    }

    #else
    var webSocketTask: URLSessionWebSocketTask?

    func connectToWebSocket(gameId: String) {
        Task{
            let urlSession = URLSession(configuration: .default)
            guard let url = await URL(string: "\(backendURL(.wss))/subscribe/game/\(gameId)") else { return }

            webSocketTask = urlSession.webSocketTask(with: url)
            webSocketTask?.delegate = WebSocketDelegateOnClose{[weak self] in
                Task{[weak self] in
                    await self?.setGameVar(to: nil)
                }
            }
            webSocketTask?.resume()
            receiveMessage()
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(.string(let text)):
                print("Received text: \(text)")
                if let data = Data(base64Encoded: text),
                   let updatedGame = try? JSONDecoder().decode(Game.self, from: data) {
                    Task{[weak self] in
                        await self?.setGameVar(to: updatedGame)
                    }
                }
                self?.receiveMessage() // Continue to receive next message
            default:
                print("Error receiving message: \(result)")
                self?.disconnectWebSocket()
            }
        }
    }

    func disconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    class WebSocketDelegateOnClose: NSObject, URLSessionWebSocketDelegate{
        let onClose: ()->Void

        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
        }

        func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
            onClose()
        }
    }
    #endif
}
