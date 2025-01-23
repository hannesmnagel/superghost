//
//  LetterPicker.swift
//  superghost
//
//  Created by Hannes Nagel on 8/6/24.
//

import SwiftUI

struct LetterPicker: View {
    @Environment(\.isEnabled) var isEnabled
    let word: String
    @State private var leadingLetter = ""
    @State private var trailingLetter = ""
    let allowedLetters = ["", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
    @State var disabled = false

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack{
            if !word.isEmpty {
                SingleLetterPicker(letter: $leadingLetter, allowedLetters: allowedLetters)
                    .disabled(!trailingLetter.isEmpty)
                Text(word)
                    .font(AppearanceManager.wordInGame)
                    .task(id: isEnabled) {
                        isFocused = true
                    }
            }
            SingleLetterPicker(letter: $trailingLetter, allowedLetters: allowedLetters)
                .disabled(!leadingLetter.isEmpty)
                .font(AppearanceManager.letterPicker)
                .focused($isFocused)
        }

        AsyncButton{
            if !leadingLetter.isEmpty {
                try await GameViewModel.shared.prepend(letter: leadingLetter)
                leadingLetter = ""
            } else {
                try await GameViewModel.shared.append(letter: trailingLetter)
                trailingLetter = ""
            }
        } label: {
            Text("Submit Move")
        }
        .keyboardShortcut(.defaultAction)
        .disabled(leadingLetter.isEmpty && trailingLetter.isEmpty)
        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
    }
}
