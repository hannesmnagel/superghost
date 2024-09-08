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
                .multilineTextAlignment(.center)
                .presentationDetents([.fraction(0.7), .large])
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
        try? await Task.sleep(for: .seconds(1))
        await MainActor.run{
            withAnimation(.smooth(duration: 2, extraBounce: 1)) {
                score += 50
            }
            Logger.score.info("Increased score by 50 because user added a friend.")
        }
        try? await Task.sleep(for: .seconds(2))
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
        try? await Task.sleep(for: .seconds(1))
        await MainActor.run{
            withAnimation(.smooth(duration: 2, extraBounce: 1)) {
                score += 50
            }
            Logger.score.info("Increased score by 50 because user added a widget.")
        }
        try? await Task.sleep(for: .seconds(2))
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
        try? await Task.sleep(for: .seconds(1))
        await MainActor.run{
            withAnimation(.smooth(duration: 2, extraBounce: 1)) {
                score += 50
            }
            Logger.score.info("Increased score by 50 because user allowed notifications")
        }
        try? await Task.sleep(for: .seconds(2))
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
        GKLocalPlayer.local.asyncImage(.normal)
            .padding(.top)
            .padding(.horizontal, 70)
            .opacity(showingScore ? 0.1 : 1)
            .overlay{
                scoreChangeOverlay
            }
        Spacer()
        Text("Why don't you add some Friends?")
            .font(.largeTitle.bold())
        Text("Add a Friend now to earn 50XP")
            .bold()
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
        .buttonStyle(.borderedProminent)
        .font(.title2.bold())
        Button("Maybe later"){
            model.showingAction = nil
        }
        .buttonStyle(.bordered)
    }
    @MainActor @ViewBuilder
    var addWidget: some View{
        Image(systemName: "widget.small.badge.plus")
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
        Text("Why don't you add a Widget?")
            .font(.largeTitle.bold())
        Text("Add a widget now to earn 50XP")
            .bold()
        Spacer()
        AsyncButton{
            task?.cancel()
            task = Task{
                try? await dismissWhenAddedWidget()
            }
            await task?.value
        } label: {
            Text("Okay, I added one!")
        }
        .buttonStyle(.borderedProminent)
        .font(.title2.bold())
        Button("Maybe later"){
            model.showingAction = nil
        }
        .buttonStyle(.bordered)
    }

    @MainActor @ViewBuilder
    var enableNotifications: some View {
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
        Text("Enable Notifications")
            .font(.largeTitle.bold())
        Text("Allow notifications now to earn 50XP")
            .bold()
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
        .buttonStyle(.borderedProminent)
        .font(.title2.bold())
        Button("Maybe later"){
            model.showingAction = nil
        }
        .buttonStyle(.bordered)
    }
}
@MainActor
func changeScore(by score: Int) {
    let isEndOfWeek = Calendar.current.component(.weekday, from: .now) == ((Calendar.current.firstWeekday + 6) % 7)
    Logger.score.info("Is end of week: \(isEndOfWeek, format: .answer, privacy: .public)")
    let score = score * (isEndOfWeek ? 2 : 1)
    if score > 0 {
#if canImport(UIKit)
        Task{
            try? await Task.sleep(for: .seconds(2))
            showConfetti(on: UIApplication.shared.topViewController() ?? ViewController())
        }
#endif
    }
    MessageModel.shared.showingScoreChangeBy = score
    let data = NSUbiquitousKeyValueStore.default.data(forKey: "score")
    if let oldScore = try? JSONDecoder().decode(Int.self, from: data ?? Data()){
        Task{
            try? await GameStat.submitScore(
                oldScore + score
            )
        }
    }
}

#Preview {
    VStack{}.modifier(Messagable())
        .task{
            requestAction(.enableNotifications)
        }
}

