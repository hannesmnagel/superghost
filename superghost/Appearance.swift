//
//  Appearance.swift
//  superghost
//
//  Created by Hannes Nagel on 7/2/24.
//

import SwiftUI

private enum OS{
    case iOS, macOS, visionOS
}
#if os(iOS)
private let os = OS.iOS
#elseif os(macOS)
private let os = OS.macOS
#elseif os(visionOS)
private let os = OS.visionOS
#endif

class AppearanceManager {
    @Published var appIcon: AppIcon = .standard {
        didSet {
            UserDefaults.standard.set(appIcon.rawValue, forKey: "appIcon")
        }
    }

    static let shared = AppearanceManager()

    enum AppIcon: String, CaseIterable{
        case standard = "AppIcon.standard",
             blue = "AppIcon.blue",
             blueSuper = "AppIcon.blue.super.blue",
             gray = "AppIcon.gray",
             graySuper = "AppIcon.gray.super.gray",
             yellow = "AppIcon.yellow",
             yellowSuper = "AppIcon.yellow.super.yellow",
             yellowSuperPuple = "AppIcon.yellow.super.purple",
             purple = "AppIcon.purple",
             purpleSuperPurple = "AppIcon.purple.super.purple",
             red = "AppIcon.red",
             redSuper = "AppIcon.red.super.red",
             redSuperGreen = "AppIcon.red.super.green"
    }

    private init(){
        appIcon = .init(rawValue: UserDefaults.standard.string(forKey: "appIcon") ?? AppIcon.standard.rawValue) ?? .standard
    }

    static let hostGame: Font = .largeTitle
    static let startGame: Font = .largeTitle
    static let howToPlayTitle: Font = .largeTitle.bold()
    static let trialEndsIn: Font = .subheadline
    static let instructions: Font = .headline
    static let buttonsInSettings: Font = .body
    static let quitGame: Font = .title
    static let wordInGame: Font = .headline
    static let letterPicker: Font = .headline
    static let statsLabel: Font = .footnote
    static let statsValue: Font = .title
    static let settingsButton: Font = .body
    static let startUpSuperghost: Font = .largeTitle
    static let startUpSuperghostTapToPlay: Font = .subheadline
    static let youWonOrLost: Font = .largeTitle.bold()
    static let youWonOrLostSubtitle: Font = .headline
    static let synonyms: Font = .footnote
    static let definitions: Font = .body
    static let wordInDefinitionView: Font = .largeTitle.bold()
    static let leaderboardTitle: Font = .title.bold()
    static let playerViewTitle: Font = .largeTitle.bold()

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
                .shadow(radius: 2)
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
    struct FullWidthButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) var isEnabled
        let isSecondary: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .shadow(radius: 2)
                .foregroundStyle(isEnabled ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSecondary ? .clear : (isEnabled ? .accent : .accent.opacity(0.5)))
                .background(isSecondary ? .thin : Material.thick)
                .clipShape(.capsule)
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
        }
    }
}
