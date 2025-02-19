//
//  SignInView.swift
//  superghost
//
//  Created by Hannes Nagel on 9/29/24.
//

import SwiftUI
import GameKit

struct SignInView: View {
    @State private var progress = 0.0
    @State private var manualSignInRequired = false
    @State private var showReasons = false
    @Environment(\.scenePhase) var scenePhase
    let onFinish: () -> Void
    @State private var loadingInitialDataId = UUID()

    var body: some View {
        VStack{
            if GKLocalPlayer.local.isAuthenticated {
                ProgressView("    Loading Data...", value: progress)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .all)
                    .clipShape(.capsule)
                    .task(id: loadingInitialDataId){
                        let restartTask = Task{
                            try await Task.sleep(for: .seconds(20))
                            try Task.checkCancellation()
                            loadingInitialDataId = .init()
                        }
                        do{
                            try await GKStore.shared.loadInitialData()
                            progress = 1
                            await StoreManager.shared.updatePurchasedProducts()
                            onFinish()
                            restartTask.cancel()
                        } catch {}
                    }
                    .task{
                        for i in 10...18{
                            try? await Task.sleep(for: .seconds(0.3))
                            progress = Double(i)/20
                        }
                    }
            } else
            if manualSignInRequired {
                pleaseSignInView
                    .foregroundStyle(.black)
            } else {
                ProgressView("    Signing you in...", value: progress)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .all)
                    .clipShape(.capsule)
                    .task {
                        GKAccessPoint.shared.showHighlights = true

                        GKLocalPlayer.local.authenticateHandler = {vc, error in
                            if error != nil {
                                manualSignInRequired = true
                            } else {
                                progress += 0.01
                            }
                        }
                    }
                    .task {
                        for i in 0...10{
                            try? await Task.sleep(for: .seconds(0.1))
                            progress = Double(i)/20
                        }
                    }
            }
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(
            Image(manualSignInRequired ? .ghostSad : .ghostThinking)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .offset(x: manualSignInRequired ? -20 : -40)
        )
        .animation(.smooth, value: manualSignInRequired)
        .animation(.smooth, value: progress)
    }
    @ViewBuilder
    var pleaseSignInView: some View {
        Text("No need for a seperate Account!")
            .font(AppearanceManager.howToPlayTitle)
            .multilineTextAlignment(.center)
        Text("You can sign in to Game Center")
        Spacer()
        if showReasons {
            VStack{
                Spacer()
                Group{
                    HStack{
                        Image(systemName: "person.3")
                            .font(.title)
                        VStack(alignment: .leading){
                            Text("Climb the leaderboard")
                                .font(.headline)
                            Text("And Compete with other players")
                                .font(.caption)
                        }
                    }
                    HStack{
                        Image(systemName: "person.3")
                            .font(.title)
                        VStack(alignment: .leading){
                            Text("Add your Friends")
                                .font(.headline)
                            Text("and challenge them!")
                                .font(.caption)
                        }
                    }
                    HStack{
                        Image(systemName: "person.3")
                            .font(.title)
                        VStack(alignment: .leading){
                            Text("Save your progress")
                                .font(.headline)
                            Text("and sync it to all your devices")
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 500, alignment: .leading)
                .background(
                    Material.ultraThin
                )
                .clipShape(.rect(cornerRadius: 20))
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .transition(.scale)
            Spacer(minLength: 40)
        }
        Button("Sign In") {
                GKAccessPoint.shared.trigger(state: .localPlayerProfile){}
        }
        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
        .padding(.horizontal)
        Button("Why do I have to sign in?") {
            withAnimation{
                showReasons.toggle()
            }
        }
        .foregroundStyle(.primary)
        .opacity(showReasons ? 0 : 1)
    }
}

#Preview {
    SignInView{}
}
