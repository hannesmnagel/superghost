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

private let backendURL = "http://127.0.0.1:8080"  // Default backend URL
private let socketBaseURL = "ws://127.0.0.1:8080"
final class ApiLayer: ObservableObject, BackendCommunicator {

    func startGame(with: String) async throws {
        do{
            self.game = try await findEmptyGame()
            try await joinGame(with: with, in: game?.id ?? "")
        } catch {
            self.game = try await createGame(userId: with, isPrivate: false)
            connectToWebSocket(gameId: game?.id ?? "")
        }
    }
    
    func joinGame(with: String, in gameId: String) async throws {
        self.game = try await joinGame(userId: with, gameId: gameId)
        connectToWebSocket(gameId: gameId)
    }
    
    func hostGame(with: String) async throws {
        self.game = try await createGame(userId: with, isPrivate: true)
        connectToWebSocket(gameId: game?.id ?? "")
    }
    
    func updateGame(_ game: Game) async throws {
        self.game = try await updateGame(updatedGame: game)
    }
    
    func quitGame() async throws {
        try await deleteGame(gameId: game?.id ?? "")
        self.game = nil
        disconnectWebSocket()
    }
    
    static let shared = ApiLayer()
    @Published var game: Game?
    var subscribedToGameId : String?
    var webSocketTask: URLSessionWebSocketTask?
}


private extension ApiLayer{

    func createGame(userId: String, isPrivate: Bool) async throws -> Game {
        let url = URL(string: "\(backendURL)/game/create")!
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
        let url = URL(string: "\(backendURL)/game/findEmptyPlayer2Id")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }

    func joinGame(userId: String, gameId: String) async throws -> Game {
        let url = URL(string: "\(backendURL)/game/join/\(gameId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONEncoder().encode(userId)

        let (data, _) = try await URLSession.shared.data(for: request)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }

    func getGame(gameId: String) async throws -> Game {
        let url = URL(string: "\(backendURL)/game/\(gameId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }

    private func deleteGame(gameId: String) async throws {
        let url = URL(string: "\(backendURL)/game/\(gameId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, _) = try await URLSession.shared.data(for: request)
    }

    func updateGame(updatedGame: Game) async throws -> Game {
        let url = URL(string: "\(backendURL)/game")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonData = try JSONEncoder().encode(updatedGame)
        request.httpBody = jsonData

        let (data, _) = try await URLSession.shared.data(for: request)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }
//MARK: WebSocket
    func connectToWebSocket(gameId: String) {
        let urlSession = URLSession(configuration: .default)
        guard let url = URL(string: "\(socketBaseURL)/subscribe/game/\(gameId)") else { return }

        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(.string(let text)):
                print("Received text: \(text)")
                if let data = Data(base64Encoded: text),
                   let updatedGame = try? JSONDecoder().decode(Game.self, from: data) {
                    self?.game = updatedGame
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
}
