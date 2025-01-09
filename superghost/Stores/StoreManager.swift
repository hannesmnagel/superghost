//
//  StoreManager.swift
//  superghost
//
//  Created by Melanie Nagel   on 10/9/24.
//

import Foundation
import StoreKit

@globalActor
actor StoreManagerActor: GlobalActor {
    static let shared = StoreManagerActor()
}

@StoreManagerActor
final class StoreManager: ObservableObject {
    private(set) var purchasedProductIDs = Set<String>()

    private var updates: Task<Void, Never>? = nil

    init() {
        Task{@StoreManagerActor in
            updates = observeTransactionUpdates()
        }
    }

    deinit {
        updates?.cancel()
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [unowned self] in
            for await _ in Transaction.updates {
                // Using verificationResult directly would be better
                // but this way works for this tutorial
                await self.updatePurchasedProducts()
            }
        }
    }

    func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            if transaction.revocationDate == nil {
                self.purchasedProductIDs.insert(transaction.productID)
            } else {
                self.purchasedProductIDs.remove(transaction.productID)
            }
            await transaction.finish()
        }
        try? await GKStore.shared.fetchSubscription()
    }
    static let shared = StoreManager()
}
