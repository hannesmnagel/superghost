//
//  InstructionsView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI


struct InstructionsView: View {
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
Get a winning streak of 10 online matches to earn a free day of superghost.
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
                .font(ApearanceManager.largeTitle.bold())
                .padding(.bottom)
            TabView(selection: $selection){
                ForEach(instructions, id:\.self){instruction in
                    Text(instruction)
                        .task {
                            do{
                                try await Task.sleep(for: .seconds(4))
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
            Button("Got it", action: next)
                .buttonStyle(.bordered)
        }
        .font(ApearanceManager.headline)
        .padding()
    }
}

#Preview {
    InstructionsView{}
        .modifier(PreviewModifier())
}
