//
//  MinimizedGameView.swift
//  superghost
//
//  Created by Hannes Nagel on 12/5/24.
//

import SwiftUI

struct MinimizedGameView: View {
    let game: GameStat
    var body: some View {

        VStack {

            game.player2profile?.imageView
                .resizable()
                .scaledToFit()
                .clipShape(.circle)
                .frame(maxHeight: 100)

            Text(game.player2profile?.name ?? "Gustav")

            Text(game.word)
                .font(.title.bold())

            if let rank = game.player2profile?.rank {
                Text("Ranked \(rank.ordinalString())")
            } else {
                Text("Not ranked")
            }

            Text(game.won ? "Victory \(Image(systemName: "crown.fill"))" : "Defeat")
                .foregroundStyle(game.won ? .accent : .orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(5)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 20))
    }
}
#Preview {
    MinimizedGameView(
        game: .init(
            player2: (
                id: "playerid",
                profile: .init(
                    rank: 4,
                    name: "Gustav"
                )
            ),
            withInvitation: true,
            won: true,
            word: "word",
            id: UUID().uuidString
        )
    )
}
