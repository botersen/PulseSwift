//
//  SubscriptionManager.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import Foundation
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var availableProducts: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var currentTier: SubscriptionTier = .free
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let productIDs = ["pulse_premium_monthly"]
    private var updates: Task<Void, Never>?
    
    init() {
        updates = observeTransactionUpdates()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - Public Methods
    
    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case let .success(.verified(transaction)):
                await transaction.finish()
                await updatePurchasedProducts()
                errorMessage = nil
                
            case let .success(.unverified(_, error)):
                errorMessage = "Purchase verification failed: \(error.localizedDescription)"
                
            case .pending:
                errorMessage = "Purchase is pending approval"
                
            case .userCancelled:
                errorMessage = nil
                
            @unknown default:
                errorMessage = "Unknown purchase result"
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Feature Gating
    
    func canSendPulse(currentCount: Int) -> Bool {
        switch currentTier {
        case .free:
            return currentCount < SubscriptionTier.free.maxPulsesPerDay
        case .premium:
            return true
        }
    }
    
    func canUseTranslation(currentCount: Int) -> Bool {
        switch currentTier {
        case .free:
            return currentCount < SubscriptionTier.free.maxTranslationsPerDay
        case .premium:
            return currentCount < SubscriptionTier.premium.maxTranslationsPerDay
        }
    }
    
    func canUseGlobalRadius() -> Bool {
        return currentTier.allowsGlobalMatching
    }
    
    func maxAllowedRadius() -> Double {
        return currentTier.maxRadiusMeters
    }
    
    func hasPriorityMatching() -> Bool {
        return currentTier.hasPriorityMatching
    }
    
    var isPremiumActive: Bool {
        return currentTier == .premium
    }
    
    // MARK: - Private Methods
    
    private func loadProducts() async {
        do {
            availableProducts = try await Product.products(for: productIDs)
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }
    
    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result {
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
        
        // Update subscription tier based on purchases
        if purchasedIDs.contains("pulse_premium_monthly") {
            currentTier = .premium
        } else {
            currentTier = .free
        }
    }
    
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await _ in Transaction.updates {
                await self?.updatePurchasedProducts()
            }
        }
    }
}

// MARK: - Extensions

extension SubscriptionManager {
    var premiumProduct: Product? {
        availableProducts.first { $0.id == "pulse_premium_monthly" }
    }
    
    var formattedPremiumPrice: String {
        premiumProduct?.displayPrice ?? "$3.99"
    }
} 