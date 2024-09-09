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
import GameKit

@main
struct superghostApp: App {
    init(){
        Purchases.logLevel = .error
        try! Purchases.configure(withAPIKey: String(contentsOf: Bundle.main.resourceURL!.appending(path: "revenuecatkey.txt")).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @CloudStorage("isSuperghost") private var isSuperghost = false
    @CloudStorage("rank") private var rank = -1

    @StateObject var viewModel = GameViewModel()
    @Environment(\.scenePhase) var scenePhase
    @State private var score = 0

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modifier(Messagable())
                .onAppear{
                    try? SoundManager.shared.setActive()
                    Logger.userInteraction.info("App launched")
#if !os(macOS)
                    scheduleLBNotifications()
#endif
                }
                .environmentObject(viewModel)
#if os(macOS)
                .frame(minHeight: 500)
#endif
        }
#if !os(macOS)
        .backgroundTask(.appRefresh("com.nagel.superghost.lbnotifications")) {
            do{
                scheduleLBNotifications()
                
                if await UNUserNotificationCenter.current().pendingNotificationRequests().filter({$0.identifier == "end-of-week-start-of-day"}).isEmpty{
                    scheduleEventNotifcation()
                }

                let rank = await rank

                if GKLocalPlayer.local.isAuthenticated,

                    let entries = try await GKLeaderboard
                    .loadLeaderboards(IDs: ["global.score"])
                    .first?
                    .loadEntries(for: .global, timeScope: .allTime, range: NSRange(rank...rank)),
                   let myCurrent = entries.0?.rank,
                   rank > 0,
                   myCurrent > rank {

                    let otherPlayer = entries.1.first{$0.rank == rank}?.player.alias ?? "Someone"
                    let notifications = [
                        ("Zoom! \(otherPlayer) Just Blasted Past You!", "Looks like \(otherPlayer) just zoomed past you! Time to step up your game!"),
                        ("Alert! \(otherPlayer) Has Overtaken You!", "Watch out! \(otherPlayer) has overtaken you on the leaderboard! Can you catch up?"),
                        ("Uh-Oh! Someone's Gaining!", "Uh-oh! \(otherPlayer) just surpassed you! Time to unleash your inner champion!"),
                        ("🚨 Lead Change Alert!", "🚨 Alert! \(otherPlayer) is now ahead of you on the leaderboard! Are you ready to reclaim your spot?"),
                        ("Oops! \(otherPlayer) Passed You!", "Oops! \(otherPlayer) just passed you! Better get back in the game before they get too far ahead!"),
                        ("Challenge Accepted!", "Whoa! \(otherPlayer) just made a move and left you in the dust! Challenge accepted?"),
                        ("Surprise! A New Leader!", "Surprise! \(otherPlayer) just took the lead! Don’t let them enjoy it for too long!"),
                        ("Heads Up! Competition Ahead!", "Heads up! \(otherPlayer) just sped by you on the leaderboard! It’s time for a comeback!"),
                        ("Watch Out! \(otherPlayer) Is Gaining Ground!", "\(otherPlayer) just stole your thunder on the leaderboard! Can you turn the tables?"),
                        ("Game On! The Challenge Awaits!", "Game on! \(otherPlayer) just passed you! Will you rise to the challenge?")
                    ]
                    let notification = notifications.randomElement()!
                    sendPushNotification(with: notification.0, description: notification.1)
                    await MainActor.run {self.rank = myCurrent}

                    Logger.appRefresh.info("Sent push notification, because someone passed you on the leaderboard.")
                } else {
                    Logger.appRefresh.info("Did not sent push notification but checked if someone passed you on the leaderboard.")
                }
            } catch {
                Logger.appRefresh.error("\(error, privacy: .public)")
            }
        }
#endif
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
#if !os(macOS)
    nonisolated func scheduleLBNotifications() {
        //start the backgroundtask with: e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.nagel.superghost.lbnotifications"]

        let lbnotificationRequest = BGAppRefreshTaskRequest(identifier: "com.nagel.superghost.lbnotifications")
        // Fetch no earlier than 30 minutes from now.
        lbnotificationRequest.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)

        do {
            try BGTaskScheduler.shared.submit(lbnotificationRequest)
            Logger.appRefresh.info("Scheduled new lbnotifications task.")
        } catch {
            Logger.appRefresh.error("Error scheduling lbnotifications: \(error, privacy: .public)")
        }
    }
    nonisolated func scheduleEventNotifcation() {
        let greetings = [
            ("Double Trouble!", "It’s the last weekday, and today your match counts double! Time to rack up those XP points and make your competition sweat!"),
            ("XP-ocalypse Now!", "Attention, brave XP warriors! On this fine last weekday, every match counts as two! So go out there and double your trouble!"),
            ("Twice the Fun!", "Why settle for one when you can have two? Today is the day when each match doubles your XP! Get in there and show them who’s boss!"),
            ("Weekend Prep: Double XP Edition!", "Before you kick back and relax, let’s double up those XP points! Today’s matches are worth two—like a two-for-one deal but without the calories!"),
            ("XP Extravaganza!", "Happy last weekday! It’s time to feast on double XP! Don’t worry, your matches won’t bite (but they will count twice)!"),
            ("Dueling XP Points!", "It’s a duel! Each match today counts double, so put on your best game face and go for the win! The XP gods demand it!"),
            ("Double or Nothing!", "It’s your lucky day! Every match today counts double towards XP—so put on your favorite socks and let’s get this double XP party started!"),
            ("XP: The Sequel!", "Guess what? Every match today is a sequel worth twice the XP! Time to make your gaming history a blockbuster hit!"),
            ("Double Your Pleasure, Double Your XP!", "It’s the last weekday! Matches today count double, so don’t just play—play like you mean it! Your XP is waiting for a lift!"),
            ("Last Weekday Shenanigans!", "Happy last weekday! Today, your matches come with a bonus—double XP! Get ready to level up faster than you can say ‘XP-tastic!’")
        ]
        let greeting = greetings.randomElement()!

        let eveningReminders = [
            ("Last Call for Double XP!", "This is it! Today is your final chance to rack up double XP before the week wraps up! Don’t miss out!"),
            ("Final Countdown: Double XP Edition!", "Tick tock! The clock is ticking down on your double XP opportunity! Get in those matches while you can!"),
            ("Last Chance to Level Up!", "It's your last chance! Double XP is about to vanish, so make those matches count before it's too late!"),
            ("The XP Train is Leaving!", "All aboard the XP train! This is your last chance to hop on for double points before it departs!"),
            ("Don’t Let Double XP Slip Away!", "The sun is setting, and so is your chance for double XP! Make your final matches count!"),
            ("End of Day XP Push!", "Time’s almost up! This is your last chance for double XP today! Show them what you’ve got!"),
            ("Final Opportunity for Double XP!", "This is your last chance to snag those double XP points! Go out with a bang!"),
            ("Last Match Madness!", "It’s the final hours for double XP! Don’t miss out on making your last matches epic!"),
            ("Double XP: The Finale!", "This is it! The final chance to earn double XP before the weekend! Make it count!"),
            ("Get in the Game Before It’s Gone!", "This is your last call for double XP! Don’t let it slip away without a fight!")
        ]
        let eveningGreeting = eveningReminders.randomElement()!

        let weekday = Calendar.current.firstWeekday + 6

        sendPushNotification(with: greeting.0, description: greeting.1, id: "end-of-week-start-of-day", using: UNCalendarNotificationTrigger(dateMatching: .init(hour: 9, weekday: weekday), repeats: false))

        sendPushNotification(with: eveningGreeting.0, description: eveningGreeting.1, id: "end-of-week-end-of-day", using: UNCalendarNotificationTrigger(dateMatching: .init(hour: 21, weekday: weekday), repeats: false))

        Logger.appRefresh.info("scheduled push notifications for end of week events")
    }
#endif
    nonisolated func sendPushNotification(with title: String, description: String, id: String = UUID().uuidString, at date: Date = .now) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: date.timeIntervalSinceNow.magnitude+0.1, repeats: false)
        sendPushNotification(with: title, description: description, using: trigger)
    }
    nonisolated func sendPushNotification(with title: String, description: String, id: String = UUID().uuidString, using trigger: UNNotificationTrigger) {
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
