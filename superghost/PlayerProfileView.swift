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
                "Become \(rank.ordinalString()) on the Leaderboard"
            case .playedMatches(let count):
                "Play \(count) matches"
            case .winInMessages:
                "Win a Game In Messages"
            case .buy(let price):
                "You can buy this Skin for \(price)"
            }
        }
    }
    static let cowboy = Skin(image: "Skin/Cowboy", unlockBy: .score(at: 0))
    static let sailor = Skin(image: "Skin/Sailor", unlockBy: .widget)
    static let doctor = Skin(image: "Skin/Doctor", unlockBy: .playedMatches(count: 20))
    static let knight = Skin(image: "Skin/Knight", unlockBy: .winInMessages)
    static let engineer = Skin(image: "Skin/Engineer", unlockBy: .rank(at: 2))
    static let samurai = Skin(image: "Skin/Samurai", unlockBy: .score(at: 1700))
    
    static let skins = [
        cowboy,
        sailor,
        doctor,
        knight,
        engineer,
        samurai
    ]
}

extension Int {
    func ordinalString() -> String {
        let suffix: String

        // Handle special cases like 11th, 12th, 13th
        let lastTwoDigits = self % 100
        if lastTwoDigits >= 11 && lastTwoDigits <= 13 {
            suffix = "th"
        } else {
            // Otherwise use 1st, 2nd, 3rd, etc.
            switch self % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }

        return "\(self)\(suffix)"
    }
}

struct PlayerProfileView: View {
    @ObservedObject var playerProfileModel = PlayerProfileModel.shared
    @State private var expanded = false
    @Environment(\.scenePhase) var scenePhase
    let skins = Skin.skins
    
    @CloudStorage("score") private var score = 1000
    @CloudStorage("rank") private var rank = -1
    
    
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
                .task(id: scenePhase, priority: .background) {
#if canImport(WidgetKit)
                    hasWidget = (
                        try? await withCheckedThrowingContinuation{con in
                            WidgetCenter.shared.getCurrentConfigurations({ result in
                                con.resume(with: result)
                    })
                    })?.isEmpty ?? hasWidget
#endif
                    if let skin = Skin.skins.filter({$0.image == playerProfileModel.player.image}).first,
                    !hasUnlocked(skin: skin){
                        showMessage("You lost access to your Skin.")
                        showMessage(skin.unlockBy.lockedDescription)
                        playerProfileModel.player.image = Skin.cowboy.image
                    }
                }
            if expanded {
                LazyVGrid(columns: [.init(.adaptive(minimum: 100, maximum: 200))]) {
                    ForEach(skins){skin in
                        let isUnlocked = hasUnlocked(skin: skin)
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
                                    .multilineTextAlignment(.center)
                                    .opacity(isUnlocked ? 0 : 1)
                            }
                        }
                        .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .plain))
                    }
                }
                .frame(maxWidth: .infinity)
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
        case .buy(_):
            false
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
