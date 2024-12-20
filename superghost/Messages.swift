//
//  Messages.swift
//  superghost
//
//  Created by Hannes Nagel on 8/4/24.
//

import SwiftUI
import GameKit
import UserNotifications
#if os(iOS)
import WidgetKit
#endif

struct Messagable: ViewModifier {
    @ObservedObject var model = MessageModel.shared

    @State private var ghostScale = 1.0
    @State private var task : Task<Void, Never>?
    @State private var showingScore = false
    @CloudStorage("score") var score = 1000
    @State private var widgetExplanationStep = 0
    @State private var presentationDetent = PresentationDetent.medium

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                ZStack{
                    if let message = model.message.first {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.thinMaterial, ignoresSafeAreaEdges: .all)
                            .transition(.opacity.animation(.smooth))
                        HStack{
                            Text(message)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .clipShape(.capsule)

                            Image("GhostHeadingLeftTransparent")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 300)
                                .scaleEffect(ghostScale)
                                .offset(x: (ghostScale-0.5) * 50)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                        .task(id: message){
                            withAnimation(.bouncy){
                                ghostScale = 0.9
                            }
                            try? await Task.sleep(for: .seconds(message.count/10))
                            model.message = Array(model.message.dropFirst())
                        }
                    }
                    
                }
                .foregroundStyle(.white)
                .animation(.smooth, value: model.message)
                .onTapGesture {
                    model.message = Array(model.message.dropFirst())
                }
            }
            .sheet(item: $model.showingAction) {
                task?.cancel()
            } content: { action in
                VStack{
                    switch action {
                    case .addFriends:
                        addFriends
                    case .addWidget:
                        addWidget
                    case .enableNotifications:
                        enableNotifications
                    case .showDoubleXP:
                        showDoubleXP(title: "Special Event!", title2: "It's time for Double XP", subtitle: "Claim Double XP for each Game", buttonTitle: "Earn Double XP now!")
                    case .showSunday:
                        showDoubleXP(title: "Special Event!", title2: "It's a very special Sunday!", subtitle: "Get Double XP for each Game", buttonTitle: "Earn Double XP")
                    case .show4xXP:
                        showDoubleXP(title: "4x the XP", title2: "It's a very special Sunday!", subtitle: "Plus: It's Double XP time", buttonTitle: "Earn 4x XP")
                    }
                }
                .padding(.horizontal)
                .multilineTextAlignment(.center)
                .presentationDetents([.medium, .large], selection: $presentationDetent)
            }

    }
    private func dismissWhenAddedFriends() async throws {
        while try await withCheckedThrowingContinuation({con in
            GKLocalPlayer.local.loadFriends { players, error in
                if let players { con.resume(returning: players.isEmpty)} else {con.resume(throwing: error ?? MessagableError.couldntLoadFriends)}
            }
        }) {
            try? await Task.sleep(for: .seconds(1))
        }
        try? await GameStat.submitScore(score + 50)

        showingScore = true
        Task{await changeScore(by: 50)}
        Logger.trackEvent("add_friend")
        Logger.score.info("Increased score by 50 because user added a friend.")

        try? await Task.sleep(for: .seconds(6))

        model.showingAction = nil
        showingScore = false

    }
    private func dismissWhenAddedWidget() async throws {
#if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
#endif
        while true {
            if let lastWidgetUpdateString = NSUbiquitousKeyValueStore.default.string(forKey: "lastWidgetUpdate"),
               let lastWidgetUpdate = ISO8601DateFormatter().date(from: lastWidgetUpdateString),
               lastWidgetUpdate.timeIntervalSinceNow.magnitude < 20 {break}
            try? await Task.sleep(for: .seconds(1))
        }
        Logger.trackEvent("add_widget")
        try? await GameStat.submitScore(score + 50)

        showingScore = true


        Task{await changeScore(by: 50)}
        Logger.score.info("Increased score by 50 because user added a widget.")

        try? await Task.sleep(for: .seconds(6))

        model.showingAction = nil
        showingScore = false
    }
    private func dismissWhenNotificationsAllowed() async throws {

        while await withCheckedContinuation({con in
            UNUserNotificationCenter.current().getNotificationSettings { notificationSettings in
                con.resume(returning: notificationSettings.authorizationStatus != .authorized)
            }
        }) {
            try? await Task.sleep(for: .seconds(1))
        }
        Task{
            try? await GameStat.submitScore(score + 50)
        }

        showingScore = true
        Task{await changeScore(by: 50)}
        Logger.score.info("Increased score by 50 because user allowed notifications")

        try? await Task.sleep(for: .seconds(6))
        await Logger.checkForNotificationStatusChange()

        model.showingAction = nil
        showingScore = false

    }

    @MainActor @ViewBuilder
    var scoreChangeOverlay: some View {
        if showingScore{
            let transition: ContentTransition = if #available(iOS 17.0, *) {
                    .numericText(value: Double(score))
                } else {
                    .numericText()
                }

            Text(score, format: .number)
                .font(.system(size: 70))
                .contentTransition(
                    transition
                )
        }
    }
    @MainActor @ViewBuilder
    var addFriends: some View {
        Text("Add a Friend")
            .font(.largeTitle.bold())
            .padding(.top)
        Text("And earn 50 XP")
            .bold()
        Spacer()
        GKLocalPlayer.local.asyncImage(.normal)
            .padding(.top)
            .padding(.horizontal, 70)
            .opacity(showingScore ? 0.1 : 1)
            .overlay{
                scoreChangeOverlay
            }
        Spacer()
        AsyncButton{
            GKAccessPoint.shared.addFriends()
            task?.cancel()
            task = Task{
                try? await dismissWhenAddedFriends()
            }
            await task?.value
        } label: {
            Text("Add Friends")
        }
        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
        .font(.title2.bold())
        Button("Maybe later"){
            model.showingAction = nil
        }
        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: true))
    }
    @MainActor @ViewBuilder
    var addWidget: some View{
        if widgetExplanationStep == 0 {
            Text("Add a Widget")
                .font(.largeTitle.bold())
                .padding(.top, 30)
            Text("And earn an extra 50 XP + Unlock a new Skin")
                .bold()
            Spacer()

            Image(Skin.sailor.image)
                .resizable()
                .scaledToFit()
                .clipShape(.circle)
                .padding()
                .padding(.top)
                .padding(.horizontal, 70)

            Spacer()
            Button("Continue"){
                widgetExplanationStep = 1
                presentationDetent = .large
            }
            .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
            .font(.title2.bold())
            Button("Maybe later"){
                model.showingAction = nil
            }
            .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: true))
        } else if widgetExplanationStep == 1 {
            if #available(iOS 17.0, *){
                Text("Tap and hold anywhere on your Home Screen")
                    .font(.largeTitle.bold())
                    .padding(.top)
                if #available(iOS 18.0, *){
                    Text("Then Tap the \"edit\" in the upper left and choose \"Add Widget\"")
                } else {
                    Text("Then Tap the \"+\" in the upper left")
                }
            } else {
                Text("Update you OS to add a Widget First")
                    .font(.largeTitle.bold())
                    .padding(.top)
            }
                Spacer()
                Image(systemName: "apps.iphone")
                    .resizable()
                    .scaledToFit()
                    .imageScale(.large)
                    .padding()
                    .padding(.top)
                    .padding(.horizontal, 70)
                    .fontWeight(.thin)

                Spacer()
            if #available(iOS 17.0, *){
                Button("Continue"){
                    widgetExplanationStep = 2
                }
                .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
                .font(.title2.bold())

                Button("Cancel"){
                    model.showingAction = nil
                }
                .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: true))
            } else {
                Button("Okay"){
                    model.showingAction = nil
                }
                .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
                .font(.title2.bold())
            }
            } else if widgetExplanationStep == 2 {

            Text("Search for superghost")
                .font(.largeTitle.bold())
                .padding(.top)
            Text("Then add it to your home screen")

            Spacer()
            Image(systemName: "magnifyingglass")
                .resizable()
                .scaledToFit()
                .imageScale(.large)
                .padding()
                .padding(.top)
                .padding(.horizontal, 70)
                .fontWeight(.thin)

            Spacer()
            Button("Continue"){
                widgetExplanationStep = 3

                task?.cancel()
                task = Task{
                    try? await dismissWhenAddedWidget()
                }
            }
            .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
            .font(.title2.bold())
            Button("Cancel"){
                model.showingAction = nil
            }
            .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: true))
        } else {


            Text("Just waiting for you...")
                .font(.largeTitle.bold())
                .padding(.top)
                .opacity(showingScore ? 0.1 : 1)
            Text("Add it to your home screen")
                .opacity(showingScore ? 0.1 : 1)

            Spacer()
            Image(systemName: "clock")
                .resizable()
                .scaledToFit()
                .imageScale(.large)
                .padding()
                .padding(.top)
                .padding(.horizontal, 70)
                .opacity(showingScore ? 0.1 : 1)
                .overlay{
                    scoreChangeOverlay
                }
                .fontWeight(.thin)

            Spacer()
            Button("Cancel"){
                model.showingAction = nil
            }
            .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: true))
            .onDisappear{
                widgetExplanationStep = 0
            }
        }
    }
    @MainActor @ViewBuilder
    func showDoubleXP(title: String, title2: String, subtitle: String, buttonTitle: String) -> some View {
        Text(title)
            .font(.largeTitle.bold())
            .padding(.top)
        Text(title2)
            .bold()
        Spacer()
        Image(systemName: "star.fill")
            .resizable()
            .scaledToFit()
            .imageScale(.large)
            .padding()
            .padding(.top)
            .padding(.horizontal, 70)
            .symbolRenderingMode(.multicolor)
        Spacer()
        Text(subtitle)
            .bold()
        Spacer()
        Button(buttonTitle){
            model.showingAction = nil
        }
        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
        .font(.title2.bold())
    }
    @MainActor @ViewBuilder
    var enableNotifications: some View {
        Text("Enable Notifications")
            .font(.largeTitle.bold())
            .padding(.top)
        Text("Allow notifications now to earn 50XP")
            .bold()
        Spacer()
        Image(systemName: "bell.badge")
            .resizable()
            .scaledToFit()
            .imageScale(.large)
            .padding()
            .padding(.top)
            .padding(.horizontal, 70)
            .opacity(showingScore ? 0.1 : 1)
            .overlay{
                scoreChangeOverlay
            }

        Spacer()
        Button("Allow notifications"){
            UNUserNotificationCenter.current().getNotificationSettings { settings in

                switch settings.authorizationStatus{
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                        Task{await Logger.checkForNotificationStatusChange()}
                    }
                case .denied:
#if os(macOS)
                    showMessage("Open settings to allow notifications.")
#else
                    if let appSettingsURL = URL(string: UIApplication.openSettingsURLString),
                       UIApplication.shared.canOpenURL(appSettingsURL) {
                        UIApplication.shared.open(appSettingsURL)
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
            task?.cancel()
            task = Task{
                try? await dismissWhenNotificationsAllowed()
            }
        }
        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
        .font(.title2.bold())
        Button("Maybe later"){
            model.showingAction = nil
        }
        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: true))
    }
    enum MessagableError: Error {
        case couldntLoadFriends
    }
}
@MainActor
func changeScore(by score: Int) async {
    let isSunday = Calendar.current.component(.weekday, from: .now) == 1
    let isDoubleXP : Bool
    if let data = NSUbiquitousKeyValueStore.default.data(forKey: "doubleXPuntil"),
       let date = try? JSONDecoder().decode(Date.self, from: data),
       date > .now{
            isDoubleXP = true
    } else {isDoubleXP = false}

    let score = score * (isSunday ? 2 : 1) * (isDoubleXP ? 2 : 1)
    try? await Task.sleep(for: .seconds(1))
    if score > 0 {
        try? await SoundManager.shared.play(.won, loop: false)
#if canImport(UIKit)
        showConfetti()
#endif
    } else {
        try? await SoundManager.shared.play(.lost, loop: false)
    }
    try? await Task.sleep(for: .seconds(1.5))
    await MessageModel.shared.changeScore(by: score)
}

#Preview {
    VStack{}.modifier(Messagable())
        .task{
            requestAction(.showDoubleXP)
        }
}

