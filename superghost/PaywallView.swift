//
//  PaywallView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/12/24.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallView: View {
    @State private var products : Result<Offerings,(any Error)>? = nil
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack{
            if let products{
                switch products {
                case .success(let offering):
                    if let offering = offering.current {
                        RevenueCatUI.PaywallView(offering: offering, displayCloseButton: true)
                            .onRequestedDismissal {
                                dismiss()
                            }
                    } else {
                        ContentUnavailableView("There is nothing available to purchase", systemImage: "questionmark.folder", description: Text("No products found"))
                    }
                case .failure(_):
                    ContentUnavailableView("You can't upgrade right now", systemImage: "network.slash", description: Text("An error occured"))
                }
            }
        }
            .task {
                do{
                    products = try await .success(Purchases.shared.offerings())
                } catch{
                    products = .failure(error)
                }
            }
    }
}

#Preview {
    PaywallView()
        .modifier(PreviewModifier())
}
