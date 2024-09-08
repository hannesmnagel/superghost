//
//  SettingsButton.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI
import RevenueCat
import UserNotifications
import OSLog

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
    @State private var managementURL: URL?
    @AppStorage("volume") var volume = 1.0

    let isSuperghost: Bool

    enum Destination: String {case learn, none}
    let dismiss: ()->Void

#if DEBUG
    @State private var entries = {
        let store = try? OSLogStore(scope: .currentProcessIdentifier)
        let position = store?.position(timeIntervalSinceLatestBoot: 1)
        let entries = try? store?
            .getEntries(at: position)
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.subsystem == Bundle.main.bundleIdentifier! }
            .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }
        return entries ?? []
    }()
#endif

    var body: some View {
        NavigationStack{
            Form{
                Section{
                    NavigationLink("Learn How To Play"){
                        InstructionsView{}
                    }
                }
                Section{
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
                        if let managementURL{Link("Manage subscription", destination: managementURL)}
                    }
                }
                Section("Volume:"){
                    Slider(value: $volume, in: 0...2)
                        .onChange(of: volume) {newVal in
                            SoundManager.shared.setVolume(newVal)
                        }
#if os(macOS)
                        .frame(maxWidth: 200)
#endif
                }
#if os(iOS)
                Section("Icon"){
                    NavigationLink("Select AppIcon", destination: AppIconPickerView(isSuperghost: isSuperghost))
                }
#endif
                Section{
                    ShareLink("Share Testflight Invite", item: URL(string: "https://testflight.apple.com/join/OzTDTCgF")!)
                }
#if DEBUG
                DisclosureGroup("Logs") {
                    ForEach(entries, id: \.self) { entry in
                        Text(entry)
                            .onTapGesture {
#if os(macOS)
                                NSPasteboard.general.setString(entries.joined(separator: "\n"), forType: .string)
#else
                                UIPasteboard.general.string = entries.joined(separator: "\n")
#endif
                            }
                    }
                }
#endif
            }
            .font(AppearanceManager.buttonsInSettings)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task{
                managementURL = try? await Purchases.shared.customerInfo().managementURL
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
        .padding(40)
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
