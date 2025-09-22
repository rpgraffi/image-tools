import Foundation
import StoreKit

final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published var isPurchasing: Bool = false
    @Published var isProUnlocked: Bool = false
    @Published var purchaseError: String? = nil
    @Published var lifetimeProduct: Product? = nil

    private var configured = false
    private let lifetimeProductId: String = "lifetime"

    private init() {}

    func configure() {
        guard !configured else { return }
        configured = true
        Task { await refreshEntitlement() }
        Task { await observeTransactions() }
        Task { await loadProducts() }
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [lifetimeProductId])
            await MainActor.run { self.lifetimeProduct = products.first }
        } catch {
            // Keep silent; UI can retry via purchase
        }
    }

    func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == lifetimeProductId {
                await MainActor.run { self.isProUnlocked = true }
            }
        }
    }

    func observeTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                if transaction.productID == lifetimeProductId {
                    await MainActor.run { self.isProUnlocked = true }
                }
                await transaction.finish()
            }
        }
    }

    func purchaseLifetime() async {
        if lifetimeProduct == nil { await loadProducts() }
        guard let product = lifetimeProduct else {
            await MainActor.run { self.purchaseError = "Product not available. Please try again." }
            return
        }
        await MainActor.run { self.isPurchasing = true }
        defer { Task { await MainActor.run { self.isPurchasing = false } } }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    if transaction.productID == lifetimeProductId {
                        await MainActor.run { self.isProUnlocked = true }
                    }
                    await transaction.finish()
                }
            case .userCancelled, .pending: break
            @unknown default: break
            }
        } catch {
            await MainActor.run { self.purchaseError = "Purchase failed. Please try again." }
        }
    }
}


