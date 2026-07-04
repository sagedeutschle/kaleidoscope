import SwiftUI

enum RootLaunchPolicy {
    static func screenshotScreen(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        guard let shot = environment["KALEIDO_SHOT"], !shot.isEmpty else { return nil }
        return shot
    }

    static func shouldRestoreAuth(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        screenshotScreen(environment: environment) == nil
    }
}

/// Launch gate: setup screen -> loading -> home.
struct RootView: View {
    @StateObject private var auth = AuthManager()
    @StateObject private var profiles = ProfileStore()

    var body: some View {
        Group {
#if DEBUG
            // Screenshot harness: drop straight into one screen when launched with
            // KALEIDO_SHOT=<name>. Inert (and compiled out) for normal/Release runs.
            if let shot = RootLaunchPolicy.screenshotScreen() {
                ShotHarness(screen: shot)
            } else {
                gate
            }
#else
            gate
#endif
        }
        .task {
            guard RootLaunchPolicy.shouldRestoreAuth() else { return }
            await auth.restore()
        }
    }

    @ViewBuilder private var gate: some View {
        if !Backend.isConfigured {
            SetupNeededView()
        } else {
            switch auth.state {
            case .loading:
                splash
            case .signedIn(let uid):
                // Game Center identity — straight into Home, no login/setup wall.
                HomeView(auth: auth, profiles: profiles)
                    .task(id: uid) {
                        await profiles.bootstrap(userID: uid,
                                                 fallbackName: auth.displayName ?? "Player",
                                                 cloud: auth.isCloudBacked)
                    }
            }
        }
    }

    private var splash: some View {
        ProgressView().controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FacetBackdrop(accent: Kaleido.gold))
    }
}

/// Shown until Supabase keys are filled into Secrets.swift.
struct SetupNeededView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2.fill").font(.system(size: 44)).foregroundStyle(Kaleido.gold)
            Text("Almost there").font(Kaleido.title(28)).foregroundStyle(Kaleido.ink)
            Text("Add your Supabase URL and anon key to Sources/Backend/Secrets.swift, then rebuild. Full steps are in docs/SETUP.md.")
                .font(.callout).multilineTextAlignment(.center).foregroundStyle(Kaleido.ink2)
                .frame(maxWidth: 340)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FacetBackdrop(accent: Kaleido.gold))
    }
}
