//
//  Alerts.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI

enum AlertItem: String, Equatable, Identifiable {
    var id: String {self.rawValue}
    case won, lost, playerLeft
}

struct AlertView: View {
    @State var alertItem: AlertItem

    let dismissParent: (() -> Void)?
    let quitGame: (() async throws -> Void)?
    let rematch: (() async throws -> Void)?
    let word: String
    let player2Id: String

    var body: some View {
        ViewThatFits{
            content
            ScrollView{
                content
            }
        }
    }
    @ViewBuilder @MainActor
    var content: some View {

        VStack{
            Text(alertItem == .won ? "You won!" : alertItem == .playerLeft ? "Player left": "You lost!")
                .font(AppearanceManager.youWonOrLost)
            Text(alertItem == .won ? "Can you win another one?" : alertItem == .playerLeft ? "Play a new game" : "Get revenge!")
                .font(AppearanceManager.youWonOrLostSubtitle)
                .padding(.bottom)
            if alertItem == .playerLeft {
                if let quitGame{
                    Spacer()
                    AsyncButton{
                        dismissParent?()
                        try await quitGame()
                    } label: {
                        Text("Quit")
                    }
                    .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
                    Spacer()
                }
            } else {
                Spacer()
                WordDefinitionView(word: word)
                HStack{
                    if let quitGame{
                        Spacer()
                        AsyncButton{
                            dismissParent?()
                            try await quitGame()
                        } label: {
                            Text("   Quit    ")
                        }
                        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: player2Id != "botPlayer"))
                        .keyboardShortcut(.cancelAction)
                    }
                    if let rematch, player2Id != "botPlayer" {
                        Spacer()
                        AsyncButton{
                            try await rematch()
                        } label: {
                            Text("Rematch")
                        }
                        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
                        .keyboardShortcut(.defaultAction)
                    }

                    Spacer()
                }
                Spacer()
            }
        }
        .padding()
    }
}


#Preview{
    AlertView(alertItem: .lost, dismissParent: {}, quitGame: {}, rematch: {}, word: "word", player2Id: "player2Id")
}
#Preview{
    AlertView(alertItem: .playerLeft, dismissParent: {}, quitGame: {}, rematch: {}, word: "word", player2Id: "player2Id")
}
#Preview{
    AlertView(alertItem: .won, dismissParent: {}, quitGame: {}, rematch: {}, word: "word", player2Id: "player2Id")
}
