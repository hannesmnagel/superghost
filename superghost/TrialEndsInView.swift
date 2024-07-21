//
//  TrialEndsInView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/21/24.
//

import SwiftUI

struct TrialEndsInView: View {
    let days: Int
    @EnvironmentObject var viewModel: GameViewModel

    var body: some View {
        Group{
            Text("Trial ends in \(days, format: .number) days. \n")
                .foregroundStyle(.orange)
                .font(ApearanceManager.headline) + Text("Upgrade now!")
                .foregroundStyle(.accent)
                .font(.subheadline)
                .underline()
        }.onTapGesture {
            viewModel.showPaywall = true
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
    }
}

#Preview {
    TrialEndsInView(days: 2)
}
