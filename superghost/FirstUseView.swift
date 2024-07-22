//
//  FirstUseView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI

struct FirstUseView: View {
    @State var firstUseState = FirstUseState.tapToContinue

    enum FirstUseState: CaseIterable{
        case tapToContinue, howTo, end
    }

    var body: some View {
        TabView(selection: $firstUseState){
            VStack{
                Image(.ghostHeadingLeft)
                    .resizable()
                    .scaledToFit()
                Text("Superghost")
                    .font(ApearanceManager.startUpSuperghost)
                    .fontWeight(.heavy)
                Text("Tap to play")
                    .font(ApearanceManager.startUpSuperghostTapToPlay)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture {
                firstUseState.nextCase()
            }
            .tag(FirstUseState.tapToContinue)
            .tabItem {}
            InstructionsView{firstUseState.nextCase()}
                .tag(FirstUseState.howTo)
                .tabItem {}
            Text("Let's go")
                .font(ApearanceManager.startUpSuperghost)
                .task{
                    try? await Task.sleep(for: .milliseconds(500))
                    finished()
                }
                .tag(FirstUseState.end)
                .tabItem {}
        }
    }

    func finished(){UserDefaults.standard.set(false, forKey: "isFirstUse")}
}

#Preview {
    FirstUseView()
        .modifier(PreviewModifier())
}

extension CaseIterable where Self: Equatable {
    mutating func nextCase() {
        guard let currentIndex = Self.allCases.firstIndex(of: self) else { return }
        let nextIndex = Self.allCases.index(after: currentIndex)
        self = nextIndex == Self.allCases.endIndex ? Self.allCases.first! : Self.allCases[nextIndex]
    }
}
