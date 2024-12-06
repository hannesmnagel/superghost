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

    @State private var product : Product? = nil


    let accentColor: Color = .init(red: 150/255, green: 15/255, blue: 40/255)

    var body: some View {
        VStack{
            Image("Skin/Christmas")
                .resizable()
                .scaledToFit()
                .clipShape(.rect(bottomLeadingRadius: 30, bottomTrailingRadius: 30))
                .ignoresSafeArea()
                .frame(maxWidth: 800, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()

            Text("Become a Superghost")
                .font(.largeTitle.bold())
                .foregroundStyle(.accent)
            Text("~80% off")
                .foregroundStyle(.accent)
                .bold()
            Spacer()

            VStack(alignment: .leading){
                Text("+ ").foregroundColor(.accent) + Text("Loose up to 10 times a day")
                Text("+ ").foregroundColor(.accent) + Text("Advanced Gameplay")
                Text("+ ").foregroundColor(.accent) + Text("Customize App Icon")
                Text("+ ").foregroundColor(.accent) + Text("Unlock more Skins")
            }
            .padding()
            Spacer()
            if #available(iOS 17.0, *) {
                PurchaseProductButton(product: product) {
                    dismiss()
                }
                .padding(.horizontal)
            } else {
#if !os(visionOS)
                LegacyPurchaseProductButton(product: product) {
                    dismiss()
                }
                .padding(.horizontal)
#endif
            }


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
            .font(.callout)
            .padding(.horizontal)
            .buttonStyle(.plain)
        }
        .background(.thinMaterial, ignoresSafeAreaEdges: .all)
        .background(
            LinearGradient(
                stops: [.init(color: .red, location: 0), .init(color: .clear, location: 1)],
                startPoint: .top,
                endPoint: .bottom
            ),
            ignoresSafeAreaEdges: .all
        )
        .font(.title2)
        .task {
            product = try? await Product.products(for: ["onetime.superghost"]).first
        }
#if !os(macOS)
        .toolbarBackground(.hidden, for: .navigationBar)
#endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
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
}


@available(iOS 17.0, *)
struct PurchaseProductButton: View {
    let product: Product?
    let onPurchase: ()->Void
    @Environment(\.purchase) var purchase
    @State private var disabled = false

    var body: some View {
        Button("Continue for \(product?.displayPrice ?? "...")"){
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
        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
        .bold()
    }
}

@available(visionOS, unavailable)
struct LegacyPurchaseProductButton: View {
    let product: Product?
    let onPurchase: ()->Void
    @State private var disabled = false

    var body: some View {
        Button("Continue for \(product?.displayPrice ?? "...")"){
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
        .buttonStyle(AppearanceManager.FullWidthButtonStyle(isSecondary: false))
        .bold()
    }
}


#Preview {
    NavigationStack{
        PaywallView{}
            .modifier(PreviewModifier())
            .tint(.accent)
    }
}
