//
//  AppearingAnimationView.swift
//  superghost
//
//  Created by Hannes Nagel on 11/16/24.
//

import SwiftUI

struct AppearingAnimationView<Content: View>: View {
    let after: Int
    @ViewBuilder let content: (Bool) -> Content
    @State private var isTriggered = false

    init(after: Int = 1, @ViewBuilder content: @escaping (Bool) -> Content) {
        self.after = after
        self.content = content
    }

    var body: some View {
        let _ = Task{
            try? await Task.sleep(for: .seconds(after))
            withAnimation{
                isTriggered = true
            }
        }
        content(isTriggered)
    }
}

@available(iOS 18.0, *)
#Preview {
    AppearingAnimationView{trigger in
        Image(systemName: "arrow.left.circle.fill")
            .font(.largeTitle)
            .imageScale(.large)
            .offset(y: trigger ? -200 : 0)
    }
}
