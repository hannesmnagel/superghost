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
        SettingsLink{
            Label("Settings", systemImage: "gearshape")
        }
        #else
        Button{
            showingSettings = true
        } label: {
            Label("Settings", systemImage: "gearshape")
                .contentShape(.capsule)
        }
        .font(AppearanceManager.settingsButton)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .sheet(isPresented: $showingSettings){
            SettingsView(isSuperghost: isSuperghost){showingSettings = false}
        }
        #endif
    }
}

import GameKit

struct SettingsView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @CloudStorage("notificationsAllowed") var notificationsAllowed = true
    @State private var managementURL: URL?
    @AppStorage("volume") var volume = 1.0

    let isSuperghost: Bool

    enum Destination: String {case learn, none}
    let dismiss: ()->Void

    var body: some View {
        NavigationStack{
            Form{
                Section{
                    NavigationLink("Learn How To Play"){
                        InstructionsView{}
                    }
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
                Section("Volume"){
                    Slider(value: $volume, in: 0...2)
                        .onChange(of: volume) {
                            SoundManager.shared.setVolume(volume)
                        }
                }
            }
            .font(AppearanceManager.buttonsInSettings)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task{
                managementURL = try? await Purchases.shared.restorePurchases().managementURL
            }
            .navigationTitle("Settings")
#if !os(macOS)
            .toolbar{
                ToolbarItem(placement: .cancellationAction) {
                    Button{
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
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
