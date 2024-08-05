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
                        #if !os(macOS)
                        RevenueCatUI.PaywallView(offering: offering, displayCloseButton: true)
                            .onRequestedDismissal {
                                dismiss()
                            }
#else
                        if let package = offering.availablePackages.first {
                            Spacer()
                            Text("Become a Superghost")
                                .font(.largeTitle)
                            Spacer()
                            Text("For only \(package.storeProduct.localizedPriceString) per Month. ")
                            Text("Auto-Renews. Cancel Anytime.")
                            Spacer()
                                .toolbar{
                                    ToolbarItem(placement: .destructiveAction){
                                        AsyncButton{
                                            dismiss()
                                        } label: {
                                            Text("Cancel")
                                        }
                                    }
                                    ToolbarItem(placement: .cancellationAction){
                                        AsyncButton{
                                            let _ = try await Purchases.shared.restorePurchases()
                                            dismiss()
                                        } label: {
                                            Text("Restore Purchases")
                                        }
                                    }
                                    ToolbarItem(placement: .confirmationAction){
                                        AsyncButton{
                                            let _ = try await Purchases.shared.purchase(package: package)
                                            dismiss()
                                        } label: {
                                            Text("Continue")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .buttonBorderShape(.capsule)
                                    }
                                }
                        }
                        #endif
                    } else {
                        ContentPlaceHolderView("There is nothing available to purchase", systemImage: "questionmark.folder", description: "No products found")
                    }
                case .failure(_):
                    ContentPlaceHolderView("You can't upgrade right now", systemImage: "network.slash", description: "An error occured")
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
