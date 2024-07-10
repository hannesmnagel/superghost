//
//  Appearance.swift
//  superghost
//
//  Created by Hannes Nagel on 7/2/24.
//

import SwiftUI

class ApearanceManager {
    #if os(watchOS)
    static let largeTitle = Font.title
    #else
    static let largeTitle = Font.largeTitle
    #endif
    static let title = Font.title2
    static let headline = Font.headline
    static let footnote = Font.footnote
    static let body = Font.body
}
