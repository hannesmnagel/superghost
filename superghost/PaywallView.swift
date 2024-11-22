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
                #if os(visionOS)
                    .padding(.trailing, 80)
                #endif

                VStack{
                    Text("Become a Superghost")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.accent)
                    if viewAllPlans {
                        ForEach(products) { product in
                            Button{
                                selectedProduct = product
                            } label: {
                                Text("\(product.displayPrice) \(subscriptionDuration(for: product))")
                                    .foregroundStyle(selectedProduct == product ? .accent : .secondary)
                                    .padding(.vertical, 5)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(selectedProduct == product ? .accent : .secondary)
                                    )
                                    .padding(.horizontal)
                            }
                        }

                    } else {
                        Spacer()
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
                        if #available(iOS 17.0, *) {
                            PurchaseProductButton(product: selectedProduct) {
                                dismiss()
                            }
                        } else {
#if !os(visionOS)
                            LegacyPurchaseProductButton(product: selectedProduct) {
                                dismiss()
                            }
#endif
                        }
                        if let selectedProduct, viewAllPlans {
                            Text("Get Access to Superghost for \(selectedProduct.displayPrice) \(subscriptionDuration(for: selectedProduct))")
                                .font(.footnote)
                        } else if !viewAllPlans {
                            VStack{

                                Button("View All Plans"){
                                    viewAllPlans = true
                                }
                                .foregroundStyle(.accent)
                                .font(.body)
                                .padding(.bottom)
                                #if os(visionOS)
                                .padding()
                                #endif

                                HStack{
                                    Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                        .foregroundStyle(.primary)
                                    Spacer()

                                    Button("Restore"){
                                        Task {
                                            try? await AppStore.sync()
                                        }
                                    }
                                    Spacer()
                                    Link("Privacy", destination: URL(string: "https://hannesnagel.com/ghost-privacy")!)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .font(.callout)
                            .padding(.horizontal)
                            .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .plain))
                        }
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
                .buttonBorderShape(.bcCircle)
                .background(.black)
                .clipShape(.circle)
                .keyboardShortcut(.cancelAction)
            }
        }
        #if os(visionOS)
        .padding(.bottom, 50)
        #endif
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


@available(iOS 17.0, *)
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

@available(visionOS, unavailable)
struct LegacyPurchaseProductButton: View {
    let product: Product?
    let onPurchase: ()->Void
    @State private var disabled = false
    
    var body: some View {
        Button("Continue"){
            Task{
                guard let product else {return}
                disabled = true
                defer{disabled = false}
                switch try await product.purchase( options: [.simulatesAskToBuyInSandbox(false)]){
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
