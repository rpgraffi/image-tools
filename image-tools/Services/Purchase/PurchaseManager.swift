import Foundation
import StoreKit

final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published var isPurchasing: Bool = false
    @Published var isProUnlocked: Bool = false
    @Published var purchaseError: String? = nil
    @Published var lifetimeProduct: Product? = nil
    @Published var lifetimeRegularProduct: Product? = nil
    
    var lifetimeDisplayPrice: String? { lifetimeProduct?.displayPrice }
    var lifetimeRegularDisplayPrice: String? { lifetimeRegularProduct?.displayPrice }

    private var configured = false
    private let lifetimeProductId: String = "lifetime"
    private let lifetimeRegularProductId: String = "lifetime_regular"
    private var proEntitlementProductIds: Set<String> { [lifetimeProductId, lifetimeRegularProductId] }

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
            let products = try await Product.products(for: [lifetimeProductId, lifetimeRegularProductId])
            await MainActor.run {
                self.lifetimeProduct = products.first(where: { $0.id == lifetimeProductId })
                self.lifetimeRegularProduct = products.first(where: { $0.id == lifetimeRegularProductId })
            }
        } catch {
            // Keep silent; UI can retry via purchase
        }
    }

    func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, proEntitlementProductIds.contains(transaction.productID) {
                await MainActor.run { self.isProUnlocked = true }
            }
        }
    }

    func observeTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                if proEntitlementProductIds.contains(transaction.productID) {
                    await MainActor.run { self.isProUnlocked = true }
                }
                await transaction.finish()
            }
        }
    }

    func purchaseLifetime() async {
        if lifetimeProduct == nil && lifetimeRegularProduct == nil { await loadProducts() }
        guard let product = lifetimeProduct ?? lifetimeRegularProduct else {
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
                    if proEntitlementProductIds.contains(transaction.productID) {
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

    func restorePurchases() async {
        await MainActor.run { self.isPurchasing = true }
        defer { Task { await MainActor.run { self.isPurchasing = false } } }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            await MainActor.run { self.purchaseError = "Restore failed. Please try again." }
        }
    }
}


