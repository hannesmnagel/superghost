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
        if #available(macOS 14.0, *){
            SettingsLink{
                Label("Settings", systemImage: "gearshape")
            }
        } else {
            Button{
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
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
                        .onChange(of: notificationsAllowed) {newValue in
                            Task{
                                if newValue{
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
#if !os(macOS)
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
                        .onChange(of: volume) {newVal in
                            SoundManager.shared.setVolume(newVal)
                        }
                }
#if os(iOS)
                Section("Icon"){
                    NavigationLink("Select AppIcon", destination: AppIconPickerView(isSuperghost: isSuperghost))
                }
#endif
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
                    .buttonBorderShape(.bcCircle)
                }
            }
#endif
        }
#if os(macOS)
        .frame(minWidth: 300, minHeight: 300)
#endif
    }
}

#if os(iOS)
struct AppIconPickerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: GameViewModel

    let isSuperghost: Bool
    let icons = AppearanceManager.AppIcon.allCases
    var body: some View {
        ScrollView{
            LazyVGrid(columns: [.init(.adaptive(minimum: 100, maximum: 400))]) {
                ForEach(icons, id: \.self) { icon in
                    Button{
                        if isSuperghost || icon == .standard {
                            UIApplication.shared.setAlternateIconName(icon.rawValue)
                            dismiss()
                        } else {
                            viewModel.showPaywall = true
                        }
                    } label: {
                        Image(icon.rawValue.appending(".image"))
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 10))
                    }
                    .overlay{
                        if AppearanceManager.shared.appIcon == icon {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor, lineWidth: 3)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if !isSuperghost && !(icon == .standard){
                            Image(systemName: "lock.fill")
                        }
                    }
                }
            }
        }
    }
}
#endif

#Preview {
    SettingsButton(isSuperghost: true)
        .modifier(PreviewModifier())
}
#Preview {
    SettingsView(isSuperghost: true) {}
        .modifier(PreviewModifier())
}
