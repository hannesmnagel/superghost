//
//  ContentView.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import RevenueCat

struct BlackOutTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase == .identity ? 0 : 10)
            .overlay{
                if !(phase == .identity){
                    Rectangle().fill(Color.black).ignoresSafeArea()
                }
            }
    }
}

struct ContentView: View {
    @AppStorage("isFirstUse") var isFirstUse = true
    @State var isGameViewPresented = false
    @StateObject var viewModel = GameViewModel()
    @State private var showTrialEndsIn : Int?
    @State private var isSuperghost = false

    var body: some View {
        Group{
            if isFirstUse{
                FirstUseView()
                    .transition(BlackOutTransition())
            } else if isGameViewPresented{
                GameView(viewModel: viewModel, isPresented: $isGameViewPresented)
                    .transition(BlackOutTransition())
            } else {
                HomeView(isSuperghost: isSuperghost, viewModel: viewModel, isGameViewPresented: $isGameViewPresented)
                    .transition(BlackOutTransition())
            }
        }
        .animation(.smooth, value: isFirstUse)
        .animation(.smooth, value: isGameViewPresented)
        .preferredColorScheme(.dark)
        .task {
            do{
                try await fetchSubscription()
            } catch {
                print(error)
            }
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            Task{try? await fetchSubscription()}
        } content: {
            PaywallView()
        }
        .fontDesign(.rounded)
    }

    func fetchSubscription() async throws {
        let info = try await Purchases.shared.customerInfo()
        let subscriptions = info.activeSubscriptions
        let timeSinceTrialEnd = (Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now).timeIntervalSince(info.firstSeen)
        let daysSinceTrialEnd = timeSinceTrialEnd / (Calendar.current.dateInterval(of: .day, for: .now)?.duration ?? 1)
        isSuperghost = subscriptions.contains("monthly.superghost") || timeSinceTrialEnd < 0

        //is in trial:
        if !subscriptions.contains("monthly.superghost") && timeSinceTrialEnd < 0 {
            showTrialEndsIn = Int(-daysSinceTrialEnd)
        }
        //is not superghost, every 4 days:
        if !isSuperghost && (Int(daysSinceTrialEnd) % 4 == 0 || daysSinceTrialEnd < 3) {
            viewModel.showPaywall = true
        }
    }
}

#Preview {
    ContentView()
        .modifier(PreviewModifier())
}

import TipKit

struct HowToPlayTip: Tip {
    var title = Text("Get Started")
    var message = Text("Learn how to play and view tips to win!")
    var actions : [Tip.Action] { [Tip.Action(id: "learn-how-to-play", title: "Learn more")] }
}
