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

        if #available(iOS 17.0, *) {
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
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
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
                Task{
                    await playAfter500ms()
                }
            }
    }
    func playAfter500ms() async {
        try? await Task.sleep(for: .milliseconds(500))
        player.play()
        Task{
            await playAfter500ms()
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
