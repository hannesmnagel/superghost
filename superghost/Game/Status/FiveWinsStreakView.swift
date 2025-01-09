//
//  FiveWinsStreakView.swift
//  superghost
//
//  Created by Hannes Nagel on 10/3/24.
//

import SwiftUI

struct FiveWinsStreakView: View {
    @AppStorage("showingFiveWinsStreak") private var showingFiveWinsStreak = false
    @CloudStorage("isPayingSuperghost") private var isPayingSuperghost = false
    @State private var animationTrigger = false
    
    var body: some View {
        Image(.ghostStars)
            .resizable()
            .scaledToFit()
            .clipShape(.rect(bottomLeadingRadius: 25, bottomTrailingRadius: 25))
            .ignoresSafeArea(edges: .top)
        Spacer()
        Text("Nice, FIVE wins in a row!")
            .multilineTextAlignment(.center)
            .font(.largeTitle.bold())
        if isPayingSuperghost {
            Text("Can you win even more?")
        } else {
            Spacer()
            Text("You earned a free day of Superghost")
                .underline(pattern: .solid, color: .accent)
                .scaleEffect(animationTrigger ? 0.9
                             : 1)
                .animation(.spring.repeatForever(), value: animationTrigger)
                .onAppear{
                    animationTrigger.toggle()
                }
        }
        Spacer()
            Button("Continue"){showingFiveWinsStreak = false}
                .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
                .font(.title2)
                .padding(.horizontal)
    }
}

#Preview {
    FiveWinsStreakView()
        .modifier(PreviewModifier())
}
