//
//  LoadingView.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI

struct LoadingView: View {
    @State private var trigger = CGFloat(0)
    
    var body: some View {
        Image(PlayerProfileModel.shared.player.image ?? Skin.cowboy.image)
            .resizable()
            .scaledToFit()
            .clipShape(.circle)
            .rotation3DEffect(.degrees(trigger*360), axis: (x: trigger, y: trigger, z: trigger))
            .onAppear{
                trigger += 1
            }
            .animation(.bouncy.repeatForever(), value: trigger)
            .frame(maxWidth: 300)
    }
}


#Preview {
    LoadingView()
        .border(.red)
        .frame(width: 400, height: 700)
        .modifier(PreviewModifier())
}

