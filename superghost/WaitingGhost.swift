//
//  WaitingGhost.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI

struct WaitingGhost: View {
    let date = Date()
    
    var body: some View {
#if !os(macOS)
        if #available(iOS 17.0, macOS 14.0, *) {
            Video("waitingGhost")
                .notUpdating()
                .padding()
                .visualEffect { content, geo in
                    content
                        .offset(y: -geo.frame(in: .scrollView).minY*0.8 + min(30, geo.size.height/2))
                        .scaleEffect(0.8+geo.frame(in: .scrollView).minY/1000)
                }
                .notUpdating()
        } else {
            Video("waitingGhost")
                .notUpdating()
                .padding()
        }
#else
        VStack{}.frame(height: 100)
#endif
    }
}

#Preview {
    WaitingGhost()
        .modifier(PreviewModifier())
}

import AVKit

struct Video: View {
    private var player: AVQueuePlayer
    private var playerLooper: AVPlayerLooper
    @Environment(\.scenePhase) var scenePhase

    init(_ named: String) {
        let url = Bundle.main.resourceURL!.appending(path: "\(named).mov")
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        player = AVQueuePlayer(playerItem: item)
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
#if !os(macOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
#endif
    }

    var body: some View {
        VideoPlayer(player: player)
            .aspectRatio(contentMode: .fill)
            .disabled(true)
            .onChange(of: scenePhase){_, newValue in
                if newValue == .active{
                    player.play()
                }
            }
    }
}
