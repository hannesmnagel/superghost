//
//  LetterPicker.swift
//  superghost
//
//  Created by Hannes Nagel on 8/6/24.
//

import SwiftUI

struct LetterPicker: View {
    @EnvironmentObject var viewModel: GameViewModel
    let isSuperghost: Bool
    @State private var leadingLetter = ""
    @State private var trailingLetter = ""
    let allowedLetters = ["", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
    @State var disabled = false

    var body: some View {
        let word = viewModel.game?.moves.last?.word ?? ""
        HStack{
            if !word.isEmpty {
                if viewModel.withInvitation || isSuperghost{
                    SingleLetterPicker(letter: $leadingLetter, allowedLetters: allowedLetters)
                        .disabled(!trailingLetter.isEmpty)
                }
                Text(word)
                    .font(AppearanceManager.wordInGame)
            }
            SingleLetterPicker(letter: $trailingLetter, allowedLetters: allowedLetters)
                .disabled(!leadingLetter.isEmpty)
                .font(AppearanceManager.letterPicker)
        }

        AsyncButton{
            try await viewModel.processPlayerMove(for: "\(leadingLetter)\(word)\(trailingLetter)", isSuperghost: isSuperghost)
            trailingLetter = ""
            leadingLetter = ""
        } label: {
            Text("Submit Move")
        }
        .keyboardShortcut(.defaultAction)
        .disabled(leadingLetter.isEmpty && trailingLetter.isEmpty)
        .buttonStyle(AppearanceManager.HapticStlyeCustom(buttonStyle: AppearanceManager.FullWidthButtonStyle(isSecondary: false)))
    }
}
