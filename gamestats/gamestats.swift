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
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

    func recommendations() -> [AppIntentRecommendation<ConfigurationAppIntent>] {
        // Create an array with all the preconfigured widgets to show.
        [
            AppIntentRecommendation(intent: .icon, description: "Quickly launch Superghost"),
            AppIntentRecommendation(intent: .rate, description: "View Your Winning Rate"),
            AppIntentRecommendation(intent: .streak, description: "View Your Winning Streak"),
            AppIntentRecommendation(intent: .winsToday, description: "View Your Wins Today"),
            AppIntentRecommendation(intent: .word, description: "See Your Progress Today")
        ]
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

@MainActor
struct WatchComplicationEntryView : View {
    var entry: Provider.Entry

    @AppStorage("isSuperghost", store: UserDefaults(suiteName: "group.com.nagel.superghost") ?? .standard) private var isSuperghost = false
    let games = try! ModelContainer(for: GameStat.self).mainContext.fetch(
        FetchDescriptor<GameStat>()
    )

    var body: some View {
        let gamesToday = games.today
        let gamesLostToday = gamesToday.lost
        let word = isSuperghost ? "SUPERGHOST" : "GHOST"
        let lettersOfWord = word.prefix(gamesLostToday.count)
        let placeHolders = Array(repeating: "-", count: word.count).joined()
        let actualPlaceHolders = placeHolders.prefix(word.count-gamesLostToday.count)
        let wordToday = lettersOfWord.appending(actualPlaceHolders)
        VStack {
            Group{
                let config = entry.configuration.configuration
                let winningRateText = config == .rate ? Text(games.winningRate, format: .percent.precision(.fractionLength(0))) : nil
                let winningStreakText = config == .streak ? Text(games.winningStreak, format: .number.precision(.fractionLength(0))) : nil
                let wordText = config == .word ? Text(wordToday) : nil
                let winsTodayText = config == .winsToday ? Text(games.today.won.count, format: .number.precision(.fractionLength(0))) : nil

                if let text = winningRateText ?? winningStreakText ?? wordText ?? winsTodayText {
                    text
                    subtext
                }
                if config == .icon {
                    Image(.ghost)
                        .resizable()
                        .scaledToFit()
                }
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
        .backgroundTask(.snapshot) { <#D#> in
            <#code#>
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var icon: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.configuration = .icon
        return intent
    }

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
    SimpleEntry(date: .now, configuration: .rate)
    SimpleEntry(date: .now, configuration: .streak)
    SimpleEntry(date: .now, configuration: .winsToday)
    SimpleEntry(date: .now, configuration: .word)
}
