//
//  superghostApp.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import RevenueCat
import BackgroundTasks
import UserNotifications

@main
struct superghostApp: App {
    init(){
        Purchases.logLevel = .error
        try! Purchases.configure(withAPIKey: String(contentsOf: Bundle.main.resourceURL!.appending(path: "revenuecatkey.txt")).trimmingCharacters(in: .whitespacesAndNewlines))
        Task{
            try? SoundManager.shared.play(.ambient, loop: true)
            try? await Task.sleep(for: .seconds(2))
            try? SoundManager.shared.play(.ambient2, loop: true)
        }
    }

    @CloudStorage("isSuperghost") private var isSuperghost = false
    @CloudStorage("notificationsAllowed") var notificationsAllowed = false
    
    @StateObject var viewModel = GameViewModel()
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modifier(Messagable())
                .onAppear{
                    try? SoundManager.shared.setActive()
                }
                .environmentObject(viewModel)
#if os(macOS)
                .frame(minHeight: 500)
#endif
        }
        .onChange(of: scenePhase){
            if scenePhase == .background{
                Task{
                    do{
                        if notificationsAllowed{
                            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(1 * 24 * 60 * 60), repeats: false)
                            let content = UNMutableNotificationContent()

                            content.title = "Keep Your Streak Going!"
                            content.body = "Play some Ghost"
                            content.sound = .default
                            try await UNUserNotificationCenter.current().add(
                                UNNotificationRequest(
                                    identifier: Calendar.current.startOfDay(for: Date().addingTimeInterval(1 * 24 * 60 * 60)).ISO8601Format(),
                                    content: content,
                                    trigger: trigger)
                            )
                        }
                    } catch{}
                }
            }
        }

#if os(macOS)
        Settings {
            SettingsView(isSuperghost: isSuperghost) {
                NSApp.keyWindow?.close()
                NSApp.mainWindow?.becomeFirstResponder()

            }
            .environmentObject(viewModel)

        }
#endif
    }
}
