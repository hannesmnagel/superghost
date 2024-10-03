//
//  InstructionsView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI

struct InstructionsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var instructionIndex = 0

    let onFinish: () -> Void

    private let instructions: [(title: String, points: [String], image: ImageResource)] = [
        (
            title: "Basic Gameplay",
            points: [
                "You will take turns with your opponent. Each turn, you can append or prepend a letter to the growing word.",
                "Your goal is to create a sequence that doesn’t form a complete word but could become one with more letters."
            ],
            image: .ghostHearts
        ),
        (
            title: "Challenge Mechanics",
            points: [
                "If you believe your opponent is lying about knowing a longer word, you can challenge their move.",
                "If they can’t prove they know a longer word, they lose!"
            ],
            image: .ghostThinking
        ),
        (
            title: "Avoiding Full Words",
            points: [
                "Be careful! If you accidentally create a full word, you automatically lose.",
                "Remember: only one player can win each round!"
            ],
            image: .ghostExploding
        ),
        (
            title: "Losing Streaks",
            points: [
                "Every time you lose, you collect a letter from the word GHOST or SUPERGHOST.",
                "Once you spell out the entire word, you cannot play for the rest of the day."
            ],
            image: .ghostSad
        ),
        (
            title: "Winning Streaks",
            points: [
                "Win 5 consecutive matches to earn a free day of Superghost!",
                "Challenge your friends and climb the leaderboards!"
            ],
            image: .ghostStars
        )
    ]

    var body: some View {
        VStack {
            Text(instructions[instructionIndex].title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 50)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(stops: [
                        .init(color: .white, location: 0),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            )
            Spacer()
            ForEach(instructions[instructionIndex].points, id: \.self) { point in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text(point)
                        .font(.body)
                }
            }
            .multilineTextAlignment(.leading)
            .padding()
            .frame(maxWidth: 500, alignment: .leading)
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)



            Button("Continue") {
                withAnimation{
                    if instructionIndex == instructions.count - 1 {
                        onFinish()
                        #if !os(macOS)
                        dismiss()
                        #endif
                    } else {
                        instructionIndex += 1
                    }
                }
            }
            .buttonStyle(AppearanceManager.HapticStlyeCustom(buttonStyle: AppearanceManager.FullWidthButtonStyle(isSecondary: false)))
            .padding(.horizontal)
            .padding(.top, 40)
        }
        .background(
            Image(instructions[instructionIndex].image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        )
        .foregroundStyle(.black)
    }
}

#Preview {
    InstructionsView {}
        .modifier(PreviewModifier())
}
