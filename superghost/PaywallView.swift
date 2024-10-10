//
//  PaywallView.swift
//  superghost
//
//  Created by Hannes Nagel on 7/12/24.
//

import SwiftUI
import StoreKit


struct PaywallView: View {
    let dismiss: ()->Void
    
    @State private var viewAllPlans = false
    @State private var selectedProduct : Product? = nil
    @State private var products = [Product]()
    
    
    var body: some View {
        VStack{
            
            VStack(spacing: 0){
                Image(.ghostStars)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(bottomLeadingRadius: 20, bottomTrailingRadius: 20))
                    .ignoresSafeArea(edges: .top)
                    .layoutPriority(1)
                Text("Become a Superghost")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.accent)
                Spacer()
                if viewAllPlans {
                    ForEach(products) { product in
                        Button{
                            selectedProduct = product
                        } label: {
                            Text("\(product.displayPrice) \(subscriptionDuration(for: product))")
                                .foregroundStyle(selectedProduct == product ? .accent : .secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(selectedProduct == product ? .accent : .secondary)
                                )
                                .padding(.horizontal)
                                .padding(.vertical, 5)
                        }
                    }
                    
                } else {
                    VStack(alignment: .leading){
                        Text("+ ").foregroundColor(.accent) + Text("Loose up to 10 times a day")
                        Text("+ ").foregroundColor(.accent) + Text("Advanced Gameplay")
                        Text("+ ").foregroundColor(.accent) + Text("Customize App Icon")
                    }
                }
                Spacer()
                VStack{
                    if let selectedProduct, !viewAllPlans {
                        Text("Get Access to Superghost for \(selectedProduct.displayPrice) \(subscriptionDuration(for: selectedProduct))")
                            .font(.footnote)
                    }
                    PurchaseProductButton(product: selectedProduct) {
                        dismiss()
                    }
                    if let selectedProduct, viewAllPlans {
                        Text("Get Access to Superghost for \(selectedProduct.displayPrice) \(subscriptionDuration(for: selectedProduct))")
                            .font(.footnote)
                    } else if !viewAllPlans {
                        Button("View All Plans"){
                            viewAllPlans = true
                        }
                        .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .plain))
                    }
                }
            }
            .font(.title2)
            .task {
                selectedProduct = try? await Product.products(for: ["monthly.superghost"]).first
                products = (try? await Product.products(for: ["monthly.superghost", "annual.superghost","onetime.superghost"])) ?? []
            }
        }
        #if !os(macOS)
        .toolbarBackground(.hidden, for: .navigationBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .bordered))
                .buttonBorderShape(.circle)
                .background(.black)
                .clipShape(.circle)
                .keyboardShortcut(.cancelAction)
            }
        }
    }
    func subscriptionDuration(for product: Product) -> String {
        if let subscriptionPeriod = product.subscription?.subscriptionPeriod {
            switch subscriptionPeriod.unit {
            case .day:
                return "Daily"
            case .week:
                return "Weekly"
            case .month:
                return "Monthly"
            case .year:
                return "Annually"
            @unknown default:
                return "Unknown duration"
            }
        } else {
            return "Lifetime"
        }
    }
}

struct PurchaseProductButton: View {
    let product: Product?
    let onPurchase: ()->Void
    @Environment(\.purchase) var purchase
    @State private var disabled = false
    
    var body: some View {
        Button("Continue"){
            Task{
                guard let product else {return}
                disabled = true
                defer{disabled = false}
                switch try await purchase(product, options: [.simulatesAskToBuyInSandbox(false)]){
                case .success(_):
                    onPurchase()
                default: return
                }
            }
        }
        .disabled(disabled || product == nil)
        .buttonStyle(AppearanceManager.HapticStlyeCustom(buttonStyle: AppearanceManager.FullWidthButtonStyle(isSecondary: false)))
        .bold()
    }
}


#Preview {
    PaywallView{}
        .modifier(PreviewModifier())
}
