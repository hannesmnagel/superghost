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
    }
}

struct ContentView: View {
    @AppStorage("isFirstUse") var isFirstUse = true
    @AppStorage("lastPaywallView") var lastPaywallView = Date.distantPast.ISO8601Format()
    @State var isGameViewPresented = false
    @StateObject var viewModel = GameViewModel()
    @State private var showTrialEndsIn : Int?
    @AppStorage("isSuperghost", store: UserDefaults(suiteName: "group.com.nagel.superghost") ?? .standard) private var isSuperghost = false

    var body: some View {
        Group{
            if isFirstUse{
                FirstUseView()
                    .transition(BlackOutTransition())
            } else if isGameViewPresented{
                GameView(isPresented: $isGameViewPresented, isSuperghost: isSuperghost)
            } else {
                HomeView(isSuperghost: isSuperghost, showTrialEndsIn: showTrialEndsIn, isGameViewPresented: $isGameViewPresented)
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
#if os(macOS)
                .frame(minWidth: 500, minHeight: 500)
#endif
        }
        .fontDesign(.rounded)
        .environmentObject(viewModel)
    }

    func fetchSubscription() async throws {
        let info = try await Purchases.shared.restorePurchases()
        let subscriptions = info.activeSubscriptions
        let timeSinceTrialEnd = (Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now).timeIntervalSince(info.firstSeen)
        let daysSinceTrialEnd = timeSinceTrialEnd / (Calendar.current.dateInterval(of: .day, for: .now)?.duration ?? 1)
        isSuperghost = subscriptions.contains("monthly.superghost") || timeSinceTrialEnd < 0

        //is in trial:
        if !subscriptions.contains("monthly.superghost") && timeSinceTrialEnd < 0 {
            showTrialEndsIn = Int(-daysSinceTrialEnd)
        } else {
            showTrialEndsIn = nil
        }
        //is not superghost, every 4 days:
        let showedPaywallToday = Calendar.current.isDateInToday(ISO8601DateFormatter().date(from: lastPaywallView) ?? Date.distantPast)
        if !showedPaywallToday && !isSuperghost && (Int(daysSinceTrialEnd) % 4 == 0 || daysSinceTrialEnd < 3) {
            viewModel.showPaywall = true
            lastPaywallView = Date().ISO8601Format()
        }
    }
}

#Preview {
    ContentView()
        .modifier(PreviewModifier())
}
