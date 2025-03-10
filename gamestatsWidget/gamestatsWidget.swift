//
//  gamestatsWidget.swift
//  gamestatsWidget
//
//  Created by Hannes Nagel on 7/16/24.
//

import WidgetKit
import SwiftUI
import GameKit

import os

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
            case .leaderboard:
                return ""
            }
        }()
        if !context.isPreview {
            Task.detached{
                NSUbiquitousKeyValueStore.default.set(Date().ISO8601Format(), forKey: "lastWidgetUpdate")
                try? await reportAchievement(.widgetAdd, percent: 100)
            }
        }
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
            case .leaderboard:
                return ""
            }
        }()
        let entry = SimpleEntry(text: string, configuration: configuration)
        if !context.isPreview {
            Task.detached{
                NSUbiquitousKeyValueStore.default.set(Date().ISO8601Format(), forKey: "lastWidgetUpdate")
                try? await reportAchievement(.widgetAdd, percent: 100)
            }
        }
        
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
    @Environment(\.widgetFamily) var widgetFamily
    @CloudStorage("leaderboardWidgetData") var leaderboardData = [LeaderboardEntry]()


    var body: some View {
        if entry.configuration.configuration == .leaderboard {
            if leaderboardData.isEmpty {
                Text("Tap to load the data")
            } else {
                Text("Leaderboard")
                    .font(.subheadline)
                    .bold()
                inlineLeaderboard(entries: leaderboardData)
                    .font(.caption)
                Group{
                    Text("You are ") + Text(leaderboardData.first{$0.isLocalPlayer}?.rank.ordinalString() ?? "not on the leaderboard")
                }
                .font(.caption2)
            }
        } else {
            ZStack {
                Image(widgetFamily == .systemSmall ? .ghost512 : .ghost1024)
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
    }
    var subtext: Text {
        let representation = Configuration.caseDisplayRepresentations[entry.configuration.configuration]
        return Text(representation?.title ?? "")
    }

    @ViewBuilder
    func inlineLeaderboard(entries: [LeaderboardEntry]) -> some View {
        ForEach(entries, id: \.self) { entry in
            HStack{
                Text(entry.name)
                Spacer()
                Text(entry.score)
            }
            .padding(.vertical, 5)

            .padding(.horizontal, 3)
            .contentShape(.rect)
            .background(entry.isLocalPlayer ? .thinMaterial : .ultraThinMaterial)
            .background(entry.isLocalPlayer ? .accent : .clear)
            .clipShape(.rect(cornerRadius: 10))
        }
    }
}

struct LeaderboardEntry : Hashable, Codable {
    let rank: Int
    let name: String
    let score: String
    let isLocalPlayer: Bool
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
