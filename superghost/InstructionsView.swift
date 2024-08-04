//
//  InstructionsView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI


struct InstructionsView: View {
    @Environment(\.dismiss) var dismiss
    let instructions = ["""
Inspired by a game played on the chalk board, superghost is a word game where you have to add letters so that:

- It doesn't make an entire word

- It could become a word when adding more letters
""", """
Players take turns and when you think a player is lying you can challenge the move.
""", """
With ghost you can append letters to a word, with superghost you can also add them before the letters.
""","""
Every time you lose, you collect a letter of the word GHOST or SUPERGHOST. When the word is full you can't play for this day any longer.
""","""
Get a winning streak of 5 online matches to earn a free day of superghost.
"""
    ]
    @State var selection = """
Inspired by a game played on the chalk board, superghost is a word game where you have to add letters so that:

- It doesn't make an entire word

- It could become a word when adding more letters
"""

    let next: ()->Void

    var body: some View {
        ViewThatFits{
            content
            ScrollView{content}
        }
    }
    @MainActor @ViewBuilder
    var content: some View{
        VStack{
            Text("Learn How To Play")
                .font(AppearanceManager.howToPlayTitle)
                .padding(.bottom)
#if os(macOS)
            Text(instructions.joined(separator: "\n\n"))
                .padding()
                .lineLimit(nil)
#else
            TabView(selection: $selection){
                ForEach(instructions, id:\.self){instruction in
                    ViewThatFits{
                        Text(instruction)
                        ScrollView{
                            Text(instruction)
                        }
                    }
                    .font(AppearanceManager.instructions)
                    .task {
                        do{
                            try await Task.sleep(for: .seconds(6))
                            guard let index = instructions.firstIndex(of: instruction) else {return}
                            selection = instructions[(index + 1) % instructions.count]
                        }catch{}
                    }
                    .tag(instruction)
                    .tabItem { Circle() }
                }
            }

            .tabViewStyle(.page)
            .padding()
#endif
            Button("Got it"){next(); dismiss()}
                .buttonStyle(.bordered)
        }
        .padding()
        .foregroundStyle(.white)
    }
}

#Preview {
    InstructionsView{}
        .modifier(PreviewModifier())
}
