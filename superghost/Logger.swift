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
    
    static func remoteLog(_ eventName: String) {
        analyzer.remoteLog(eventName)
    }
    
    static func appDidActivate() {
        analyzer.appDidActivate()
    }
    static func appDidDeactivate() {
        analyzer.appDidDeactivate()
    }
    static private let analyzer = Analyzer()
    
    private final class Analyzer {
        @CloudStorage("timeSpentInGhost") private var timeSpentInGhost = 0.0//in minutes
        private var activated : Date?
        private var notificationDelegate = NotificationDelegate()
        
        init(){
            UNUserNotificationCenter.current().delegate = self.notificationDelegate
        }
        
        func appDidActivate() {
            activated = .now
            uploadStats()
        }
        func appDidDeactivate() {
            if let activated {
                timeSpentInGhost += (Date.now.timeIntervalSince(activated)/60)
                self.activated = nil
            }
        }
        
        struct Event: Codable {
            let userId: String
            let eventName: String
            let timestamp: Date
        }
        
        func uploadStats(){
#if !os(macOS)
            remoteLog("stats|timeInGhost|\(Int(timeSpentInGhost/10)*10)")
#endif
            remoteLog("stats|osVersion|\(ProcessInfo.processInfo.operatingSystemVersionString)")
            if let data = NSUbiquitousKeyValueStore.default.data(forKey: "isSuperghost"),
               let isSuperghost = try? JSONDecoder().decode(Bool.self, from: data) {
                remoteLog("stats|isSuperghost|\(isSuperghost)")
            }
            if let data = NSUbiquitousKeyValueStore.default.data(forKey: "superghostTrialEnd"),
               let superghostTrialEnd = try? JSONDecoder().decode(Date.self, from: data) {
                let timeSinceTrialEnd = Date().timeIntervalSince(superghostTrialEnd)
                let daysSinceTrialEnd = timeSinceTrialEnd / (Calendar.current.dateInterval(of: .day, for: .now)?.duration ?? 1)
                remoteLog("stats|superghostTrialEnd|\(Int(-daysSinceTrialEnd))")
            }
            Task{
                let nots = await UNUserNotificationCenter.current().notificationSettings()
                let mappingDict : [UNAuthorizationStatus.RawValue : String] = [
                    UNAuthorizationStatus.notDetermined.rawValue : "notDetermined",
                    UNAuthorizationStatus.denied.rawValue : "denied",
                    UNAuthorizationStatus.authorized.rawValue : "authorized",
                    UNAuthorizationStatus.provisional.rawValue : "provisional",
                    UNAuthorizationStatus.ephemeral.rawValue : "ephemeral"
                ]
                remoteLog("stats|notifications|\(mappingDict[nots.authorizationStatus.rawValue] ?? "error: unknown status")")
            }
        }
        func remoteLog(_ eventName: String){
            Task{
                do {
                    let timeout = Date()
                    while !GKLocalPlayer.local.isAuthenticated,
                          timeout < .now + 10 {
                        try? await Task.sleep(for: .seconds(1))
                    }
                    let event = Event(userId: GKLocalPlayer.local.gamePlayerID, eventName: eventName, timestamp: Date())
                    let url = URL(string: "https://hannesnagel.com/api/v2/log")!
                    
                    // Convert Event to JSON data
                    let encoder = JSONEncoder()
                    print(encoder.dateEncodingStrategy)
                    encoder.dateEncodingStrategy = .iso8601
                    let jsonData = try encoder.encode(event)
                    
                    // Create the URLRequest
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = jsonData
                    
                    // Perform the request
                    let (_, response) = try await URLSession.shared.data(for: request)
                    
                    // Check for a valid response
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    } else {
                        Logger.general.error("Error sending remote log, status code: \((response as? HTTPURLResponse)?.statusCode ?? 0, privacy: .public)")
                    }
                } catch {
                    Logger.general.error("Error sending remote log: \(error, privacy: .public)")
                }
            }
        }
        
        final private class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
            func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
                if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                    Logger.remoteLog("Tapped notification")
                    let content = response.notification.request.content
                    Logger.userInteraction.info("Tapped notification \(content.title) content: \(content.body)")
                }
            }
        }
    }
}
