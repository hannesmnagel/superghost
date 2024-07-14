//
//  SettingsButton.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI
import RevenueCat

struct SettingsButton: View {
    @ObservedObject var viewModel: GameViewModel
    let isSuperghost: Bool
    @State private var managementURL: URL?
    @State private var showingSettings = false
    @State private var destination = Destination.none

    enum Destination: String {case learn, none}

    var body: some View {
        Button{
            showingSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSettings){
            NavigationStack(path: .init(get: {destination == .none ? [] : [destination]}, set: { destinations in
                destination = destinations.last ?? .none
            })){
                Form{
                    NavigationLink("Learn How To Play", value: Destination.learn)
                    if !isSuperghost{
                        Button("Subscribe to Superghost"){
                            showingSettings = false
                            viewModel.showPaywall = true
                        }
                    } else {
                        #if DEBUG
                        Button("Subscribe to Superghost"){
                            showingSettings = false
                            viewModel.showPaywall = true
                        }
                        #endif
                    }
                    if let managementURL{Link("Manage subscription", destination: managementURL).font(.body)}
                }
                .task{
                    managementURL = try? await Purchases.shared.customerInfo().managementURL
                }
                .font(.body)
                .navigationDestination(for: Destination.self) { selectedDestination in
                    switch selectedDestination {
                    case .learn:
                        ViewThatFits{
                            InstructionsView{destination = .none}
                            ScrollView{InstructionsView{destination = .none}}
                        }
                    case .none:
                        EmptyView()
                    }
                }
                .navigationTitle("Settings")
            }
        }
    }
}

#Preview {
    SettingsButton(viewModel: GameViewModel(), isSuperghost: true)
        .modifier(PreviewModifier())
}
