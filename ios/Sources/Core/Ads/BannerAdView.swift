import SwiftUI
import UIKit
import GoogleMobileAds

/// A single standard banner (320×50) wrapping AdMob's `GADBannerView` for SwiftUI.
struct BannerAdView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.rootViewController = Self.rootViewController()
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
    }
}

/// Bottom bar that reserves the banner's height so layout stays stable before the
/// ad fills. Drop this into a `safeAreaInset(edge: .bottom)`.
struct BannerAdBar: View {
    @ObservedObject private var entitlement: AdEntitlementStore

    init(entitlement: AdEntitlementStore = .shared) {
        self.entitlement = entitlement
    }

    var body: some View {
        if !entitlement.adsRemoved {
            BannerAdView()
                .frame(width: 320, height: 50)
                .frame(maxWidth: .infinity)
                .background(PrismetDesign.panel.opacity(0.0))
        }
    }
}
