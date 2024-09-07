//
//  GKAccessPoint.swift
//  superghost
//
//  Created by Hannes Nagel on 9/5/24.
//

import GameKit
import SwiftUI

extension GKAccessPoint{
    @MainActor
    func trigger(leaderboardID: String, playerScope: GKLeaderboard.PlayerScope, timeScope: GKLeaderboard.TimeScope){
        let viewController = GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: playerScope, timeScope: timeScope)
        let vc = GKGameCenterViewControllerDismissable(gameCenterViewController: viewController)
        present(vc)
    }
    @MainActor
    func trigger(achievementID: String, handler: () -> Void){
        let viewController = GKGameCenterViewController(achievementID: achievementID)
        let vc = GKGameCenterViewControllerDismissable(gameCenterViewController: viewController)
        present(vc)
    }

    @MainActor
    func addFriends(){
#if os(macOS)
        try? GKLocalPlayer.local.presentFriendRequestCreator(from: NSApplication.shared.keyWindow ?? .init())
#else
        try? GKLocalPlayer.local.presentFriendRequestCreator(from: UIApplication.shared.topViewController() ?? UIViewController())
#endif
    }
    @MainActor
    private func present(_ viewController: ViewController){
#if os(macOS)
        NSApplication.shared.keyWindow?.contentViewController?.presentAsModalWindow(viewController)
#else
        UIApplication.shared.topViewController()?.present(viewController, animated: true)
#endif
    }
}

@MainActor
private final class GKGameCenterViewControllerDismissable: ViewController, GKGameCenterControllerDelegate{
    let gameCenterViewController: GKGameCenterViewController

    init(gameCenterViewController: GKGameCenterViewController){
        self.gameCenterViewController = gameCenterViewController
        super.init(nibName: nil, bundle: nil)
    }
    #if os(macOS)
    override func viewDidAppear() {
        gameCenterViewController.gameCenterDelegate = self
        presentAsSheet(gameCenterViewController)
    }
    #else
    override func viewDidAppear(_ animated: Bool) {
        gameCenterViewController.gameCenterDelegate = self
        present(gameCenterViewController, animated: false)
    }
    #endif
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        //Dismissing it twice as workaround
        DispatchQueue.main.async{
#if os(macOS)
            NSApplication.shared.keyWindow?.close()
            DispatchQueue.main.asyncAfter(deadline: .now()+0.1){
                NSApplication.shared.keyWindow?.close()
            }
#else
            self.dismiss(animated: true)
            self.dismiss(animated: true)
#endif
        }
    }

}

