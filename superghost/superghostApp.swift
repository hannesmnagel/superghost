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
import WidgetKit
import GameKit

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
    @CloudStorage("rank") private var rank = -1

    @StateObject var viewModel = GameViewModel()
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modifier(Messagable())
                .onAppear{
                    try? SoundManager.shared.setActive()

                    scheduleAppRefresh()
                }
                .environmentObject(viewModel)
#if os(macOS)
                .frame(minHeight: 500)
#endif
        }
        .backgroundTask(.appRefresh("com.nagel.superghost.lbnotifications")) {
            do{
                await scheduleAppRefresh()
                let rank = await rank

                if await notificationsAllowed,
                   GKLocalPlayer.local.isAuthenticated,

                    let entries = try await GKLeaderboard
                        .loadLeaderboards(IDs: ["global.score"])
                        .first?
                        .loadEntries(for: .global, timeScope: .allTime, range: NSRange(rank...rank)),
                   let myCurrent = entries.0?.rank,
                   rank > 0,
                   myCurrent > rank {

                    let otherPlayer = entries.1.first{$0.rank == rank}?.player.alias ?? "Someone"
                    await sendPushNotification(with: "\(otherPlayer) passed you on the leaderboard!", description: "Claim your rank now!")
                }
            } catch {}
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
    func scheduleAppRefresh() {
        //start the backgroundtask with: e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.nagel.superghost.lbnotifications"]

        let request = BGAppRefreshTaskRequest(identifier: "com.nagel.superghost.lbnotifications")
        // Fetch no earlier than 30 minutes from now.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    func sendPushNotification(with title: String, description: String, id: String = UUID().uuidString) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(0.1), repeats: false)
        let content = UNMutableNotificationContent()

        content.title = title
        content.body = description
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: trigger)
        )
    }
}
