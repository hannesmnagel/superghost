//
//  ApiLayer.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import Foundation
import Combine
import RevenueCat


private func backendURL(_ option: RequestType, isSuperghost: Bool) async -> String {
    "\(option.rawValue)://hannesnagel.com/\(isSuperghost ? "superghost" : "ghost")"
}
enum RequestType:String{case https, wss}
final class ApiLayer: ObservableObject {

    func startGame(with: String, isSuperghost: Bool) async throws {
        do{
            try await setGameVar(to: findEmptyGame(isSuperghost: isSuperghost))
            try await joinGame(with: with, in: game?.id ?? "", isPrivate: false, isSuperghost: isSuperghost)
        } catch {
            try await setGameVar(to: createGame(userId: with, isPrivate: false, isSuperghost: isSuperghost))
            connectToWebSocket(gameId: game?.id ?? "", isPrivate: false, isSuperghost: isSuperghost)
        }
    }

    func joinGame(with: String, in gameId: String, isPrivate: Bool, isSuperghost: Bool) async throws {
        try await setGameVar(to: joinGame(userId: with, gameId: gameId, isPrivate: isPrivate, isSuperghost: isSuperghost))
        connectToWebSocket(gameId: gameId, isPrivate: isPrivate, isSuperghost: isSuperghost)
    }

    func hostGame(with: String, isSuperghost: Bool) async throws {
        try await setGameVar(to: createGame(userId: with, isPrivate: true, isSuperghost: true))
        connectToWebSocket(gameId: game?.id ?? "", isPrivate: true, isSuperghost: isSuperghost)
    }

    func updateGame(_ game: Game, isPrivate: Bool, isSuperghost: Bool) async throws {
        try await setGameVar(to: updateGame(updatedGame: game, isPrivate: isPrivate, isSuperghost: isSuperghost))
    }

    func quitGame(isPrivate: Bool, isSuperghost: Bool) async throws {
        try await deleteGame(gameId: game?.id ?? "", isPrivate: isPrivate, isSuperghost: isSuperghost)
        await setGameVar(to: nil)
        disconnectWebSocket()
    }

    static let shared = ApiLayer()
    @Published var game: Game?

    func createGame(userId: String, isPrivate: Bool, isSuperghost: Bool) async throws -> Game {
        let url = await URL(string: "\(backendURL(.https, isSuperghost: isPrivate ? true : isSuperghost))/game/create")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let json = Game(id: UUID().uuidString, player1Id: userId, player2Id: isPrivate ? "privateGame" : "", blockMoveForPlayerId: userId, rematchPlayerId: [], moves: [])
        request.httpBody = try JSONEncoder().encode(json)

        let (data, _) = try await URLSession.shared.data(for: request)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }

    func findEmptyGame(isSuperghost: Bool) async throws -> Game {
        let url = await URL(string: "\(backendURL(.https, isSuperghost: isSuperghost))/game/findEmptyPlayer2Id")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }

    func joinGame(userId: String, gameId: String, isPrivate: Bool, isSuperghost: Bool) async throws -> Game {
        let url = await URL(string: "\(backendURL(.https, isSuperghost: isPrivate ? true : isSuperghost))/game/join/\(gameId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONEncoder().encode(userId)

        let (data, _) = try await URLSession.shared.data(for: request)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }

    func getGame(gameId: String, isPrivate: Bool, isSuperghost: Bool) async throws -> Game {
        let url = await URL(string: "\(backendURL(.https, isSuperghost: isPrivate ? true : isSuperghost))/game/\(gameId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let game = try JSONDecoder().decode(Game.self, from: data)

        return game
    }

    private func deleteGame(gameId: String, isPrivate: Bool, isSuperghost: Bool) async throws {
        let url = await URL(string: "\(backendURL(.https, isSuperghost: isPrivate ? true : isSuperghost))/game/\(gameId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, _) = try await URLSession.shared.data(for: request)
    }

    func updateGame(updatedGame: Game, isPrivate: Bool, isSuperghost: Bool) async throws -> Game {
        let url = await URL(string: "\(backendURL(.https, isSuperghost: isPrivate ? true : isSuperghost))/game")!
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

    func connectToWebSocket(gameId: String, isPrivate: Bool, isSuperghost: Bool) {
        subscribedToGameId = gameId
        Task{
            do{
                try await receive(isPrivate: isPrivate, isSuperghost: isSuperghost)
            } catch {
                subscribedToGameId = nil
                Task{[weak self] in
                    await self?.setGameVar(to: nil)
                }
            }
        }
    }
    private func receive(isPrivate: Bool, isSuperghost: Bool) async throws {
        if let subscribedToGameId {
            try await setGameVar(to: self.getGame(gameId: subscribedToGameId, isPrivate: isPrivate, isSuperghost: isSuperghost))
            try? await Task.sleep(for: .seconds(1))
            try await receive(isPrivate: isPrivate, isSuperghost: isSuperghost)
        } else {
            await setGameVar(to: nil)
        }
    }
    func disconnectWebSocket() {
        subscribedToGameId = nil
    }

    #else
    private var webSocketTask: (URLSessionWebSocketTask)?

    private func connectToWebSocket(gameId: String, isPrivate: Bool, isSuperghost: Bool) {
        Task{
            let urlSession = URLSession(configuration: .default)
            guard let url = await URL(string: "\(backendURL(.wss, isSuperghost: isPrivate ? true : isSuperghost))/subscribe/game/\(gameId)") else { return }

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
            receiveMessage()

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
                Task{[weak self] in
                    await self?.setGameVar(to: nil)
                }
                self?.disconnectWebSocket()
            }
        }
    }

    private func disconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    private class WebSocketDelegateOnClose: NSObject, URLSessionWebSocketDelegate{
        let onClose: ()->Void
        let onOpen: ()->Void

        init(onOpen: @escaping () -> Void, onClose: @escaping () -> Void) {
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
    #endif
}
