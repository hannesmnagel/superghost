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
    @Published var showingScoreChangeBy = Int?.none
    @Published var message = [String]()
    @Published var showingAction = UserAction?.none
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
