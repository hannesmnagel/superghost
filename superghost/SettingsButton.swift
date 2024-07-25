//
//  SettingsButton.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI
import RevenueCat
import UserNotifications

struct SettingsButton: View {
    @EnvironmentObject var viewModel: GameViewModel
    let isSuperghost: Bool
    @State private var managementURL: URL?
    @State private var showingSettings = false
    @State private var destination = Destination.none
    @CloudStorage("notificationsAllowed") var notificationsAllowed = true

    enum Destination: String {case learn, none}

    var body: some View {
        Button{
            showingSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .font(AppearanceManager.settingsButton)
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
                        Button("Show Paywall"){
                            showingSettings = false
                            viewModel.showPaywall = true
                        }
                        #endif
                    }
                    if let managementURL{Link("Manage subscription", destination: managementURL)}

                    Toggle("Notifications", isOn: $notificationsAllowed)
                        .onChange(of: notificationsAllowed) {
                            Task{
                                if notificationsAllowed{
                                    do{
                                        if try await !UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]){
#if !os(macOS)
                                            if let settingsURL = URL(string: UIApplication.openNotificationSettingsURLString){
                                                await UIApplication.shared.open(settingsURL)
                                            }
#endif
                                            notificationsAllowed = false
                                        }
                                    } catch {
#if os(iOS)
                                        if let settingsURL = URL(string: UIApplication.openNotificationSettingsURLString){
                                            await UIApplication.shared.open(settingsURL)
                                        } else {
                                            notificationsAllowed = true
                                        }
#else
                                        notificationsAllowed = false
#endif
                                    }
                                }
                            }
                        }
                }
                .font(AppearanceManager.buttonsInSettings)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task{
                    managementURL = try? await Purchases.shared.restorePurchases().managementURL
                }
                .navigationDestination(for: Destination.self) { selectedDestination in
                    switch selectedDestination {
                    case .learn:
                        InstructionsView{destination = .none}
                    case .none:
                        EmptyView()
                    }
                }
                .navigationTitle("Settings")
                .toolbar{
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done"){
                            showingSettings = false
                        }
                    }
                }
            }
#if os(macOS)
            .frame(minWidth: 500, minHeight: 500)

#endif
        }
    }
}

#Preview {
    SettingsButton(isSuperghost: true)
        .modifier(PreviewModifier())
}
