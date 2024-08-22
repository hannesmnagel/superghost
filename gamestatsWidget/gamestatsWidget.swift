//
//  gamestatsWidget.swift
//  gamestatsWidget
//
//  Created by Hannes Nagel on 7/16/24.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(text: "Placeholder", configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let string = {
            switch configuration.configuration {
            case .rate:
                if let data = NSUbiquitousKeyValueStore.default.data(forKey: "winRate"),
                   let newValue = try? JSONDecoder().decode(Double.self, from: data){
                    return newValue.formatted(.percent.precision(.fractionLength(0)))
                }
                else {
                    return "Ups, sth went wrong."
                }
            case .streak:
                if let data = NSUbiquitousKeyValueStore.default.data(forKey: "winStreak"),
                   let streak = try? JSONDecoder().decode(Int.self, from: data){
                    return streak.formatted(.number.precision(.fractionLength(0)))
                } else {
                    return "Ups, sth went wrong."
                }
            case .word:
                if let data = NSUbiquitousKeyValueStore.default.data(forKey: "wordToday"),
                   let wordToday = try? JSONDecoder().decode(String.self, from: data){
                    return wordToday
                } else {
                    return "Ups, sth went wrong."
                }
            case .winsToday:
                if let data = NSUbiquitousKeyValueStore.default.data(forKey: "winsToday"),
                   let winsToday = try? JSONDecoder().decode(Int.self, from: data){
                    return winsToday.formatted(.number.precision(.fractionLength(0)))
                } else {
                    return "Ups, sth went wrong."
                }
            case .icon:
                return "Icon"
            }
        }()
        return SimpleEntry(text: string, configuration: configuration)

    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let string = {
            switch configuration.configuration {
            case .rate:
                if let data = NSUbiquitousKeyValueStore.default.data(forKey: "winRate"),
                   let newValue = try? JSONDecoder().decode(Double.self, from: data){
                    return newValue.formatted(.percent.precision(.fractionLength(0)))
                }
                else {
                    return "Ups, sth went wrong."
                }
            case .streak:
                if let data = NSUbiquitousKeyValueStore.default.data(forKey: "winStreak"),
                   let streak = try? JSONDecoder().decode(Int.self, from: data){
                    return streak.formatted(.number.precision(.fractionLength(0)))
                } else {
                    return "Ups, sth went wrong."
                }
            case .word:
                if let data = NSUbiquitousKeyValueStore.default.data(forKey: "wordToday"),
                   let wordToday = try? JSONDecoder().decode(String.self, from: data){
                    return wordToday
                } else {
                    return "Ups, sth went wrong."
                }
            case .winsToday:
                if let data = NSUbiquitousKeyValueStore.default.data(forKey: "winsToday"),
                   let winsToday = try? JSONDecoder().decode(Int.self, from: data){
                    return winsToday.formatted(.number.precision(.fractionLength(0)))
                } else {
                    return "Ups, sth went wrong."
                }
            case .icon:
                return "Icon"
            }
        }()
        let entry = SimpleEntry(text: string, configuration: configuration)

        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60)))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date = Date()
    let text: String
    let configuration: ConfigurationAppIntent
}


struct GamestatsWidgetEntryView : View {
    var entry: Provider.Entry


    var body: some View {
        ZStack {
            Image(.ghost)
                .resizable()
                .scaledToFit()
                .scaleEffect(1.4)
                .brightness(-0.5)
            if entry.configuration.configuration != .icon {
                VStack{
                    Spacer()
                    Text(entry.text)
                        .font(.system(size: entry.configuration.configuration == .word ? 27 : 40).bold())
                    subtext
                        .font(.subheadline)
                }
                .foregroundStyle(.white)
            }
        }
        .multilineTextAlignment(.center)

    }
    var subtext: Text {
        let representation = Configuration.caseDisplayRepresentations[entry.configuration.configuration]
        return Text(representation?.title ?? "")
    }
}

struct gamestatsWidget: Widget {
    let kind: String = "Gamestats Widget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            GamestatsWidgetEntryView(entry: entry)
                .containerBackground(.black, for: .widget)
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

#Preview(as: .systemSmall) {
    gamestatsWidget()
} timeline: {
    SimpleEntry(text: "Rate", configuration: .rate)
    SimpleEntry(text: "Streak", configuration: .streak)
    SimpleEntry(text: "Wins", configuration: .winsToday)
    SimpleEntry(text: "Word", configuration: .word)
}
