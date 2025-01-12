//
//  Logger.swift
//  superghost
//
//  Created by Hannes Nagel on 9/4/24.
//

import Foundation
import os
import GameKit
@preconcurrency import UserNotifications
import SwiftUI
#if canImport(Aptabase)
import Aptabase
#endif

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

    static func trackEvent(_ eventName: String, with parameters: [String: Any] = [:]) {
#if canImport(Aptabase)
        Aptabase.shared.trackEvent(eventName, with: parameters)
#endif
    }

    static func appDidActivate() async {
        await analyzer.appDidActivate()
    }

    static func appDidDeactivate() async {
        await analyzer.appDidDeactivate()
    }
    @MainActor
    static func checkForNotificationStatusChange(onDeny: (@Sendable () -> Void)? = nil) async {
        await analyzer.checkForNotificationStatusChange(onDeny: onDeny)
    }
    @MainActor
    static private let analyzer = Analyzer()

    actor Analyzer {
        @AppStorage("notificationsEnabled") private var notificationsEnabled = "not determined"
        @AppStorage("osVersion") private var osVersion = "undetermined"

        @CloudStorage("isPayingSuperghost") private var isPayingSuperghost = false

        @CloudStorage("timeSpentInGhost") private var timeSpentInGhost = 0.0//in minutes
        private var activated : Date?


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
                Logger.trackEvent("notification_status_change", with: ["notification_status": newNotificationsEnabled])
                if settings.authorizationStatus == .denied {
                    onDeny?()
                }
            }
        }
        func appDidActivate() {
            Logger.trackEvent("app_launch")
            activated = .now
        }
        func appDidDeactivate() async {
            Logger.trackEvent("app_closed")
            if let activated {
                await MainActor.run {
                    timeSpentInGhost += (Date.now.timeIntervalSince(activated)/60)
                }
                self.activated = nil
            }
        }
    }
}
