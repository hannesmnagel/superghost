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
                if settings.authorizationStatus == .denied {
                    onDeny?()
                }
            }
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
    }
}
