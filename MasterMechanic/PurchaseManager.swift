import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var isPro = false
    @Published var message: String?

    func prepare() async {
        await refreshEntitlements()
        do {
            product = try await Product.products(for: [AppConfig.proProductID]).first
        } catch {
            message = "Pro purchase information is unavailable right now."
        }
    }

    func buyPro() async {
        guard let product else {
            message = "Create the StoreKit product \(AppConfig.proProductID) in App Store Connect before testing purchases."
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
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == AppConfig.proProductID, transaction.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw PurchaseError.failedVerification
        }
    }

    enum PurchaseError: Error { case failedVerification }
}
