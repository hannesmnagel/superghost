//
//  ScoreChangeView.swift
//  superghost
//
//  Created by Melanie Nagel   on 9/24/24.
//

import SwiftUI

struct ScoreChangeView: View {
    @CloudStorage("score") private var score = 1000
    @State var increasing = Bool?.none
    
    var image : ImageResource {
        switch increasing {
        case .none:
                .ghostThinking
        case .some(true):
                .ghostHearts
        case .some(false):
                .ghostSad
        }
    }

    var body: some View {
        let transition : ContentTransition =
        if #available(iOS 17.0, macOS 14.0, *){
            .numericText(value: Double(score))
        } else {
            .numericText()
        }
        VStack{
            Spacer()
            Image(image)
                .resizable()
                .scaledToFit()
                .clipShape(.capsule)
                .animation(.spring, value: image)
            Group{
                Text(score, format: .number) + Text(" XP")
            }
            .font(.system(size: 70))
            Spacer()
            Button("Continue"){
                UserDefaults.standard.set(false, forKey: "showingScoreChange")
            }
            .buttonStyle(AppearanceManager.HapticStlyeCustom(buttonStyle: AppearanceManager.FullWidthButtonStyle(isSecondary: false)))
            .padding(.horizontal)
            .font(.title2)
        }
        .foregroundStyle(increasing == true ? .black : .primary)
            .contentTransition(transition)
            .onDisappear{
                increasing = nil
            }
            .onChange(of: score) { old, new in
                increasing = new > old
#if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(increasing! ? .success : .error)
#endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.brightness(increasing == true ? 0.5 : 0).ignoresSafeArea())
    }
}
#Preview{
    ScoreChangeView()
        .modifier(PreviewModifier())
        .task {
            try? await Task.sleep(for: .seconds(5))
            await MessageModel.shared.changeScore(by: -50)
            try? await Task.sleep(for: .seconds(5))
            await MessageModel.shared.changeScore(by: 50)
        }
}
