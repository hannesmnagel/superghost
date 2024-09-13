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
    @State private var hasUnlockedLeaderboard = false
    @EnvironmentObject var viewModel: GameViewModel
    @CloudStorage("score") private var score = 1000
    @CloudStorage("rank") private var rank = -1
    @Namespace var namespace

    var body: some View {
        VStack{
            HStack{
                Text(title)
                    .font(AppearanceManager.leaderboardTitle)
                if let image{
                    image.resizable().scaledToFit().clipShape(.circle).frame(width: 40, height: 40)
                }
            }
            if !GKLocalPlayer.local.isAuthenticated{
                ContentPlaceHolderView("Sign In to Game Center to see the leaderboard", systemImage: "person.3")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if !hasUnlockedLeaderboard {
                ContentPlaceHolderView("Earn 1,050 XP to see the leaderboard", systemImage: "chart.bar.fill")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                inlineLeaderboard
                if image != nil {
                    Button{
                        GKAccessPoint.shared.trigger(leaderboardID: "global.score", playerScope: .global, timeScope: .allTime)
                    } label: {
                        HStack{
                            Text("More")
                            Image(systemName: "ellipsis")
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.bcCapsule)
                    .padding()
                }
            }
        }
        .task(id: viewModel.games){
            while !GKLocalPlayer.local.isAuthenticated{
                try? await Task.sleep(for: .seconds(2))
            }
            hasUnlockedLeaderboard = (try? await GKAchievement.loadAchievements().first(where: { $0.identifier == Achievement.leaderboardUnlock.rawValue })?.percentComplete) == 100
            try? await loadData()
        }
        .task(id: score){
            try? await Task.sleep(for: .seconds(5))
            try? await loadData()
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
                            .buttonStyle(.bordered)
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
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.bcCapsule)
                    } else {
                        Text("Rank: \(entry.rank)")
                    }
                    if entry.player.isInvitable {
                        Button("Challenge"){
                            let vc: ViewController
                            if #available(iOS 17.0, macOS 14.0, *) {
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
                        .buttonBorderShape(.bcCircle)
                    }
                }
            }
//        }
    }
    nonisolated func loadData() async throws {
        guard let leaderboard = try? await GKLeaderboard.loadLeaderboards(IDs: ["global.score"]).first
        else {
            return
        }
        let title = leaderboard.title ?? ""
        let image = try? await withCheckedThrowingContinuation{con in
            leaderboard.loadImage { image, error in
                if let image {
                    con.resume(returning: Image(uiImage: image))
                } else {
                    con.resume(throwing: error!)
                }
            }

        }
        let entries = try await leaderboard.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...5))
        await MainActor.run{
            self.myScore = entries.0
            self.rank = myScore?.rank ?? -1
            self.entries = entries.1
            self.title = title
            self.image = image
        }
    }
    @ViewBuilder @MainActor
    var inlineLeaderboard: some View {
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
            .buttonStyle(.plain)
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
