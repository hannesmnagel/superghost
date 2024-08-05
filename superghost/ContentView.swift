//
//  ContentView.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI
import RevenueCat
import GameKit


extension Date: Swift.RawRepresentable{
    public var rawValue: String {ISO8601Format()}
    public init?(rawValue: String) {
        if let decoded = ISO8601DateFormatter().date(from: rawValue){
            self = decoded
        } else {
            return nil
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @CloudStorage("isFirstUse") var isFirstUse = true
    @CloudStorage("lastViewOfPaywall") var lastPaywallView = Date.distantPast
    @CloudStorage("superghostTrialEnd") var superghostTrialEnd = (Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now)
    @State var isGameViewPresented = false
    @State private var showTrialEndsIn : Int?
    @CloudStorage("isSuperghost") private var isSuperghost = false

    var body: some View {
        Group{
            if isFirstUse{
                FirstUseView()
                    .transition(.opacity)
            } else if isGameViewPresented{
                GameView(isPresented: $isGameViewPresented, isSuperghost: isSuperghost)
            } else {
                HomeView(isSuperghost: isSuperghost, showTrialEndsIn: showTrialEndsIn, isGameViewPresented: $isGameViewPresented)
            }
        }
        .animation(.smooth, value: isFirstUse)
        .animation(.smooth, value: isGameViewPresented)
        .preferredColorScheme(.dark)
        .task(id: superghostTrialEnd) {
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
        .background(Color.black, ignoresSafeAreaEdges: .all)
    }

    func fetchSubscription() async throws {
        let info = try await Purchases.shared.restorePurchases()
        let subscriptions = info.activeSubscriptions
        let timeSinceTrialEnd = Date().timeIntervalSince(superghostTrialEnd)
        let daysSinceTrialEnd = timeSinceTrialEnd / (Calendar.current.dateInterval(of: .day, for: .now)?.duration ?? 1)
        print(daysSinceTrialEnd)
        isSuperghost = subscriptions.contains("monthly.superghost") || timeSinceTrialEnd < 0

        let showedPaywallToday = Calendar.current.isDateInToday(lastPaywallView)

        //is in trial:
        if !subscriptions.contains("monthly.superghost") && timeSinceTrialEnd < 0 {
            showTrialEndsIn = Int(-daysSinceTrialEnd+0.5)
        } else {
            showTrialEndsIn = nil
        }
        //is not superghost, every 4 days:
        if !showedPaywallToday && !isSuperghost && (Int(daysSinceTrialEnd) % 4 == 0 || daysSinceTrialEnd < 3) {
            viewModel.showPaywall = true
            lastPaywallView = Date()
        } else if !showedPaywallToday && Int.random(in: 0...3) == 0{
            showMessage("Add some friends and challenge them!")
            lastPaywallView = Date()
        }
    }
}

#Preview {
    ContentView()
        .modifier(PreviewModifier())
}
