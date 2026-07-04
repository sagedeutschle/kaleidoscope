import StoreKit
import SwiftUI

struct RemoveAdsView: View {
    static let purchaseUnavailableMessage = "The $4.99 Remove Ads purchase is not available yet. Create the non-consumable product com.spocksclub.kaleidoscope.removeads in App Store Connect, or run a Debug build with Configuration/RemoveAds.storekit selected."

    @ObservedObject var entitlement: AdEntitlementStore
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isPurchasing = false
    @State private var priceLabel = "$4.99"
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if entitlement.adsRemoved {
                        Label("Ads Off", systemImage: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await purchase() }
                        } label: {
                            HStack {
                                Label("Remove Ads", systemImage: "rectangle.slash")
                                Spacer()
                                Text(priceLabel)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(isPurchasing)

                        Button {
                            Task { await restorePurchase() }
                        } label: {
                            Label("Restore Purchase", systemImage: "arrow.clockwise")
                        }
                        .disabled(isPurchasing)
                    }
                }

                Section {
                    TextField("Code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    Button {
                        redeemCode()
                    } label: {
                        Label("Redeem Code", systemImage: "key.fill")
                    }
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || entitlement.adsRemoved)
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Remove Ads")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await entitlement.refreshPurchasedEntitlement()
                await loadPrice()
            }
        }
    }

    private func redeemCode() {
        if entitlement.redeemTesterCode(code) {
            code = ""
            statusMessage = "Ads are off."
        } else {
            statusMessage = "That code did not work."
        }
    }

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        switch await entitlement.purchaseRemoveAds() {
        case .purchased:
            statusMessage = "Ads are off."
        case .cancelled:
            statusMessage = "Purchase cancelled."
        case .pending:
            statusMessage = "Purchase pending."
        case .unavailable:
            statusMessage = Self.purchaseUnavailableMessage
        case .failed(let message):
            statusMessage = message
        }
    }

    private func restorePurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        if await entitlement.restoreStorePurchase() {
            statusMessage = "Ads are off."
        } else {
            statusMessage = "No purchase found."
        }
    }

    private func loadPrice() async {
        guard let product = try? await entitlement.loadRemoveAdsProduct() else { return }
        priceLabel = product.displayPrice
    }
}
