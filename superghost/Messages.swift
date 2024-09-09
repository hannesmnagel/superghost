//
//  Messages.swift
//  superghost
//
//  Created by Hannes Nagel on 8/4/24.
//

import SwiftUI
import GameKit
import UserNotifications

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
                        Color.black
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea()
                            .transition(.opacity)
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
                            withAnimation(.smooth){
                                model.message = Array(model.message.dropFirst())
                            }
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
                    }
                }
                .padding(.horizontal)
                .multilineTextAlignment(.center)
                .presentationDetents([.medium, .large], selection: $presentationDetent)
            }

    }
    nonisolated private func dismissWhenAddedFriends() async throws {
        while try await GKLocalPlayer.local.loadFriends().isEmpty {
            try? await Task.sleep(for: .seconds(1))
        }
        try? await GameStat.submitScore(score + 50)
        await MainActor.run{
            showingScore = true
        }
        await MainActor.run{
            changeScore(by: 50)
            Logger.score.info("Increased score by 50 because user added a friend.")
        }
        try? await Task.sleep(for: .seconds(6))
        await MainActor.run{
            model.showingAction = nil
            showingScore = false
        }
    }
    nonisolated private func dismissWhenAddedWidget() async throws {
        while NSUbiquitousKeyValueStore.default.double(forKey: Achievement.widgetAdd.rawValue) != 100 {
            try? await Task.sleep(for: .seconds(1))
        }
        try? await GameStat.submitScore(score + 50)
        await MainActor.run{
            showingScore = true
        }
        await MainActor.run{
            changeScore(by: 50)
            Logger.score.info("Increased score by 50 because user added a widget.")
        }
        try? await Task.sleep(for: .seconds(6))
        await MainActor.run{
            model.showingAction = nil
            showingScore = false
        }
    }
    nonisolated private func dismissWhenNotificationsAllowed() async throws {
        
        while await (UNUserNotificationCenter.current().notificationSettings().authorizationStatus != .authorized) {
            try? await Task.sleep(for: .seconds(1))
        }
        Task.detached{
            try? await GameStat.submitScore(score + 50)
        }
        await MainActor.run{
            showingScore = true
        }
        await MainActor.run{
            changeScore(by: 50)
            Logger.score.info("Increased score by 50 because user allowed notifications")
        }
        try? await Task.sleep(for: .seconds(6))
        await MainActor.run{
            model.showingAction = nil
            showingScore = false
        }
    }

    @MainActor @ViewBuilder
    var scoreChangeOverlay: some View {
        if showingScore{
            let transition : ContentTransition =
            if #available(iOS 17.0, macOS 14.0, *){
                .numericText(value: Double(score))
            } else {
                .numericText()
            }
            Text(score, format: .number)
                .font(.system(size: 70))
                .contentTransition(transition)
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
            Text("And earn an extra 50 XP")
                .bold()
            Spacer()

            Image(systemName: "apps.iphone.badge.plus")
                .resizable()
                .scaledToFit()
                .imageScale(.large)
                .padding()
                .padding(.top)
                .padding(.horizontal, 70)
                .fontWeight(.thin)

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

            Text("Tap and hold anywhere on your Home Screen")
                .font(.largeTitle.bold())
                .padding(.top)
            if #available(iOS 18.0, *){
                Text("Then Tap the \"edit\" in the upper left and choose \"Add Widget\"")
            } else {
                Text("Then Tap the \"+\" in the upper left")
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
            Button("Continue"){
                widgetExplanationStep = 2
            }
            .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
            .font(.title2.bold())
            Button("Cancel"){
                model.showingAction = nil
            }
            .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: true))
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
        }
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
            Task{
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                switch settings.authorizationStatus{
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
}
@MainActor
func changeScore(by score: Int) {
    let isEndOfWeek = Calendar.current.component(.weekday, from: .now) == ((Calendar.current.firstWeekday + 6) % 7)
    Logger.score.info("Is end of week: \(isEndOfWeek, format: .answer, privacy: .public)")
    let score = score * (isEndOfWeek ? 2 : 1)
#if canImport(UIKit)
        Task{
            try? await Task.sleep(for: .seconds(2))
            if score > 0 {
                try? await SoundManager.shared.play(.won, loop: false)
                showConfetti()
            }
            try? await Task.sleep(for: .seconds(1.5))
            await MessageModel.shared.changeScore(by: score)
        }
#endif
}

#Preview {
    VStack{}.modifier(Messagable())
        .task{
            requestAction(.addWidget)
        }
}

