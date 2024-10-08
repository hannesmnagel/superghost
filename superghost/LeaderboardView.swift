//
//  LeaderboardView.swift
//  superghost
//
//  Created by Hannes Nagel on 8/4/24.
//

import SwiftUI
import GameKit

extension GKLeaderboard.Entry: Swift.Identifiable {
    public var id : String {
        self.debugDescription
    }
}

struct LeaderboardView: View {
    let isSuperghost: Bool
    @ObservedObject private var gkStore = GKStore.shared
    @State private var selectedScore: GKLeaderboard.Entry?
    @State private var playerScope = GKLeaderboard.PlayerScope.global
    @State private var hasUnlockedLeaderboard = false
    @CloudStorage("score") private var score = 1000
    @CloudStorage("rank") private var rank = -1
    @Namespace var namespace

    var body: some View {
        VStack{
            HStack{
                if let leaderboardTitle = gkStore.leaderboardTitle{
                    Text(leaderboardTitle)
                        .font(AppearanceManager.leaderboardTitle)
                }
                if let image = gkStore.leaderboardImage{
                    image.resizable().scaledToFit().clipShape(.circle).frame(width: 40, height: 40)
                }
            }
            if !gkStore.hasUnlockedLeaderboard {
                ContentUnavailableView(
                    "Earn 1,050 XP to see the leaderboard",
                    systemImage: "chart.bar.fill"
                )
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                if let entries = gkStore.leaderboardData {
                    inlineLeaderboard(entries: entries)
                        .id(gkStore.leaderboardData)
                    Button{
                        GKAccessPoint.shared.trigger(leaderboardID: "global.score", playerScope: .global, timeScope: .allTime)
                    } label: {
                        HStack{
                            Text("More")
                            Image(systemName: "ellipsis")
                        }
                        .contentShape(.rect)
                    }
                    .foregroundStyle(.accent)
                    .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .bordered))
                    .buttonBorderShape(.capsule)
                    .padding()
                }
            }
        }
        .sheet(item: $selectedScore) { entry in
            scoreDetail(for: entry)
        }
    }
    @ViewBuilder @MainActor
    func scoreDetail(for entry: GKLeaderboard.Entry) -> some View{
            NavigationStack{
                entry.player.asyncImage(.normal)
                    .frame(maxWidth: 200, maxHeight: 200)
                Text(entry.player.displayName)
                    .font(AppearanceManager.playerViewTitle)
                Text(entry.formattedScore).bold()

                AsyncView {
                    let friends = try? await GKLocalPlayer.local.loadFriends()
                    if friends?.contains(entry.player) ?? false {
                        Text("A friend of yours ranked at \(entry.rank)")
                        if #available(iOS 18.0, macOS 15.0, visionOS 2.0, *){
                            Button("View their profile"){
                                selectedScore = nil

                                DispatchQueue.main.asyncAfter(deadline: .now()+0.7){
                                    GKAccessPoint.shared.trigger(player: entry.player)
                                }
                            }
                            .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .bordered))
                            .buttonBorderShape(.capsule)
                        }

                    } else if entry.player == GKLocalPlayer.local {
                        Text("You are rank \(entry.rank)")
                        Button("View your profile"){
                            selectedScore = nil

                            DispatchQueue.main.asyncAfter(deadline: .now()+0.7){
                                GKAccessPoint.shared.trigger(state: .localPlayerProfile){}
                            }
                        }
                        .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .bordered))
                        .buttonBorderShape(.capsule)
                    } else {
                        Text("Rank: \(entry.rank)")
                    }
                    if entry.player.isInvitable {
                        Button("Challenge"){
                            let vc: ViewController
                            vc = entry.challengeComposeController(withMessage: "I just scored \(entry.formattedScore) on the leaderboard!", players: [entry.player], completion: nil)

#if os(macOS)

                            let window = NSWindow(contentViewController: vc)
                            NSWindowController(window: window).showWindow(nil)
                            #else
                            UIApplication.shared.topViewController()?.present(vc, animated: true)
#endif

                        }
                    }
                } loading: {
                    ProgressView()
                }
                .toolbar{
                    ToolbarItem(placement: .cancellationAction) {
                        Button{
                            selectedScore = nil
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .bordered))
                        .buttonBorderShape(.circle)
                        .keyboardShortcut(.cancelAction)
                    }
                }
            }
//        }
    }
    @ViewBuilder @MainActor
    func inlineLeaderboard(entries: [GKLeaderboard.Entry]) -> some View {
        ForEach(entries, id: \.rank) { entry in
            Button{
                if #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) {
                    GKAccessPoint.shared.trigger(player: entry.player)
                } else {
                    selectedScore = entry
                }
            } label: {
                HStack{
                    Text("\(entry.rank).")
                    entry.player.asyncImage(.small)
                        .frame(width: 40, height: 40)
                        .id(entry.player.alias)
                    Text(entry.player.alias)
                    Spacer()
                    Text(entry.formattedScore)
                }
                .contentShape(.rect)
            }
            .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .plain))
            .matchedGeometryEffect(id: entry.player.gamePlayerID, in: namespace)
        }
    }
}
extension GKPlayer {
    @MainActor
    func asyncImage(_ size: PhotoSize) -> some View {
        AsyncView {
            await Task<Image?, Never>{
                while !GKLocalPlayer.local.isAuthenticated{
                    try? await Task.sleep(for: .seconds(1))
                }
                return try? await withCheckedThrowingContinuation{con in
                    self.loadPhoto(for: size) { image, error in
                        if let image {
                            con.resume(returning: Image(uiImage: image))
                        } else {
                            con.resume(throwing: error!)
                        }
                    }

                }
            }.value?
            .resizable().scaledToFit().clipShape(.circle)
        } loading: {
            ProgressView()
        }
    }
}


#Preview {
    LeaderboardView(isSuperghost: true)
}
