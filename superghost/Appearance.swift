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

@MainActor
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
             green = "AppIcon.green"
    }

    private init(){
        appIcon = .init(rawValue: UserDefaults.standard.string(forKey: "appIcon") ?? AppIcon.standard.rawValue) ?? .standard
    }

    static let hostGame: Font = .largeTitle
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
    static let startUpSuperghostTapToPlay: Font = .subheadline
    static let youWonOrLost: Font = .largeTitle.bold()
    static let youWonOrLostSubtitle: Font = .headline
    static let synonyms: Font = .footnote
    static let definitions: Font = .body
    static let wordInDefinitionView: Font = .largeTitle.bold()
    static let leaderboardTitle: Font = .title.bold()
    static let playerViewTitle: Font = .largeTitle.bold()

    struct FullWidthButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) var isEnabled
        let isSecondary: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .buttonStyle(.plain)
                .foregroundStyle(isEnabled ? (isSecondary ? .white : .black) : .secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSecondary ? .clear : (isEnabled ? .accent : .accent.opacity(0.5)))
                .background(isSecondary ? .thin : Material.thick)
                .clipShape(.capsule)
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
        }
    }
}

