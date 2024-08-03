//
//  SoundManager.swift
//  superghost
//
//  Created by Hannes Nagel on 8/3/24.
//

import Foundation
import AVFoundation

class SoundManager{
    private var players = [Sound:AVAudioPlayer]()

    private init(){}

    static let shared = SoundManager()

    func play(_ sound: Sound, loop: Bool) throws {
        guard let string = Bundle.main.path(forResource: sound.rawValue, ofType: "mp3"),
              let url = URL(string: string)
        else {
            throw SoundManagerError.couldntFindFile
        }
        try AVAudioSession.sharedInstance().setActive(true)
        try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        let player = try AVAudioPlayer(contentsOf: url)
        players[sound] = player
        player.prepareToPlay()
        player.setVolume(1, fadeDuration: 1)
        player.play()
        player.numberOfLoops = loop ? -1 : 1
    }
    enum Sound: String {
        case ambient, laughingGhost, scream
    }
}
enum SoundManagerError: Error {
    case couldntFindFile
}
