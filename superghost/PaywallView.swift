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
                            AsyncButton{
                                let _ = try await Purchases.shared.purchase(package: package)
                                dismiss()
                            } label: {
                                Text("Continue")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            AsyncButton{
                                let _ = try await Purchases.shared.restorePurchases()
                                dismiss()
                            } label: {
                                Text("Restore Purchases")
                            }
                        }
                        #endif
                    } else {
                        ContentUnavailableView("There is nothing available to purchase", systemImage: "questionmark.folder", description: Text("No products found"))
                    }
                case .failure(let error):
                    ContentUnavailableView("You can't upgrade right now", systemImage: "network.slash", description: Text("An error occured"))
                    Text(error.localizedDescription)
                        .contextMenu{
                        Button(
                                (try? String(contentsOf: Bundle.main.resourceURL!.appending(path: "revenuecatkey.txt"))) ?? "none"
                        ) {
                            #if os(iOS)
                            UIPasteboard.general.string = (try? String(contentsOf: Bundle.main.resourceURL!.appending(path: "revenuecatkey.txt"))) ?? "none"
#endif

                        }
                        }
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
