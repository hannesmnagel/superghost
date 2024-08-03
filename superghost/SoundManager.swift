//
//  SoundManager.swift
//  superghost
//
//  Created by Hannes Nagel on 8/3/24.
//

import SwiftUI
import AVFoundation

class SoundManager{
    @AppStorage("volume") private var volume = 1.0

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

    func play(_ sound: Sound, loop: Bool) throws {
        guard let string = Bundle.main.path(forResource: sound.rawValue, ofType: "mp3"),
              let url = URL(string: string)
        else {
            throw SoundManagerError.couldntFindFile
        }
        try setActive()
        let player = try AVAudioPlayer(contentsOf: url)
        players[sound] = player
        player.prepareToPlay()
        player.setVolume(Float(volume), fadeDuration: 1)
        player.play()
        player.numberOfLoops = loop ? -1 : 0
    }
    enum Sound: String {
        case ambient, laughingGhost, scream
    }
}
enum SoundManagerError: Error {
    case couldntFindFile
}
