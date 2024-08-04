//
//  PreviewModifier.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI

struct PreviewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .fontDesign(.rounded)
            .environmentObject(GameViewModel())
    }
}
