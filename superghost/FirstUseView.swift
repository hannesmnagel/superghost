//
//  FirstUseView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI
import GameKit

struct FirstUseView: View {
    @CloudStorage("showOnBoarding") var isFirstUse = true
    @State var firstUseState = FirstUseState.tapToContinue

    enum FirstUseState: CaseIterable{
        case tapToContinue, howTo, signIn, grantFriendsPermission, end
    }

    var body: some View {
        switch firstUseState {
        case .tapToContinue:
            VStack{
                Image(.ghostHeadingLeft)
                    .resizable()
                    .scaledToFit()
                Text("Welcome to Ghost!")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                Text("Tap to play")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture {
                firstUseState.nextCase()
            }
        case .howTo:
            InstructionsView{firstUseState.nextCase()}
        case .signIn:
            SignInView{firstUseState.nextCase()}
        case .grantFriendsPermission:
            GrantFriendsPermissionView{firstUseState.nextCase()}
        case .end:
            Text("Let's go")
                .font(.largeTitle.bold())
                .task{
                    finished()
                }
        }
    }

    func finished(){
        isFirstUse = false
    }
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
