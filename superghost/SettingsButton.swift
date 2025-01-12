//
//  SettingsButton.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI
import UserNotifications
import OSLog

struct SettingsButton: View {
    @AppStorage("showingSettings") private var showingSettings = false


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
        .foregroundStyle(.accent)
#endif
    }
}

import GameKit

struct SettingsView: View {
    @CloudStorage("doubleXP15minNotifications") var doubleXP15minNotifications = true
    @CloudStorage("specialEventNotifications") var specialEventNotifications = true
    @CloudStorage("leaderboardNotifications") var leaderboardNotifications = true
    @State private var notificationAuthorization = UNAuthorizationStatus?.none


    enum Destination: String {case learn, none}
    let dismiss: ()->Void

#if DEBUG
    @State private var logs = [String]()
#endif

    var body: some View {
            Form{
                Section{
                    NavigationLink("Learn How To Play"){
                        InstructionsView{}
                    }
                }
#if os(iOS)
                Section("Icon"){
                    NavigationLink("Select AppIcon", destination: AppIconPickerView())
                }
#endif
                Section{
                    Button("Game Center"){
                        GKAccessPoint.shared.trigger {}
                    }
                }
#if DEBUG
                DisclosureGroup("Logs") {
                    ForEach(logs, id: \.self) { entry in
                        Text(entry)
                            .onTapGesture {
#if os(macOS)
                                NSPasteboard.general.setString(logs.joined(separator: "\n"), forType: .string)
#else
                                UIPasteboard.general.string = logs.joined(separator: "\n")
#endif
                            }
                    }
                }
                .task{
                    Task.detached{
                        let store = try? OSLogStore(scope: .currentProcessIdentifier)
                        let position = store?.position(timeIntervalSinceLatestBoot: 1)
                        let entries = try? store?
                            .getEntries(at: position)
                            .compactMap { $0 as? OSLogEntryLog }
                            .filter { $0.subsystem == Bundle.main.bundleIdentifier! }
                            .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }
                        await MainActor.run{
                            self.logs = entries ?? []
                        }
                    }
                }
#endif
                
                Section("Notifications"){
                    if let notificationAuthorization {
                        if notificationAuthorization == .authorized {
                            Toggle("15 minute Double XP", isOn: $doubleXP15minNotifications)
                            Toggle("Special Event Notifications", isOn: $specialEventNotifications)
                            Toggle("Leaderboard Notifications", isOn: $leaderboardNotifications)
                        } else {
                            ContentPlaceHolderView(
                                "Notifications not allowed",
                                systemImage: "bell.badge.slash"
                            )
                            Button("Grant Permission"){
                                Task{
                                    switch notificationAuthorization {
                                    case .notDetermined:
                                        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                                    case .denied:
                                        #if os(macOS)
                                        showMessage("Open settings to allow notifications.")
                                        #else
                                        if let appSettingsURL = URL(string: UIApplication.openSettingsURLString),
                                           UIApplication.shared.canOpenURL(appSettingsURL) {
                                            await UIApplication.shared.open(appSettingsURL)
                                        }
                                        #endif
                                    case .authorized:
                                        return
                                    case .provisional:
                                        return
                                    case .ephemeral:
                                        return
                                    @unknown default:
                                        return
                                    }

                                }
                            }
                        }
                    } else {
                        ContentPlaceHolderView("Loading authorization", systemImage: "bell.badge")
                            .task{
                                self.notificationAuthorization = await withCheckedContinuation({ con in
                                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                                        con.resume(returning: settings.authorizationStatus)
                                    }
                                })
                            }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        #if !os(macOS)
            .background(PlayerProfileModel.shared.player.color.gradient, ignoresSafeAreaEdges: .all)
        #endif
            .font(AppearanceManager.buttonsInSettings)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .keyboardShortcut(.cancelAction)
                }
            }
#else
        .padding(40)
#endif
    }
}

#if os(iOS)
struct AppIconPickerView: View {
    @Environment(\.dismiss) var dismiss

    let icons = AppearanceManager.AppIcon.allCases
    var body: some View {
        ScrollView{
            LazyVGrid(columns: [.init(.adaptive(minimum: 150, maximum: 300))]) {
                ForEach(icons, id: \.self) { icon in
                    Button{
                        AppearanceManager.shared.appIcon = icon
                        UIApplication.shared.setAlternateIconName(icon.rawValue)
                        dismiss()
                    } label: {
                        Image(icon.rawValue.appending(".image"))
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 25))
                    }
                    .overlay{
                        if AppearanceManager.shared.appIcon == icon {
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.accent, lineWidth: 3)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("App Icon")
    }
}
#endif

#Preview {
    SettingsButton()
        .modifier(PreviewModifier())
}
