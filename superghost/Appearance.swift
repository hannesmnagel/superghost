//
//  Appearance.swift
//  superghost
//
//  Created by Hannes Nagel on 7/2/24.
//

import SwiftUI

private enum OS{
    case watchOS, iOS, macOS, visionOS
}
#if os(watchOS)
private let os = OS.watchOS
#elseif os(iOS)
private let os = OS.iOS
#elseif os(macOS)
private let os = OS.macOS
#elseif os(visionOS)
private let os = OS.visionOS
#endif

class ApearanceManager {
    static let hostGame: Font = os == .watchOS ? .headline : .largeTitle
    static let startGame: Font = os == .watchOS ? .title : .largeTitle
    static let howToPlayTitle: Font = os == .watchOS ? .title2.bold() : .largeTitle.bold()
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
