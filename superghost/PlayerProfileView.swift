//
//  PlayerProfileView.swift
//  superghost
//
//  Created by Hannes Nagel on 10/4/24.
//

import SwiftUI

struct PlayerProfileView: View {
    @ObservedObject var playerProfileModel = PlayerProfileModel.shared
    @State private var expanded = false
    @State private var possibleImages: [String] = [
        "SkinSailorGhost",
        "SkinCowboyGhost",
    ]

    var body: some View {
        VStack{
            playerProfileModel.player.imageView
                .resizable()
                .scaledToFit()
                .clipShape(.circle)
                .onTapGesture {
                    expanded.toggle()
                }
                .animation(.bouncy, value: playerProfileModel.player.image)
            if expanded {
                LazyVGrid(columns: [.init(.adaptive(minimum: 80, maximum: 130))]) {
                    ForEach(possibleImages, id: \.self){image in
                        Button{
                            playerProfileModel.player.image = image
                        } label: {
                            Image(image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(.circle)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .top).combined(with: .scale))
            }
        }
        .animation(.bouncy, value: expanded)
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
