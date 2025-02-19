//
//  PlayerProfileView.swift
//  superghost
//
//  Created by Hannes Nagel on 10/4/24.
//

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif
import GameKit

struct PlayerProfileView: View {
    @ObservedObject var playerProfileModel = PlayerProfileModel.shared
    @State private var expanded = false
    @Environment(\.scenePhase) var scenePhase
    let skins = Skin.skins
    
    @CloudStorage("score") private var score = 1000
    @CloudStorage("rank") private var rank = -1


    @CloudStorage("isPayingSuperghost") private var isPayingSuperghost = false


    @CloudStorage("lastWinInMessages") private var lastWinInMessages = Date.distantPast
    
    @AppStorage("hasWidget") var hasWidget = {
        if
            let lastWidgetUpdateString = NSUbiquitousKeyValueStore.default.string(forKey: "lastWidgetUpdate"),
           
                let lastWidgetUpdate = ISO8601DateFormatter().date(from: lastWidgetUpdateString),
           
                Calendar.current.isDateInToday(lastWidgetUpdate)
        {
            return true
        } else {
            return false
        }
    }()

    var cloudStorageHasWidget: Bool {
        if
            let lastWidgetUpdateString = NSUbiquitousKeyValueStore.default.string(forKey: "lastWidgetUpdate"),

                let lastWidgetUpdate = ISO8601DateFormatter().date(from: lastWidgetUpdateString),

                Calendar.current.isDateInToday(lastWidgetUpdate)
        {
            return true
        } else {
            return false
        }
    }

    var body: some View {
        VStack{
            GeometryReader{geo in
                playerProfileModel.player.imageView
                    .resizable()
                    .scaledToFit()
                    .clipShape(.circle)
                    .padding()
                    .onTapGesture {
                        expanded.toggle()
                        Logger.trackEvent(expanded ? "skin_view_open" : "skin_view_close")
                    }
                    .animation(.smooth, value: playerProfileModel.player.image)
                    .frame(maxWidth: 300)
                    .task(id: scenePhase, priority: .background) {
#if canImport(WidgetKit)
                        do {
                            hasWidget =
                            !(try await withCheckedThrowingContinuation{con in
                                WidgetCenter.shared.getCurrentConfigurations({ result in
                                    con.resume(with: result)
                                })
                            }).isEmpty
                        } catch {
                            hasWidget = cloudStorageHasWidget
                        }
#else
                        hasWidget = cloudStorageHasWidget
#endif
                        if let skin = Skin.skins.filter({$0.image == playerProfileModel.player.image}).first,
                           !hasUnlocked(skin: skin){
                            showMessage("You lost access to your Skin.")
                            showMessage(skin.unlockBy.lockedDescription)
                            playerProfileModel.player.image = Skin.cowboy.image
                            Logger.trackEvent("skin_access_lost", with: ["unlock_by":skin.unlockBy.lockedDescription])
                        }
                    }
                    .stretchable(in: geo)
            }
            .frame(minHeight: 300)
            if expanded {
                LazyVGrid(columns: [.init(.adaptive(minimum: 100, maximum: 200))]) {
                    ForEach(
                        skins
                            .filter{
                                $0.unlockBy != .superghost || isPayingSuperghost
                            }
                    ){skin in
                        let isUnlocked = hasUnlocked(skin: skin)
                        Button{
                            if isUnlocked {
                                playerProfileModel.player.image = skin.image
                                Logger.trackEvent("skin_equipped", with: ["skin":skin.unlockBy.lockedDescription])
                            } else {
                                switch skin.unlockBy {
                                case .widget:
                                    requestAction(.addWidget)
                                case .winInMessages:
                                    showMessage("Win a game this month in Messages to unlock this Skin")
                                    showMessage("Just tap the plus Button in Messages and then choose Superghost")
                                default:
                                    showMessage(skin.unlockBy.lockedDescription)
                                }
                                Logger.trackEvent("skin_not_unlocked", with: ["unlock_by":skin.unlockBy.lockedDescription])
                            }
                        } label: {
                            VStack{
                                Image(skin.image)
                                    .resizable()
                                    .scaledToFit()
                                    .overlay{
                                        if !isUnlocked {
                                            ZStack {
                                                Rectangle()
                                                    .fill()
                                                    .frame(height: 10)
                                                    .rotationEffect(.degrees(45))
                                                Circle().stroke(lineWidth: 10)
                                            }
                                        }
                                    }
                                    .clipShape(.circle)
                                Text(skin.unlockBy.lockedDescription)
                                    .lineLimit(2, reservesSpace: true)
                                    .multilineTextAlignment(.center)
                                    .opacity(isUnlocked ? 0 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .scale))
            }
        }
        .animation(.spring, value: expanded)
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
    }
    private func hasUnlocked(skin: Skin) -> Bool {
        switch skin.unlockBy {
        case .widget:
            hasWidget
        case .score(let necessaryScore):
            score >= necessaryScore
        case .rank(let necessaryRank):
            rank > 0 && rank <= necessaryRank
        case .playedMatches(count: let count):
            GKStore.shared.games.count >= count
        case .winInMessages:
            Calendar.current.isDate(.now, equalTo: lastWinInMessages, toGranularity: .month)
        case .superghost:
            isPayingSuperghost
        }
    }
}

#Preview {
    NavigationStack{
        List{
            PlayerProfileView()
                .listRowBackground(Color.clear)
                .buttonStyle(.plain)
        }
    }
}
