//
//  NotUpdating.swift
//  superghost
//
//  Created by Hannes Nagel on 7/26/24.
//

import SwiftUI

extension View{
    @ViewBuilder
    func notUpdating() -> some View {
        NotUpdatingView{
            self
        }
    }
}
private struct NotUpdatingView<Content: View>: View, Equatable {
    @ViewBuilder let content: () -> Content

    var body: some View{
        content()
    }
    static func == (lhs: NotUpdatingView, rhs: NotUpdatingView) -> Bool {true}
}
