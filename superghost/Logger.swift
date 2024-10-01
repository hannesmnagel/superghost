//
//  Logger.swift
//  superghost
//
//  Created by Hannes Nagel on 9/4/24.
//

import Foundation
import os
import GameKit
import UserNotifications
import SwiftUI

final class Logger {

    private static let subsystem = "com.nagel.superghost"
    enum Category: String {
        case achievements, score, appRefresh, userInteraction, subscription, game, general
    }
    static let achievements = os.Logger(subsystem: subsystem, category: Category.achievements.rawValue)
    static let score = os.Logger(subsystem: subsystem, category: Category.score.rawValue)
    static let appRefresh = os.Logger(subsystem: subsystem, category: Category.appRefresh.rawValue)
    static let userInteraction = os.Logger(subsystem: subsystem, category: Category.userInteraction.rawValue)
    static let subscription = os.Logger(subsystem: subsystem, category: Category.subscription.rawValue)
    static let game = os.Logger(subsystem: subsystem, category: Category.game.rawValue)
    static let general = os.Logger(subsystem: subsystem, category: Category.general.rawValue)

    static func remoteLog(_ event: Event){
        analyzer.remoteLog(event)
    }
    static func remoteLog(_ stat: UserStatChange){
        analyzer.remoteLog(stat)
    }

    static func appDidActivate() {
        analyzer.appDidActivate()
    }
    static func appDidDeactivate() {
        analyzer.appDidDeactivate()
    }
    static func checkForNotificationStatusChange(onDeny: (()->Void)? = nil) async {
        await analyzer.checkForNotificationStatusChange(onDeny: onDeny)
    }
    static private let analyzer = Analyzer()

    final class Analyzer {
        @AppStorage("anonymousUserID") private var anonymousUserID = UUID().uuidString
        @AppStorage("notificationsEnabled") private var notificationsEnabled = "not determined"
        @AppStorage("osVersion") private var osVersion = "undetermined"

        @CloudStorage("isSuperghost") private var isSuperghost = false
        @CloudStorage("paywallViews") private var paywallViews = 0

        @CloudStorage("timeSpentInGhost") private var timeSpentInGhost = 0.0//in minutes
        private var activated : Date?


        init(){
            self.anonymousUserID = self.anonymousUserID
        }

        func checkForNotificationStatusChange(onDeny: (()->Void)? = nil) async {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let newNotificationsEnabled = switch settings.authorizationStatus {
            case .notDetermined:
                "not detemined"
            case .authorized:
                "authorized"
            case .denied:
                "denied"
            default:
                "unknown"
            }
            if newNotificationsEnabled != notificationsEnabled {
                remoteLog(.notificationsEnabled(enabled: settings.authorizationStatus == .authorized))
                if settings.authorizationStatus == .denied {
                    onDeny?()
                }
            }
        }
        func checkForOSChange() {
#if os(iOS)
            let os = "iOS - " + ProcessInfo.processInfo.operatingSystemVersion.majorVersion.formatted()
#elseif os(macOS)
            let os = "macOS - " + ProcessInfo.processInfo.operatingSystemVersion.majorVersion.formatted()
#elseif os(visionOS)
            let os = "visionOS" + ProcessInfo.processInfo.operatingSystemVersion.majorVersion.formatted()
#endif
            if osVersion != os {
                osVersion = os
                remoteLog(.osVersion(string: os))
            }

        }
        func uploadTimeSpentInGhost(){
            remoteLog(.totalTimeSpent(seconds: Int(timeSpentInGhost*60)))
        }
        func appDidActivate() {
            activated = .now
        }
        func appDidDeactivate() {
            if let activated {
                timeSpentInGhost += (Date.now.timeIntervalSince(activated)/60)
                self.activated = nil
            }
        }

        func remoteLog(_ event: Event){
            if event == .paywallViewed {
                paywallViews += 1
                remoteLog(.paywallViews(views: paywallViews))
            }
            Task{
                let url = URL(string: "https://hannesnagel.com/api/v2/analytics/events")!
                await send(event, to: url)
            }
        }
        func remoteLog(_ stat: UserStatChange){
            Task{
                let url = URL(string: "https://hannesnagel.com/api/v2/analytics/userStats")!
                await send(stat, to: url)
            }
        }
        func send(_ log: RemoteLoggable, to url: URL) async {
            do{
                // Convert Event to JSON data
                let codable = log.toLog(userId: UUID(uuidString: anonymousUserID)!)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(codable)

                // Create the URLRequest
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData

                // Perform the request
                let (_, response) = try await URLSession.shared.data(for: request)

                // Check for a valid response
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    Logger.general.error("Error sending remote log, status code: \((response as? HTTPURLResponse)?.statusCode ?? 0, privacy: .public)")
                    return
                }
            } catch {
                Logger.general.error("Error sending remote log: \(error, privacy: .public)")
            }
        }


    }
    enum UserStatChange: RemoteLoggable {
        case notificationsEnabled(enabled: Bool)
        case widgetInstalled(installed: Bool)
        case totalTimeSpent(seconds: Int)
        case paywallViews(views: Int)
        case subscriptionDate(date: Date)
        case osVersion(string: String)

        func toLog(userId: UUID) -> any Codable {
            struct UserStatsRequest: Codable {
                var userID: UUID
                var notificationsEnabled: Bool? // Optional, updates if provided
                var widgetInstalled: Bool? // Optional, updates if provided
                var totalTimeSpent: Int? // Optional, total time spent in seconds
                var paywallViews: Int? // Optional, total number of paywall views
                var subscriptionDate: Date? // Optional, date of subscription
                var osVersion: String? // Optional, OS version and model string
            }
            switch self {
            case .notificationsEnabled(let enabled):
                return UserStatsRequest(userID: userId, notificationsEnabled: enabled)
            case .widgetInstalled(let installed):
                return UserStatsRequest(userID: userId, widgetInstalled: installed)
            case .totalTimeSpent(let seconds):
                return UserStatsRequest(userID: userId, totalTimeSpent: seconds)
            case .paywallViews(let views):
                return UserStatsRequest(userID: userId, paywallViews: views)
            case .subscriptionDate(let date):
                return UserStatsRequest(userID: userId, subscriptionDate: date)
            case .osVersion(let string):
                return UserStatsRequest(userID: userId, osVersion: string)
            }
        }
    }
    enum Event: RemoteLoggable, Equatable {
        case gameLost(duration: Int)//in sec
        case gameWon(duration: Int)//in sec
        case gameCancelled(duration: Int)//in sec
        case widgetInstalled
        case notificationsEnable
        case paywallViewed
        case subscriptionStarted
        case messagesMove
        case joinedPrivateGame



        func toLog(userId: UUID) -> any Codable {

            enum EventType: String, Codable {
                case gameLost = "Game Lost"
                case gameWon = "Game Won"
                case gameCancelled = "Game Cancelled"
                case widgetInstalled = "Widget Installed"
                case notificationsEnabled = "Notifications Enabled"
                case paywallViewed = "Paywall Viewed"
                case subscriptionStarted = "Subscription Started"
                case messagesMove = "Messages Move"
                case joinedPrivateGame = "Joined Private Game"
            }

            let eventType : EventType = switch self {
            case .gameLost(_):
                    .gameLost
            case .gameWon(_):
                    .gameWon
            case .gameCancelled(_):
                    .gameCancelled
            case .widgetInstalled:
                    .widgetInstalled
            case .notificationsEnable:
                    .notificationsEnabled
            case .paywallViewed:
                    .paywallViewed
            case .subscriptionStarted:
                    .subscriptionStarted
            case .messagesMove:
                    .messagesMove
            case .joinedPrivateGame:
                    .joinedPrivateGame
            }

            struct EventRequest: Codable {
                var userID: UUID
                var eventType: EventType
                var duration: Int? // Duration of the event in seconds (optional)
            }

            let duration : Int? = switch self {
            case .gameLost(let duration), .gameWon(let duration), .gameCancelled(let duration):
                duration
            default:
                nil
            }
            let event = EventRequest(userID: userId, eventType: eventType, duration: duration)
            return event
        }
    }
    protocol RemoteLoggable {
        func toLog(userId: UUID) -> Codable
    }
}
