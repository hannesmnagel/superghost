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

    @State private var title = ""
    @State private var image : Image?
    @State private var entries = [GKLeaderboard.Entry]()
    @State private var myScore : GKLeaderboard.Entry?
    @State private var selectedScore: GKLeaderboard.Entry?
    @State private var playerScope = GKLeaderboard.PlayerScope.global

    var body: some View {
        VStack{
            HStack{
                Text(title)
                    .font(AppearanceManager.leaderboardTitle)
                if let image{
                    image.resizable().scaledToFit().clipShape(.circle).frame(width: 40, height: 40)
                } else if title.isEmpty {
                    ProgressView()
                        .task{
                            try? await Task.sleep(for: .seconds(1))
                            if GKLocalPlayer.local.isAuthenticated{
                                try? await loadData()
                            } else {
                                try? await Task.sleep(for: .seconds(2))
                                try? await loadData()
                            }
                        }
                }
            }
            inlineLeaderboard
            if image != nil {
                Button{
                    GKAccessPoint.shared.trigger(state: .leaderboards) {}
                } label: {
                    HStack{
                        Text("More")
                        Image(systemName: "ellipsis")
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .padding()
            }
        }
        .animation(.bouncy, value: myScore)
        .animation(.bouncy, value: selectedScore)
        .animation(.bouncy, value: playerScope)
        .animation(.bouncy, value: entries)
        .animation(.bouncy, value: image)
        .animation(.bouncy, value: title)
        .sheet(item: $selectedScore) { entry in
            scoreDetail(for: entry)
        }
    }
    @ViewBuilder @MainActor
    func scoreDetail(for entry: GKLeaderboard.Entry) -> some View{
//        if #available(iOS 18.0, macOS 15.0, *){
//            GameCenterView(viewController: GKGameCenterViewController(player: entry.player))
//        } else {
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
                    } else if entry.player == GKLocalPlayer.local {
                        Text("You are rank \(entry.rank)")
                    } else {
                        Text("Rank: \(entry.rank)")
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
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                    }
                }
            }
//        }
    }
    func loadData() async throws {

        guard let leaderboard = try? await GKLeaderboard.loadLeaderboards(IDs: ["global.score"]).first
        else {
            title = "Couldn't load leaderboard"
            return
        }
        title = leaderboard.title ?? ""
        image = try await Image(uiImage: leaderboard.loadImage())
        let entries = try await leaderboard.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...5))
        myScore = entries.0
        self.entries = entries.1
    }
    @ViewBuilder @MainActor
    var inlineLeaderboard: some View {
        ForEach(entries, id: \.rank) { entry in
            Button{
//                if #available(iOS 18.0, macOS 15.0, *) {
//                    GKAccessPoint.shared.trigger(player: entry.player)
//                } else {
                    if entry.player == GKLocalPlayer.local{
                        GKAccessPoint.shared.trigger(state: .localPlayerProfile) {}
                    } else {
                        selectedScore = entry
                    }
//                }
            } label: {
                HStack{
                    Text("\(entry.rank).")
                    entry.player.asyncImage(.small)
                        .frame(width: 40, height: 40)
                    Text(entry.player.alias)
                    Spacer()
                    Text(entry.formattedScore)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}
extension GKPlayer {
    func asyncImage(_ size: PhotoSize) -> some View {
        AsyncView {
            try? await Image(uiImage: self.loadPhoto(for: size)).resizable().scaledToFit().clipShape(.circle)
        } loading: {
            ProgressView()
        }
    }
}

private struct AsyncView<Content: View, Loading: View>: View {
    @State var content: Content?
    @ViewBuilder let loading: Loading
    let contentClosure: () async -> Content
    init(@ViewBuilder content: @escaping () async -> Content, loading: () -> Loading) {
        self.content = nil
        self.loading = loading()
        contentClosure = content
    }

    var body: some View {
        if let content{
            content
        } else {
            loading
                .task {
                    content = await contentClosure()
                }
        }
    }
}

#Preview {
    LeaderboardView(isSuperghost: true)
}
