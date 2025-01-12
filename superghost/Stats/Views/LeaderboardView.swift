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
                ContentPlaceHolderView(
                    "Play a game to join the leaderboard",
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
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .padding()
                }
            }
        }
        .sheet(item: $selectedScore) { entry in
            ScoreDetailView(entry: entry)
        }
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
                .padding(.horizontal)
                .padding(.vertical, 5)
                .contentShape(.rect)
                .background(entry.player.displayName == GKLocalPlayer.local.displayName ? .thinMaterial : .ultraThinMaterial)
                .background(entry.player.displayName == GKLocalPlayer.local.displayName ? .accent : .clear)
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .matchedGeometryEffect(id: entry.player.gamePlayerID, in: namespace)
        }
    }
}

struct ScoreDetailView: View {
    let entry : GKLeaderboard.Entry
    @State private var friends = [GKPlayer]?.none
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack{
            entry.player.asyncImage(.normal)
                .frame(maxWidth: 200, maxHeight: 200)
            Text(entry.player.displayName)
                .font(AppearanceManager.playerViewTitle)
            Text(entry.formattedScore).bold()
            Group{
            if let friends {
                if friends.contains(entry.player) {
                    Text("A friend of yours ranked at \(entry.rank)")
                    if #available(iOS 18.0, macOS 15.0, visionOS 2.0, *){
                        Button("View their profile"){
                            dismiss()

                            DispatchQueue.main.asyncAfter(deadline: .now()+0.7){
                                GKAccessPoint.shared.trigger(player: entry.player)
                            }
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                    }

                } else if entry.player == GKLocalPlayer.local {
                    Text("You are rank \(entry.rank)")
                    Button("View your profile"){
                        dismiss()

                        DispatchQueue.main.asyncAfter(deadline: .now()+0.7){
                            GKAccessPoint.shared.trigger(state: .localPlayerProfile){}
                        }
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                } else {
                    Text("Rank: \(entry.rank)")
                }
                if entry.player.isInvitable {
                    Button("Challenge"){
                        let vc: ViewController
                        if #available(iOS 17.0, *) {
                            vc = entry.challengeComposeController(withMessage: "I just scored \(entry.formattedScore) on the leaderboard!", players: [entry.player], completion: nil)
                        } else {
                            vc = entry.challengeComposeController(withMessage: "I just scored \(entry.formattedScore) on the leaderboard!", players: [entry.player], completionHandler: nil)
                        }

#if os(macOS)

                        let window = NSWindow(contentViewController: vc)
                        NSWindowController(window: window).showWindow(nil)
#else
                        UIApplication.shared.topViewController()?.present(vc, animated: true)
#endif

                    }
                }
            } else {
                ProgressView()
                    .task{
                        GKLocalPlayer.local.loadFriends { players, error in
                            if let players {
                                self.friends = players
                            }
                        }
                    }
            }
        }
            .toolbar{
                ToolbarItem(placement: .cancellationAction) {
                    Button{
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.bcCircle)
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
    }
}
extension GKPlayer {
    @MainActor
    func asyncImage(_ size: PhotoSize) -> some View {
        AsyncProfileImageView {
            try await withCheckedThrowingContinuation { con in
                self.loadPhoto(for: size) { image, error in
                    if let image {
                        con.resume(returning: Image(uiImage: image))
                    } else {
                        con.resume(throwing: error ?? NSError(domain: "Ouch", code: 0))
                    }
                }
            }
        } loading: {
            ProgressView()
        }
    }
    struct AsyncProfileImageView<Loading: View>: View {
        let closure: () async throws -> Image
        @State var image: Image?
        @ViewBuilder let loading: Loading

        var body: some View {
            if let image {
                image
                    .resizable().scaledToFit().clipShape(.circle)
            } else {
                loading
                    .task{
                        image = try? await closure()
                    }
            }
        }
    }
}


#Preview {
    LeaderboardView()
}
