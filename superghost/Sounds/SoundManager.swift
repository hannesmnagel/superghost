//
//  SoundManager.swift
//  superghost
//
//  Created by Hannes Nagel on 8/3/24.
//

import SwiftUI
import AVFoundation
import CoreHaptics

actor SoundManager{
    let hapticsEngine = try? CHHapticEngine()

    private var players = [Sound:AVAudioPlayer]()

    private init(){}

    static let shared = SoundManager()

    func setVolume(_ volume: Double) {
        players.values.forEach { player in
            player.volume = Float(volume)
            player.play()
        }
    }

    func setActive() throws {
#if !os(macOS)
        if !AVAudioSession.sharedInstance().isOtherAudioPlaying{
            try AVAudioSession.sharedInstance().setActive(true)
        }
        try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
#endif
    }

    func play(_ sound: Sound, loop: Bool) async throws {
        guard let string = Bundle.main.path(forResource: sound.rawValue, ofType: "mp4"),
              let url = URL(string: string)
        else {
            throw SoundManagerError.couldntFindFile
        }
        try setActive()
        let player = try AVAudioPlayer(contentsOf: url)
        players[sound] = player
        player.prepareToPlay()
        player.volume = 1
#if !os(macOS) && !os(macOS)
        if let ahap = sound.ahap{
            await withCheckedContinuation{con in
                hapticsEngine?.start{_ in con.resume()}
            }
            let url = URL(fileURLWithPath: Bundle.main.path(forResource: ahap, ofType: nil)!)
            try? hapticsEngine?.playPattern(from: url)
        }
#endif
        player.play()
        player.numberOfLoops = loop ? -1 : 0
    }
    enum Sound: String {
        case won, lost, gameStart
        var ahap: String? {
            switch self {
            case .won:
                "won.ahap"
            case .gameStart:
                "gameStart.ahap"
                
            case .lost:
                "lost.ahap"
            }
        }
    }
}
enum SoundManagerError: Error {
    case couldntFindFile
}
