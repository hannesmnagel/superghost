//
//  AppIntent.swift
//  gamestatsWidget
//
//  Created by Hannes Nagel on 7/16/24.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Configuration"
    static let description = IntentDescription("This is an example widget.")

    // An example configurable parameter.
    @Parameter(title: "Configuration", default: Configuration.rate)
    var configuration: Configuration
}

enum Configuration: String, Codable, Sendable, AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        .init(name: "Configure this complication")
    }

    static var caseDisplayRepresentations: [Configuration : DisplayRepresentation ] {
        [
            .rate : .init(title: "Win Rate", subtitle: "Display Your current win rate"),
            .streak : .init(title: "Win Streak", subtitle: "Display Your current win streak"),
            .word : .init(title: "Word Today", subtitle: "Display Your Progress today"),
            .winsToday : .init(title: "Wins Today", subtitle: "Display Your Wins today"),
            .icon : .init(title: "Superghost Icon", subtitle: "Launch Superghost")
        ]
    }
    case rate, streak, word, winsToday, icon
}
