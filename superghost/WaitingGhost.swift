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
        TimelineView(.animation){context in

            let timeInterval = context.date.timeIntervalSince(date)
            let sineValue = sin(timeInterval * .pi / 2) // Adjust the frequency of the sine wave
            let cosineValue = cos(timeInterval * .pi / 2)

            let offsetX = CGFloat(sineValue)*30
            let rotationAngle = atan2(cosineValue, 1.0) * 20 / .pi


            Video("waitingGhost")
                .visualEffect { content, geo in
                    content
                        .offset(x: offsetX)
                        .rotationEffect(.degrees(rotationAngle))
                        .offset(y: -geo.frame(in: .scrollView).minY*0.8 + min(30, geo.size.height/2))
                        .scaleEffect(0.8+geo.frame(in: .scrollView).minY/1000)
                }
        }
        .notUpdating()
    }
}

#Preview {
    WaitingGhost()
        .modifier(PreviewModifier())
}

import AVKit

struct Video: View {
    private let player: AVPlayer

    init(_ named: String) {
        let url = Bundle.main.resourceURL!.appending(path: "\(named).mov")
        self.player = AVPlayer(url: url)
        self.player.isMuted = true
#if !os(macOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
#endif
    }

    var body: some View {
        AVPlayerControllerRepresented(player: player)
            .aspectRatio(contentMode: .fill)
            .disabled(true)
            .onAppear {
                self.player.play()
                NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main) { _ in
                    self.player.seek(to: .zero)
                    self.player.play()
                }
            }
    }
}
#if os(macOS)
struct AVPlayerControllerRepresented : NSViewRepresentable {
    var player : AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {

    }
}
#else
struct AVPlayerControllerRepresented: UIViewControllerRepresentable {
    var player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.showsPlaybackControls = false // Hide playback controls
        return playerViewController
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
    }
}
#endif
