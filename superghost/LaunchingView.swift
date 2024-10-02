//
//  LaunchingView.swift
//  superghost
//
//  Created by Hannes Nagel on 9/29/24.
//

import SwiftUI
import GameKit

struct LaunchingView: View {
    @CloudStorage("showOnBoarding") var isFirstUse = true
    @State private var isAuthenticated = GKLocalPlayer.local.isAuthenticated
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        if isFirstUse {
            FirstUseView()
        } else if isAuthenticated{
            ContentView()
                .onChange(of: scenePhase) { old, new in
                    if new == .active {
                        isAuthenticated = GKLocalPlayer.local.isAuthenticated
                    }
                }
        } else {
            SignInView{isAuthenticated = true}
        }
    }
}

#Preview {
    LaunchingView()
}
