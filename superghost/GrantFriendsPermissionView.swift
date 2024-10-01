//
//  GrantFriendsPermissionView.swift
//  superghost
//
//  Created by Hannes Nagel on 9/29/24.
//

import SwiftUI
import GameKit

struct GrantFriendsPermissionView: View {
    let onFinish: () -> Void
    @State private var progress = 0.0
    @State private var grantedPermission = false
    @State private var showReasons = false

    var body: some View {
        VStack{
            if !grantedPermission {
                pleaseGrantPermission
                    .foregroundStyle(.black)
            }
        }
        .background(
            Image(grantedPermission ? .ghostHearts : .ghostThinking)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .offset(x: grantedPermission ? -20 : -40)
        )
        .animation(.smooth, value: grantedPermission)
        .animation(.smooth, value: progress)
    }
    @ViewBuilder
    var pleaseGrantPermission: some View {
        VStack{
            Text("Wanna play with some Friends?")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Allow Ghost to access your Game Center friends list")
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(stops: [.init(color: .white, location: 0), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
        )
        Spacer()
        if showReasons {
            VStack(spacing: 30){
                Group{
                    HStack{
                        Image(systemName: "person.3")
                            .font(.title)
                        VStack(alignment: .leading){
                            Text("Play with Friends")
                                .font(.headline)
                            Text("You can compete with them for challenges or on the leaderboard")
                                .font(.caption)
                        }
                    }
                    HStack{
                        Image(systemName: "lock")
                            .font(.title)
                        VStack(alignment: .leading){
                            Text("Privacy first.")
                                .font(.headline)
                            Text("This data will NOT be uploaded to my server")
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 500, alignment: .leading)
                .background(Color.white.opacity(0.8))
                .clipShape(.rect(cornerRadius: 20))
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .transition(.scale)
            Spacer()
        }
        VStack{
            AsyncButton {
                let authStatus = try await GKLocalPlayer.local.loadFriendsAuthorizationStatus()
                if authStatus == .notDetermined {
                    let _ = try? await GKLocalPlayer.local.loadFriends()
                }
                onFinish()
            } label: {
                Text("Continue")
            }
            .buttonStyle(AppearanceManager.HapticStlyeCustom(buttonStyle: AppearanceManager.FullWidthButtonStyle(isSecondary: false)))
            Button("But Why?!") {
                withAnimation{
                    showReasons.toggle()
                }
            }
            .foregroundStyle(.primary)
            .opacity(showReasons ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(stops: [.init(color: .white, location: 0), .init(color: .clear, location: 1)], startPoint: .bottom, endPoint: .top)
        )

    }
}

#Preview {
    GrantFriendsPermissionView {}
}
