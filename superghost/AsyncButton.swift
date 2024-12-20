//
//  AsyncButton.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI

struct AsyncButton<Label:View>: View {

    let action: () async throws -> Void
    @ViewBuilder let label: Label

    @State private var state = AsyncButtonState.main

    enum AsyncButtonState{
        case main, inProgress, success, failed
    }

    var body: some View {
        Button{
            Task{
                do{
                    state = .inProgress
                    try await action()
                    state = .success
                    try? await Task.sleep(for: .seconds(1))
                    state = .main
                } catch {
                    Logger.userInteraction.error("AsyncButton failed with error: \(error, privacy: .public)")
                    Logger.trackEvent("asyncbutton_failed", with: ["error" : String(describing: error)])
                    state = .failed
                    try? await Task.sleep(for: .seconds(1))
                    state = .main
                }
            }
        } label: {
            switch state {
            case .main:
                label
            case .inProgress:
                ProgressView()
            case .success:
                Image(systemName: "checkmark")
            case .failed:
                Image(systemName: "xmark")
            }
        }
        .disabled(state == .inProgress)
    }
}


#Preview {
    AsyncButton {

    } label: {
        Text("Button")
    }
    .buttonStyle(.bordered)
//    .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: ))
}
