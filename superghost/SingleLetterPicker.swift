//
//  SingleLetterPicker.swift
//  superghost
//
//  Created by Hannes Nagel on 8/6/24.
//

import SwiftUI

struct SingleLetterPicker: View {
    @Binding var letter: String
    let allowedLetters: [String]


    var body: some View {
#if !os(macOS)
        Picker("", selection: $letter) {
            ForEach(allowedLetters, id: \.self){letter in
                Text(letter)
            }
        }
        .pickerStyle(.wheel)
#else
        TextField("Letter", text: .init(get: {
            letter
        }, set: {
            let newLetter = String($0.suffix(1))
            if allowedLetters.joined().localizedCaseInsensitiveContains(newLetter){
                letter = newLetter.uppercased()
            }
        }))
#endif
    }
}
