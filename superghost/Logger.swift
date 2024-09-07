//
//  Logger.swift
//  superghost
//
//  Created by Hannes Nagel on 9/4/24.
//

import Foundation
import os

final class Logger {
    private static let subsystem = "com.nagel.superghost"
    enum Category: String {
        case achievements, score, appRefresh, userInteraction
    }
    static let achievements = os.Logger(subsystem: subsystem, category: Category.achievements.rawValue)
    static let score = os.Logger(subsystem: subsystem, category: Category.score.rawValue)
    static let appRefresh = os.Logger(subsystem: subsystem, category: Category.appRefresh.rawValue)
    static let userInteraction = os.Logger(subsystem: subsystem, category: Category.userInteraction.rawValue)
}
