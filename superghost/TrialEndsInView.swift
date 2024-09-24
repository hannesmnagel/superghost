//
//  TrialEndsInView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/21/24.
//

import SwiftUI

struct TrialEndsInView: View {
    let days: Int

    var body: some View {
        Group{
            Text("Superghost for \(days) more days")
                .foregroundStyle(.orange)
                .font(AppearanceManager.trialEndsIn)
                .underline()
        }.onTapGesture {
            UserDefaults.standard.set(true, forKey: "showingPaywall")
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
    }
}

#Preview {
    TrialEndsInView(days: 2)
}
