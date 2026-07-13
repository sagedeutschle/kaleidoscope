import SwiftUI
import GoogleMobileAds

@main
struct PrismetApp: App {
    /// App-wide font choice; cascades to the whole app via `.fontDesign` on the root.
    @AppStorage(AppFont.storageKey) private var fontRaw = AppFont.default.rawValue

    init() {
        PhoneFieldDeckBridge.shared.activate()
        if AdConfig.isLiveAdsConfigured {
            GADMobileAds.sharedInstance().start(completionHandler: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .fontDesign(AppFont(stored: fontRaw).design)
        }
    }
}
