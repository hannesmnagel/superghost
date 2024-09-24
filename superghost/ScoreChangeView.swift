//
//  ScoreChangeView.swift
//  superghost
//
//  Created by Melanie Nagel   on 9/24/24.
//

import SwiftUI

struct ScoreChangeView: View {
    @CloudStorage("score") private var score = 1000

    var body: some View {
        let transition : ContentTransition =
        if #available(iOS 17.0, macOS 14.0, *){
            .numericText(value: Double(score))
        } else {
            .numericText()
        }
        Group{
            Text(score, format: .number) + Text(" XP")
        }
            .font(.system(size: 70))
            .contentTransition(transition)
    }
}
#Preview{
    ScoreChangeView()
        .task{
            try? await Task.sleep(for: .seconds(1))
            await MessageModel.shared.changeScore(by: Bool.random() ? 10 : -10)
        }
}
