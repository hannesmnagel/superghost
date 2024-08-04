//
//  GameCenterView.swift
//  superghost
//
//  Created by Hannes Nagel on 8/4/24.
//

import Foundation
import GameKit
import SwiftUI

struct GameCenterView: View {
    @Environment(\.dismiss) var dismiss
    let viewController: GKGameCenterViewController

    init(viewController: GKGameCenterViewController = .init()) {
        self.viewController = viewController
    }
    var body: some View {
        GameCenterDismissView(viewController: viewController){dismiss()}
    }
}
#if os(macOS)
struct GameCenterDismissView: NSViewControllerRepresentable {
    let viewController: GKGameCenterViewController
    let dismiss: () -> Void

    public init(viewController: GKGameCenterViewController = .init(), dismiss: @escaping () -> Void) {
        self.viewController = viewController
        self.dismiss = dismiss
    }

    public func makeNSViewController(context: Context) -> GKGameCenterViewController {
        let gkVC = viewController
        gkVC.gameCenterDelegate = context.coordinator
        return gkVC
    }

    public func updateNSViewController(_ nsViewController: GKGameCenterViewController, context: Context) {}

    public func makeCoordinator() -> GKCoordinator {
        return GKCoordinator(self, dismiss: dismiss)
    }
}
extension Image{
    init(uiImage: NSImage) {
        self.init(nsImage: uiImage)
    }
}
#else
struct GameCenterDismissView: UIViewControllerRepresentable {
    let viewController: GKGameCenterViewController
    let dismiss: ()->Void

    public init(viewController: GKGameCenterViewController = .init(), dismiss: @escaping () -> Void) {
        self.viewController = viewController
        self.dismiss = dismiss
    }

    public func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let gkVC = viewController
        gkVC.gameCenterDelegate = context.coordinator

        return gkVC
    }

    public func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {
    }

    public func makeCoordinator() -> GKCoordinator {
        return GKCoordinator(self, dismiss: dismiss)
    }
}
#endif

public class GKCoordinator: NSObject, GKGameCenterControllerDelegate {
    var view: GameCenterDismissView
    let dismiss: ()->Void

    init(_ view: GameCenterDismissView, dismiss: @escaping () -> Void) {
        self.view = view
        self.dismiss = dismiss
    }

    public func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        dismiss()
    }
}
