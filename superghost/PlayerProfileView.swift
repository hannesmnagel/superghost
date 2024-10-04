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

struct Skin : Identifiable, Equatable{
    var id = UUID()
    var image: String
    
    var unlockBy: UnlockReason
    
    enum UnlockReason: Equatable {
        case widget, score(at: Int), rank(at: Int), playedMatches(count: Int), winInMessages, buy(price: Int)
        
        var lockedDescription: String {
            switch self {
            case .widget:
                "Add a Widget"
            case .score(let score):
                "Earn a score of \(score)"
            case .rank(let rank):
                "Climb the leaderboard to rank \(rank)"
            case .playedMatches(let count):
                "Play \(count) matches"
            case .winInMessages:
                "Win a Game In Messages"
            case .buy(let price):
                "You can buy this Skin for \(price)"
            }
        }
    }
    static let cowboy = Skin(image: "SkinCowboyGhost", unlockBy: .score(at: 0))
    static let sailor = Skin(image: "SkinSailorGhost", unlockBy: .widget)
    static let doctor = Skin(image: "SkinDoctorGhost", unlockBy: .playedMatches(count: 20))
    static let knight = Skin(image: "SkinKnightGhost", unlockBy: .winInMessages)
    
    static let skins = [
        cowboy,
        sailor,
        doctor,
        knight,
    ]
}

struct PlayerProfileView: View {
    @ObservedObject var playerProfileModel = PlayerProfileModel.shared
    @State private var expanded = false
    @Environment(\.scenePhase) var scenePhase
    let skins = Skin.skins
    
    @CloudStorage("score") private var score = 1000
    @CloudStorage("rank") private var rank = -1
    
    
    @CloudStorage("lastWinInMessages") private var lastWinInMessages = Date.distantPast
    
    @CloudStorage("hasWidget") var hasWidget = {
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
    
    @CloudStorage("username") private var username = GKLocalPlayer.local.alias

    var body: some View {
        VStack{
            playerProfileModel.player.imageView
                .resizable()
                .scaledToFit()
                .clipShape(.circle)
                .onTapGesture {
                    expanded.toggle()
                }
                .animation(.smooth, value: playerProfileModel.player.image)
                .frame(maxWidth: 300)
            if expanded {
                TextField("Username", text: $username)
                    .frame(maxWidth: 300)
                    .onAppear{
                        playerProfileModel.player.name = username
                    }
                    .onChange(of: username) {_,_ in
                        playerProfileModel.player.name = username
                    }
#if os(macOS)
                    .textFieldStyle(.roundedBorder)
#endif
                LazyVGrid(columns: [.init(.adaptive(minimum: 100, maximum: 200))]) {
                    ForEach(skins){skin in
                        let isUnlocked = switch skin.unlockBy {
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
                        case .buy(_):
                            false
                        }
                        Button{
                            if isUnlocked {
                                playerProfileModel.player.image = skin.image
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
                                    .opacity(isUnlocked ? 0 : 1)
                            }
                        }
                        .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .plain))
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .top).combined(with: .scale))
                .task(id: scenePhase) {
#if canImport(WidgetKit)
                    hasWidget = (try? await !WidgetCenter.shared.currentConfigurations().isEmpty) ?? hasWidget
#endif
                }
            }
        }
        .animation(.smooth, value: expanded)
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
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
