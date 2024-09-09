//
//  SharedMessages.swift
//  superghost
//
//  Created by Hannes Nagel on 9/6/24.
//

import Foundation

@MainActor
final class MessageModel: ObservableObject {
    private init(){}
    static let shared = MessageModel()
    @Published var message = [String]()
    @Published var showingAction = UserAction?.none
    @CloudStorage("score") private var score = 1000

    func changeScore(by translation: Int) async {

        for _ in 1...translation.magnitude {
            if translation > 0 {
                score += 1
            } else {
                score -= 1
            }
            try? await Task.sleep(for: .milliseconds(100/translation.magnitude))
        }
        let score = score
        Task.detached{
            try? await GameStat.submitScore(score)
        }
    }
}

@MainActor
func showMessage(_ message: String) {
    MessageModel.shared.message.append(message)
}

@MainActor
func requestAction(_ action: UserAction){
    Logger.userInteraction.info("Requesting action: \(action.rawValue, privacy: .public)")
    MessageModel.shared.showingAction = action
}

enum UserAction: String, Identifiable{
    case addFriends, addWidget, enableNotifications

    var id: Self { self }
}