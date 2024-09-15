//
//  Logger.swift
//  superghost
//
//  Created by Hannes Nagel on 9/4/24.
//

import Foundation
import os
import GameKit

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
        
        func appDidActivate() {
            activated = .now
        }
        func appDidDeactivate() {
            if let activated {
                timeSpentInGhost += (Date.now.timeIntervalSince(activated)/60)
            }
            uploadStats()
        }
        
        struct Event: Codable {
            let userId: String
            let eventName: String
            let timestamp: Date
        }
        
        func uploadStats(){
#if !os(macOS)
            remoteLog("stats|timeInGhost|\(Int(timeSpentInGhost))")
#endif
            remoteLog("stats|osVersion|\(ProcessInfo.processInfo.operatingSystemVersionString)")
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
    }
}
