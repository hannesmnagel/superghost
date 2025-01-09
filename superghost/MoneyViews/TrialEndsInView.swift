//
//  TrialEndsInView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/21/24.
//

import SwiftUI

struct TrialEndsInView: View {
    @CloudStorage("showTrialEndsIn") private var showTrialEndsIn : Int? = nil

    var body: some View {
        if let showTrialEndsIn {
            Group{
                Text("Superghost for \(showTrialEndsIn) more days")
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
}

#Preview {
    TrialEndsInView()
}
