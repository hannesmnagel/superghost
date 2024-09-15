//
//  MessagesViewController.swift
//  Messages Extension
//
//  Created by Hannes Nagel on 8/6/24.
//

import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {
    let appState = AppState()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let hostingController = UIHostingController(
            rootView: ContentView()
                .environmentObject(appState)
        )
        addChild(hostingController)
        view.addSubview(hostingController.view)

        // Set constraints to make the SwiftUI view fill the parent view
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Notify the hosting controller that it has been moved to the parent
        hostingController.didMove(toParent: self)
    }
    
    // MARK: - Conversation Handling
    
    override func willBecomeActive(with conversation: MSConversation) {
        // Called when the extension is about to move from the inactive to active state.
        // This will happen when the extension is about to present UI.
        
        // Use this method to configure the extension and restore previously stored state.
        appState.conversation = conversation
        if let string = conversation.selectedMessage?.url?.lastPathComponent,
           let data = Data(base64Encoded: string),
           let move = try? JSONDecoder().decode(Move.self, from: data)
        {
            appState.lastMove = move
            appState.session =  conversation.selectedMessage?.session
        }
        appState.dismiss = {[weak self] in
            self?.dismiss()
        }
    }

    override func didResignActive(with conversation: MSConversation) {
        // Called when the extension is about to move from the active to inactive state.
        // This will happen when the user dismisses the extension, changes to a different
        // conversation or quits Messages.
        
        // Use this method to release shared resources, save user data, invalidate timers,
        // and store enough state information to restore your extension to its current state
        // in case it is terminated later.
        appState.conversation = nil
    }
   
    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        // Called when a message arrives that was generated by another instance of this
        // extension on a remote device.
        // Use this method to trigger UI updates in response to the message.

        if let string = message.url?.lastPathComponent,
           let data = Data(base64Encoded: string),
           let move = try? JSONDecoder().decode(Move.self, from: data){
            appState.conversation = conversation
            appState.lastMove = move
            appState.session =  message.session
        }
    }
    
    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        // Called when the user taps the send button.
    }
    
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
        // Called when the user deletes the message without sending it.
    
        // Use this to clean up state related to the deleted message.
    }
    
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Called before the extension transitions to a new presentation style.
    
        // Use this method to prepare for the change in presentation style.
    }
    
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Called after the extension transitions to a new presentation style.
    
        // Use this method to finalize any behaviors associated with the change in presentation style.
        appState.presentation = presentationStyle
    }

}

final class AppState: ObservableObject {
    @Published var dismiss: (()->Void)?
    @Published var presentation: MSMessagesAppPresentationStyle?
    @Published var conversation: MSConversation?
    @Published var session: MSSession?
    @Published var lastMove: Move? {
        didSet{
            if let move = lastMove,
               let conversation,
               let winnerIsPlayer1 = move.winnerIsPlayer1 {
                let isPlayer1 = move.player1Id == conversation.localParticipantIdentifier.uuidString
                alertItem = winnerIsPlayer1 ? isPlayer1 ? .won : .lost : isPlayer1 ? .lost : .won
                if let session{
                    if NSUbiquitousKeyValueStore.default.double(forKey: "\(conversation.storeKey).\(session).lastMoveCount") > 0 {
                        do{
                            try GameStat(
                                player2: isPlayer1 ? move.player2Id : move.player1Id,
                                withInvitation: true,
                                won: winnerIsPlayer1 ? isPlayer1 : !isPlayer1,
                                word: move.word,
                                id: UUID().uuidString
                            )
                            .save()
                            NSUbiquitousKeyValueStore.default.set(-1.0, forKey: "\(conversation.storeKey).\(session).lastMoveCount")
                        } catch {}
                    }
                }
            }
        }
    }
    @Published var alertItem: AlertItem?

    func move(_ move: Move){
        guard let conversation,
              let data = try? JSONEncoder().encode(move)
        else {return}
        let message = if let session {MSMessage(session: session)} else {MSMessage(session: MSSession())}
        if session == nil {
            session = message.session
        }
        message.shouldExpire = false
        let layout = MSMessageTemplateLayout()

        layout.image = UIImage(resource: .ghostHeadingLeft)
        if let winnerIsPlayer1 = move.winnerIsPlayer1 {
            layout.caption = (move.blockMoveForPlayer1 == winnerIsPlayer1) ? "Won the game" : "Lost the game"
        } else if move.player2Id.isEmpty{
            layout.caption = "Invited to a game"
        } else if move.word.isEmpty {
            layout.caption = "Joined the game"
        } else {
            layout.caption = "Did a Move"
        }
        layout.subcaption = "in Superghost"
        message.layout = layout
        message.url = URL(string: "https://a.a/\(data.base64EncodedString())")
        message.summaryText = layout.caption
        conversation.send(message)
        lastMove = move
        NSUbiquitousKeyValueStore.default.set(Double(move.count), forKey: "\(conversation.storeKey).\(session!).lastMoveCount")
        Logger.remoteLog("messages app \(layout.caption ?? "did something")")
    }
}

extension MSConversation{
    var storeKey: String {
        var identifiers = remoteParticipantIdentifiers.map{$0.uuidString}.sorted()
        identifiers.append( localParticipantIdentifier.uuidString )
        return identifiers.joined(separator: "\n")
    }
}

struct ContentView: View {
    @EnvironmentObject var appState : AppState
    @State var disabled = false

    var body: some View {
        Group{
            if let lastMove = appState.lastMove,
               let conversation = appState.conversation,
               lastMove.player1Id == conversation.localParticipantIdentifier.uuidString ? lastMove.blockMoveForPlayer1 : !lastMove.blockMoveForPlayer1 || disabled,
               lastMove.winnerIsPlayer1 == nil{
                Text("Sent...")
                    .font(AppearanceManager.startUpSuperghost)
            } else {
                GameView()
            }
        }
        .task(id: appState.lastMove){
            try? await Task.sleep(for: .milliseconds(500))

            if let conversation = appState.conversation, let lastMove = appState.lastMove, let session = appState.session{
                let actualCount = Int(NSUbiquitousKeyValueStore.default.double(forKey: "\(conversation.storeKey).\(session).lastMoveCount"))
                disabled = !(lastMove.count > actualCount)
            }
            if disabled {
                appState.dismiss?()
            }
        }
    }
}

struct GameView: View {
    @EnvironmentObject var appState : AppState
    let allowedLetters = ["", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
    @State private var leadingLetter = ""
    @State private var trailingLetter = ""
    @State private var alertItem : AlertItem?

    var body: some View {
        VStack{
            if let conversation = appState.conversation{
                if let lastMove = appState.lastMove {
                    if !lastMove.player1Id.isEmpty && !lastMove.player2Id.isEmpty {
                        VStack{
                            if let _ = lastMove.challengerIsPlayer1{
                                Text("You were challenged")
                                SayTheWordButton(lastMove: lastMove, isPlayer1: !lastMove.blockMoveForPlayer1) { move in
                                    appState.move(move)
                                }
                                AsyncButton{
                                    appState.move(
                                        Move(
                                            word: lastMove.word,
                                            blockMoveForPlayer1: !lastMove.blockMoveForPlayer1,
                                            winnerIsPlayer1: lastMove.blockMoveForPlayer1,
                                            player1Id: lastMove.player1Id,
                                            player2Id: lastMove.player2Id,
                                            count: lastMove.count + 1
                                        )
                                    )
                                } label: {
                                    Text("Yes, I lied")
                                }
                            } else {
                                HStack{
                                    if !lastMove.word.isEmpty {
                                        SingleLetterPicker(letter: $leadingLetter, allowedLetters: allowedLetters)
                                            .disabled(!trailingLetter.isEmpty)
                                        Text(lastMove.word)
                                            .font(AppearanceManager.wordInGame)
                                    }
                                    SingleLetterPicker(letter: $trailingLetter, allowedLetters: allowedLetters)
                                        .disabled(!leadingLetter.isEmpty)
                                        .font(AppearanceManager.letterPicker)
                                }

                                AsyncButton{
                                    try await processPlayerMove(
                                        for: "\(leadingLetter)\(appState.lastMove?.word ?? "")\(trailingLetter)",
                                        currentUser: conversation.localParticipantIdentifier.uuidString,
                                        player1Id: lastMove.player1Id,
                                        player2Id: lastMove.player2Id,
                                        newCount: lastMove.count + 1
                                    )
                                    trailingLetter = ""
                                    leadingLetter = ""
                                } label: {
                                    Text("Submit Move")
                                }
                                .keyboardShortcut(.defaultAction)
                                .disabled(leadingLetter.isEmpty && trailingLetter.isEmpty)

                                if lastMove.word.count > 1 {
                                    AsyncButton{
                                        appState.move(
                                            Move(
                                                word: lastMove.word,
                                                blockMoveForPlayer1: !lastMove.blockMoveForPlayer1,
                                                challengerIsPlayer1: !lastMove.blockMoveForPlayer1,
                                                player1Id: lastMove.player1Id,
                                                player2Id: lastMove.player2Id,
                                                count: lastMove.count + 1
                                            )
                                        )
                                    } label: {
                                        Text("There is no such word")
                                    }
                                }
                            }
                        }
                        .disabled(lastMove.player1Id == conversation.localParticipantIdentifier.uuidString ? lastMove.blockMoveForPlayer1 : !lastMove.blockMoveForPlayer1)
                    } else {
                        Text("Game hasn't started")
                        if lastMove.player1Id != conversation.localParticipantIdentifier.uuidString {
                            Button("Join"){
                                appState.move(
                                    Move(
                                        word: "",
                                        blockMoveForPlayer1: false,
                                        challengerIsPlayer1: nil,
                                        winnerIsPlayer1: nil,
                                        player1Id: lastMove.player1Id,
                                        player2Id: conversation.localParticipantIdentifier.uuidString,
                                        count: lastMove.count + 1
                                    )
                                )
                            }
                            Link("Learn how to play", destination: URL(string: "https://hannesnagel.com/open/ghost/instructions")!)
                        }
                    }
                } else {
                    Button("Start") {
                        appState.move(
                            Move(
                                word: "",
                                blockMoveForPlayer1: true,
                                player1Id: conversation.localParticipantIdentifier.uuidString,
                                player2Id: "",
                                count: 1
                            )
                        )
                    }
                    Link("Learn how to play", destination: URL(string: "https://hannesnagel.com/open/ghost/instructions")!)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay{
            if let alertItem = appState.alertItem{
                AlertView(
                    alertItem: alertItem,
                    dismissParent: nil,
                    isSuperghost: true,
                    quitGame: nil,
                    rematch: nil,
                    word: appState.lastMove?.word ?? "",
                    player2Id: appState.lastMove?.player2Id ?? ""
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Material.bar, ignoresSafeAreaEdges: .all)
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
    }
    func processPlayerMove(for word: String, currentUser: String, player1Id: String, player2Id: String, newCount: Int) async throws {
        try await appState.move(
            Move(
                word: word,
                blockMoveForPlayer1: currentUser == player1Id,
                winnerIsPlayer1: isWord(word) ? currentUser != player1Id : nil,
                player1Id: player1Id,
                player2Id: player2Id,
                count: newCount
            )
        )

    }
}


struct SayTheWordButton: View {
    @State private var isExpanded = false
    @State private var word = ""
    @State var lastMove : Move
    let isPlayer1: Bool
    let setMove: (Move) -> Void

    var body: some View {
        if isExpanded{
            TextField("What word did you think of?", text: $word)
        }
        AsyncButton {
            if isExpanded {
                if try await isWord(word) && word.localizedCaseInsensitiveContains(lastMove.word) {
                    setMove(
                        Move(
                            word: word,
                            blockMoveForPlayer1: isPlayer1,
                            challengerIsPlayer1: !isPlayer1,
                            winnerIsPlayer1: isPlayer1,
                            player1Id: lastMove.player1Id,
                            player2Id: lastMove.player2Id,
                            count: lastMove.count + 1
                        )
                    )
                } else{
                    word = "This doesn't fit"
                }
            } else {
                isExpanded = true
            }
        } label: {
            Text(isExpanded ? "Confirm" : "There is a word")
        }
    }
}


enum GameError: Error{
    case noConversation
}

struct Move: Codable, Hashable{
    var word: String
    var blockMoveForPlayer1: Bool
    var challengerIsPlayer1: Bool?
    var winnerIsPlayer1: Bool?
    var player1Id: String
    var player2Id: String
    var count: Int
}
func isWord(_ word: String) async throws -> Bool {
    if word.count < 3 {return false}
    let (data, _) = try await retry{try await URLSession.shared.data(from: URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)")!)}
    if let _ = try? JSONDecoder().decode([WordEntry].self, from: data){
        return true
    }
    return false
}
func define(_ word: String) async throws -> [WordEntry] {
    let (data, _) = try await retry{try await  URLSession.shared.data(from: URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)")!)}
    return try JSONDecoder().decode([WordEntry].self, from: data)
}

struct WordEntry: Codable, Hashable {
    let word: String
    let phonetic: String?
    let phonetics: [Phonetic]
    let origin: String?
    let meanings: [Meaning]
}

struct Phonetic: Codable, Hashable {
    let text: String
    let audio: String?
}

struct Meaning: Codable, Hashable {
    let partOfSpeech: String
    let definitions: [Definition]
}

struct Definition: Codable, Hashable {
    let definition: String
    let example: String?
    let synonyms: [String]
    let antonyms: [String]
}

func retry<R:Sendable>(count: Int = 3, _ action: () async throws ->R) async rethrows -> R {
    do {
        return try await action()
    } catch {
        guard count > 0 else {throw error}
        return try await retry(count: count-1){
            try? await Task.sleep(for: .seconds(1))
            return try await action()
        }

    }
}
import GameKit

extension GKAccessPoint{
    func trigger(achievementID: String){
        //do nothing
    }
}
