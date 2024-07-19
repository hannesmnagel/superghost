//
//  AppIntent.swift
//  gamestats
//
//  Created by Hannes Nagel on 7/16/24.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("This is an example widget.")

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
            .rate : .init(title: "Winning Rate", subtitle: "Display Your current winning rate"),
            .streak : .init(title: "Winning Streak", subtitle: "Display Your current winning streak"),
            .word : .init(title: "Word Today", subtitle: "Display Your Progress today"),
            .winsToday : .init(title: "Wins Today", subtitle: "Display Your Wins today")
        ]
    }
    case rate, streak, word, winsToday
}
