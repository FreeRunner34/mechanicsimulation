import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var isPro = false
    @Published private(set) var isLoadingProduct = false
    @Published var message: String?

    private var transactionTask: Task<Void, Never>?

    func prepare() async {
        startTransactionListenerIfNeeded()
        await refreshEntitlements()
        await loadProduct()
    }

    func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            product = try await Product.products(for: [AppConfig.proProductID]).first
            if product == nil {
                message = "Pro purchase information is not available in this store yet."
            }
        } catch {
            product = nil
            message = "Pro purchase information is unavailable right now."
        }
    }

    func buyPro() async {
        guard let product else {
            message = "Pro is not available from the App Store right now."
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                message = "The purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = isPro ? "Pro access restored." : "No active Pro subscription was found."
        } catch {
            message = "Restore failed: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var active = false
        let now = Date()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == AppConfig.proProductID,
                  transaction.revocationDate == nil else { continue }

            if let expiration = transaction.expirationDate {
                if expiration > now { active = true }
            } else {
                active = true
            }
        }

        isPro = active
    }

    private func startTransactionListenerIfNeeded() {
        guard transactionTask == nil else { return }
        transactionTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else { continue }

                if transaction.productID == AppConfig.proProductID {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw PurchaseError.failedVerification
        }
    }

    deinit { transactionTask?.cancel() }

    enum PurchaseError: Error {
        case failedVerification
    }
}
