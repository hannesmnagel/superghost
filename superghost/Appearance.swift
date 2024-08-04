//
//  Appearance.swift
//  superghost
//
//  Created by Hannes Nagel on 7/2/24.
//

import SwiftUI

private enum OS{
    case watchOS, iOS, macOS, visionOS
}
#if os(watchOS)
private let os = OS.watchOS
#elseif os(iOS)
private let os = OS.iOS
#elseif os(macOS)
private let os = OS.macOS
#elseif os(visionOS)
private let os = OS.visionOS
#endif

class AppearanceManager {
    private init(){}

    static let hostGame: Font = os == .watchOS ? .headline : .largeTitle
    static let startGame: Font = os == .watchOS ? .title : .largeTitle
    static let howToPlayTitle: Font = os == .watchOS ? .title2.bold() : .largeTitle.bold()
    static let trialEndsIn: Font = os == .watchOS ? .caption : .subheadline
    static let instructions: Font = .headline
    static let buttonsInSettings: Font = .body
    static let quitGame: Font = os == .watchOS ? .headline : .title
    static let wordInGame: Font = .headline
    static let letterPicker: Font = .headline
    static let statsLabel: Font = .footnote
    static let statsValue: Font = os == .watchOS ? .headline : .title
    static let settingsButton: Font = .body
    static let startUpSuperghost: Font = os == .watchOS ? .title : .largeTitle
    static let startUpSuperghostTapToPlay: Font = os == .watchOS ? .headline : .subheadline
    static let youWonOrLost: Font = os == .watchOS ? .title.bold() : .largeTitle.bold()
    static let youWonOrLostSubtitle: Font = os == .watchOS ? .subheadline : .headline
    static let synonyms: Font = .footnote
    static let definitions: Font = .body
    static let wordInDefinitionView: Font = os == .watchOS ? .title.bold() : .largeTitle.bold()
    static let leaderboardTitle: Font = os == .watchOS ? .title3.bold() : .title.bold()
    static let playerViewTitle: Font = os == .watchOS ? .title.bold() : .largeTitle.bold()

    struct QuitRematch: ButtonStyle {
        let isPrimary: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.horizontal)
                .padding()
                .background(isPrimary ? Color.accent : .clear)
                .background(isPrimary ? Material.thick : .thin)
                .clipShape(.capsule)
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
        }
    }
    struct StartGame: ButtonStyle {
        @Environment(\.isEnabled) var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(isEnabled ? .white : .secondary)
                .padding(.horizontal)
                .padding()
                .background(isEnabled ? .accent : .accent.opacity(0.5))
                .background(Material.thick)
                .clipShape(.capsule)
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .font(AppearanceManager.startGame)
        }
    }
    struct HostGame: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(.white)
                .padding(.horizontal)
                .padding()
                .background(Material.thin)
                .clipShape(.capsule)
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .font(AppearanceManager.hostGame)
        }
    }
}
