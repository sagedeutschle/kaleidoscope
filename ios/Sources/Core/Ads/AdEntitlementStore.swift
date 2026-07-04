import Combine
import CryptoKit
import Foundation
import StoreKit

enum AdUnlockSource: String, Codable, Equatable {
    case testerCode
    case storePurchase
}

struct AdEntitlementState: Codable, Equatable {
    var adsRemoved: Bool
    var unlockSource: AdUnlockSource?
    var unlockedAt: Date?
    var transactionID: String?

    static let locked = AdEntitlementState(
        adsRemoved: false,
        unlockSource: nil,
        unlockedAt: nil,
        transactionID: nil
    )
}

enum RemoveAdsPurchaseOutcome: Equatable {
    case purchased
    case cancelled
    case pending
    case unavailable
    case failed(String)
}

@MainActor
final class AdEntitlementStore: ObservableObject {
    static let shared = AdEntitlementStore()

    @Published private(set) var state: AdEntitlementState

    let purchaseProductID: String
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let testerCodeHashes: Set<String>

    var adsRemoved: Bool { state.adsRemoved }
    var unlockSource: AdUnlockSource? { state.unlockSource }

    init(
        userDefaults: UserDefaults = .standard,
        testerCodeHashes: [String] = AdConfig.testerUnlockCodeHashes,
        purchaseProductID: String = AdConfig.removeAdsProductID,
        storageKey: String = "kaleidoscope.ads.entitlement.v1"
    ) {
        self.userDefaults = userDefaults
        self.testerCodeHashes = Set(testerCodeHashes.map(Self.normalizedHash).filter(Self.isValidSHA256Hex))
        self.purchaseProductID = purchaseProductID
        self.storageKey = storageKey
        self.state = Self.loadState(userDefaults: userDefaults, storageKey: storageKey)
    }

    @discardableResult
    func redeemTesterCode(_ code: String) -> Bool {
        let hash = Self.hashTesterCode(code)
        guard !hash.isEmpty, testerCodeHashes.contains(hash) else { return false }

        unlock(source: .testerCode, transactionID: nil)
        return true
    }

    func grantStorePurchase(transactionID: String?) {
        unlock(source: .storePurchase, transactionID: transactionID)
    }

    func loadRemoveAdsProduct() async throws -> Product? {
        try await Product.products(for: [purchaseProductID]).first
    }

    func purchaseRemoveAds() async -> RemoveAdsPurchaseOutcome {
        do {
            guard let product = try await loadRemoveAdsProduct() else { return .unavailable }
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    grantStorePurchase(transactionID: String(transaction.id))
                    await transaction.finish()
                    return .purchased
                case .unverified:
                    return .failed("Purchase could not be verified.")
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Unknown purchase result.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    @discardableResult
    func restoreStorePurchase() async -> Bool {
        do {
            try await AppStore.sync()
        } catch {
            // A sync failure should not erase a valid local entitlement.
        }

        return await refreshPurchasedEntitlement()
    }

    @discardableResult
    func refreshPurchasedEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == purchaseProductID, transaction.revocationDate == nil else { continue }

            grantStorePurchase(transactionID: String(transaction.id))
            return true
        }

        return adsRemoved
    }

    static func hashTesterCode(_ code: String) -> String {
        let normalized = normalizedTesterCode(code)
        guard !normalized.isEmpty else { return "" }

        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func unlock(source: AdUnlockSource, transactionID: String?) {
        state = AdEntitlementState(
            adsRemoved: true,
            unlockSource: source,
            unlockedAt: Date(),
            transactionID: transactionID
        )
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func loadState(userDefaults: UserDefaults, storageKey: String) -> AdEntitlementState {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let state = try? JSONDecoder().decode(AdEntitlementState.self, from: data)
        else {
            return .locked
        }

        return state
    }

    private static func normalizedTesterCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func normalizedHash(_ hash: String) -> String {
        hash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isValidSHA256Hex(_ value: String) -> Bool {
        value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil
    }
}
