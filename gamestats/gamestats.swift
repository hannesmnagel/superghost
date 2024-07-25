//
//  gamestats.swift
//  gamestats
//
//  Created by Hannes Nagel on 7/16/24.
//

import WidgetKit
import SwiftUI
import SwiftData

struct Provider: AppIntentTimelineProvider {
    @CloudStorage("isSuperghost") private var isSuperghost = false
    @CloudStorage("winningRate") private var winningRate = 0.0
    @CloudStorage("winningStreak") private var winningStreak = 0
    @CloudStorage("wordToday") private var wordToday = "-----"
    @CloudStorage("winsToday") private var winsToday = 0


    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(text: "Placeholder", configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let config = configuration.configuration
        let string = {
            switch config {
            case .rate:
                winningRate.formatted(.percent.precision(.fractionLength(0)))
            case .streak:
                winningStreak.formatted(.number.precision(.fractionLength(0)))
            case .word:
                wordToday
            case .winsToday:
                winsToday.formatted(.number.precision(.fractionLength(0)))
            }
        }()
        return SimpleEntry(text: string, configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let string = {
            switch configuration.configuration {
            case .rate:
                winningRate.formatted(.percent.precision(.fractionLength(0)))
            case .streak:
                winningStreak.formatted(.number.precision(.fractionLength(0)))
            case .word:
                wordToday
            case .winsToday:
                winsToday.formatted(.number.precision(.fractionLength(0)))
            }
        }()
        let entry = SimpleEntry(text: string, configuration: configuration)

        return Timeline(entries: [entry], policy: .after(.now + 100))
    }

    func recommendations() -> [AppIntentRecommendation<ConfigurationAppIntent>] {
        // Create an array with all the preconfigured widgets to show.
        [
            AppIntentRecommendation(intent: .rate, description: "View Your Winning Rate"),
            AppIntentRecommendation(intent: .streak, description: "View Your Winning Streak"),
            AppIntentRecommendation(intent: .winsToday, description: "View Your Wins Today"),
            AppIntentRecommendation(intent: .word, description: "See Your Progress Today")
        ]
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date = Date()
    let text: String
    let configuration: ConfigurationAppIntent
}

@MainActor
struct WatchComplicationEntryView : View {
    var entry: Provider.Entry


    var body: some View {
        ZStack {
            VStack{
                Text(entry.text)
                    .font(.system(size: entry.configuration.configuration == .word ? 10 : 12).bold())
                subtext
                    .font(.system(size: 8))
            }
        }
        .multilineTextAlignment(.center)

    }
    var subtext: Text {
        let representation = Configuration.caseDisplayRepresentations[entry.configuration.configuration]
        return Text(representation?.title ?? "")
    }
}

@main
struct WatchComplication: Widget {
    let kind: String = "Watch Complication"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            WatchComplicationEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {

    fileprivate static var rate: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.configuration = .rate
        return intent
    }

    fileprivate static var streak: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.configuration = .streak
        return intent
    }
    fileprivate static var winsToday: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.configuration = .winsToday
        return intent
    }

    fileprivate static var word: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.configuration = .word
        return intent
    }
}

#Preview(as: .accessoryRectangular) {
    WatchComplication()
} timeline: {
    SimpleEntry(text: "Rate", configuration: .rate)
    SimpleEntry(text: "Streak", configuration: .streak)
    SimpleEntry(text: "Wins", configuration: .winsToday)
    SimpleEntry(text: "Word", configuration: .word)
}
