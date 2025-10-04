import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var isPurchasing = false
    @Published private(set) var isProUnlocked = false
    @Published var purchaseError: String?
    @Published var lifetimeDisplayPrice: String?
    @Published var lifetimeRegularDisplayPrice: String?
    
    // MARK: - Private Properties
    
    private var lifetimeProduct: Product?
    private var lifetimeRegularProduct: Product?
    private var transactionUpdateTask: Task<Void, Never>?
    
    private let lifetimeProductId = "lifetime"
    private let lifetimeRegularProductId = "lifetime_regular"
    private var proEntitlementProductIds: Set<String> {
        [lifetimeProductId, lifetimeRegularProductId]
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    deinit {
        transactionUpdateTask?.cancel()
    }
    
    // MARK: - Configuration
    
    func configure() {
        guard transactionUpdateTask == nil else { return }
        
        transactionUpdateTask = Task {
            await observeTransactions()
        }
        
        Task {
            await checkEntitlements()
            await loadProducts()
        }
    }
    
    // MARK: - Products
    
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [lifetimeProductId, lifetimeRegularProductId])
            
            lifetimeProduct = products.first(where: { $0.id == lifetimeProductId })
            lifetimeRegularProduct = products.first(where: { $0.id == lifetimeRegularProductId })
            
            lifetimeDisplayPrice = lifetimeProduct?.displayPrice
            lifetimeRegularDisplayPrice = lifetimeRegularProduct?.displayPrice
            
            #if DEBUG
            print("🔵 PurchaseManager: Loaded \(products.count) products")
            #endif
        } catch {
            #if DEBUG
            print("🔴 PurchaseManager: Failed to load products - \(error)")
            #endif
        }
    }
    
    // MARK: - Entitlements
    
    func checkEntitlements() async {
        var hasEntitlement = false
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if proEntitlementProductIds.contains(transaction.productID) {
                hasEntitlement = true
                break
            }
        }
        
        isProUnlocked = hasEntitlement
        
        #if DEBUG
        print("🔵 PurchaseManager: Pro unlocked = \(isProUnlocked)")
        #endif
    }
    
    private func observeTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            #if DEBUG
            print("🔵 PurchaseManager: Transaction update - \(transaction.productID)")
            #endif
            
            if proEntitlementProductIds.contains(transaction.productID) {
                isProUnlocked = true
            }
            
            await transaction.finish()
        }
    }
    
    // MARK: - Purchase
    
    func purchaseLifetime() async {
        guard !isPurchasing else { return }
        
        // Load products if needed
        if lifetimeProduct == nil && lifetimeRegularProduct == nil {
            await loadProducts()
        }
        
        guard let product = lifetimeProduct ?? lifetimeRegularProduct else {
            purchaseError = "Product not available. Please try again."
            return
        }
        
        isPurchasing = true
        purchaseError = nil
        
        defer { isPurchasing = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "Purchase verification failed."
                    return
                }
                
                if proEntitlementProductIds.contains(transaction.productID) {
                    isProUnlocked = true
                }
                
                await transaction.finish()
                
                #if DEBUG
                print("🟢 PurchaseManager: Purchase successful")
                #endif
                
            case .userCancelled:
                #if DEBUG
                print("🟡 PurchaseManager: Purchase cancelled by user")
                #endif
                
            case .pending:
                #if DEBUG
                print("🟡 PurchaseManager: Purchase pending")
                #endif
                
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed. Please try again."
            #if DEBUG
            print("🔴 PurchaseManager: Purchase error - \(error)")
            #endif
        }
    }
    
    // MARK: - Restore
    
    func restorePurchases() async {
        guard !isPurchasing else { return }
        
        isPurchasing = true
        purchaseError = nil
        
        defer { isPurchasing = false }
        
        do {
            try await AppStore.sync()
            await checkEntitlements()
            
            #if DEBUG
            print("🟢 PurchaseManager: Restore successful")
            #endif
        } catch {
            purchaseError = "Restore failed. Please try again."
            #if DEBUG
            print("🔴 PurchaseManager: Restore error - \(error)")
            #endif
        }
    }
}


