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
    let isSuperghost: Bool
    @State private var showingSettings = false


    var body: some View {
        #if os(macOS)
        SettingsLink{Image(systemName: "gearshape")}
        #else
        Button{
            showingSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .font(AppearanceManager.settingsButton)
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSettings){
            SettingsView(isSuperghost: isSuperghost){showingSettings = false}
        }
        #endif
    }
}

struct SettingsView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var destination = Destination.none
    @CloudStorage("notificationsAllowed") var notificationsAllowed = true
    @State private var managementURL: URL?

    let isSuperghost: Bool

    enum Destination: String {case learn, none}
    let dismiss: ()->Void

    var body: some View {
        NavigationStack(path: .init(get: {destination == .none ? [] : [destination]}, set: { destinations in
            destination = destinations.last ?? .none
        })){
            Form{
                NavigationLink("Learn How To Play", value: Destination.learn)
                if !isSuperghost{
                    Button("Subscribe to Superghost"){
                        dismiss()
                        viewModel.showPaywall = true
                    }
                } else {
#if DEBUG
                    Button("Show Paywall"){
                        dismiss()
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
#if !os(macOS) && !os(watchOS)
                                        if let settingsURL = URL(string: UIApplication.openNotificationSettingsURLString){
                                            await UIApplication.shared.open(settingsURL)
                                        }
#endif
                                        notificationsAllowed = false
                                    }
                                } catch {
#if !os(macOS) && !os(watchOS)
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
#if !os(macOS)
            .toolbar{
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done"){
                        dismiss()
                    }
                }
            }
#endif
        }
#if os(macOS)
        .frame(minWidth: 300, minHeight: 300)
#endif
    }
}


#Preview {
    SettingsButton(isSuperghost: true)
        .modifier(PreviewModifier())
}
