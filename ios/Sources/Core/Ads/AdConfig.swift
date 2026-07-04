import Foundation

/// Central AdMob configuration.
///
/// Uses Google's official TEST ad ids until the real AdMob app + banner unit are
/// created. To go live, set `KaleidoscopeAdMobBannerUnitID` to your
/// `ca-app-pub-.../...` banner id and swap the `GADApplicationIdentifier` in
/// `project.yml` (Info.plist) for your real `ca-app-pub-...~...` app id.
enum AdConfig {
    /// Google's official sample AdMob app id (iOS) — test ads only.
    static let testAppID = "ca-app-pub-3940256099942544~1458002511"

    /// Google's official sample BANNER ad unit (iOS) — always serves test ads.
    static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"

    /// StoreKit non-consumable product id for the $4.99 remove-ads purchase.
    static let defaultRemoveAdsProductID = "com.spocksclub.kaleidoscope.removeads"

    struct LiveReadiness: Equatable {
        let isReady: Bool
        let blockers: [String]
    }

    private static var configuredAppID: String? {
        Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
    }

    /// Optional real banner unit id from Info.plist. Missing/blank/malformed = test ads.
    private static var configuredBannerUnitID: String? {
        Bundle.main.object(forInfoDictionaryKey: "KaleidoscopeAdMobBannerUnitID") as? String
    }

    private static var configuredRemoveAdsProductID: String? {
        Bundle.main.object(forInfoDictionaryKey: "KaleidoscopeRemoveAdsProductID") as? String
    }

    private static var configuredTesterCodeHashes: Any? {
        Bundle.main.object(forInfoDictionaryKey: "KaleidoscopeAdUnlockCodeHashes")
    }

    static var bannerUnitID: String { resolvedBannerUnitID(configuredBannerUnitID) }

    static var removeAdsProductID: String {
        let configured = normalizedID(configuredRemoveAdsProductID)
        return configured.isEmpty ? defaultRemoveAdsProductID : configured
    }

    static var testerUnlockCodeHashes: [String] {
        resolvedTesterCodeHashes(configuredTesterCodeHashes)
    }

    /// True while we're still serving Google's test ads (useful for a tiny dev label).
    static var isTestAds: Bool { bannerUnitID == testBannerUnitID }

    static var currentLiveReadiness: LiveReadiness {
        liveReadiness(appID: configuredAppID, bannerUnitID: configuredBannerUnitID)
    }

    static var isLiveAdsConfigured: Bool { currentLiveReadiness.isReady }

    static var shouldDisplayBanner: Bool {
        shouldDisplayBanner(adsRemoved: false, liveReadiness: currentLiveReadiness)
    }

    static func shouldDisplayBanner(adsRemoved: Bool, liveReadiness: LiveReadiness) -> Bool {
        !adsRemoved && liveReadiness.isReady
    }

    static func liveReadiness(appID: String?, bannerUnitID: String?) -> LiveReadiness {
        var blockers: [String] = []

        let appID = normalizedID(appID)
        if appID.isEmpty {
            blockers.append("AdMob app id is missing")
        } else if appID == testAppID {
            blockers.append("AdMob app id is still Google's sample/test id")
        } else if !isValidAppID(appID) {
            blockers.append("AdMob app id is malformed")
        }

        let bannerUnitID = normalizedID(bannerUnitID)
        if bannerUnitID.isEmpty {
            blockers.append("AdMob banner unit id is missing")
        } else if bannerUnitID == testBannerUnitID {
            blockers.append("AdMob banner unit id is still Google's sample/test id")
        } else if !isValidBannerUnitID(bannerUnitID) {
            blockers.append("AdMob banner unit id is malformed")
        }

        return LiveReadiness(isReady: blockers.isEmpty, blockers: blockers)
    }

    static func resolvedBannerUnitID(_ configuredID: String?) -> String {
        let trimmed = normalizedID(configuredID)

        if isValidBannerUnitID(trimmed) {
            return trimmed
        }

        return testBannerUnitID
    }

    static func resolvedTesterCodeHashes(_ rawValue: Any?) -> [String] {
        let values: [String]
        if let array = rawValue as? [String] {
            values = array
        } else if let string = rawValue as? String {
            values = string.components(separatedBy: CharacterSet(charactersIn: ",\n"))
        } else {
            values = []
        }

        return values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter(isValidSHA256Hex)
    }

    private static func normalizedID(_ id: String?) -> String {
        id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func isValidAppID(_ id: String) -> Bool {
        id.range(of: #"^ca-app-pub-\d{16}~\d{10}$"#, options: .regularExpression) != nil
    }

    private static func isValidBannerUnitID(_ id: String) -> Bool {
        id.range(of: #"^ca-app-pub-\d{16}/\d{10}$"#, options: .regularExpression) != nil
    }

    private static func isValidSHA256Hex(_ value: String) -> Bool {
        value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil
    }
}
