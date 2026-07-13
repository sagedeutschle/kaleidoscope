import SwiftUI

private enum FieldDeckRoute: Hashable {
    case games
    case link
    case pocket2048
    case lightsOut
    case catanHarvest
}

struct FieldDeckRootView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            TodayView()
                .navigationDestination(for: FieldDeckRoute.self) { route in
                    switch route {
                    case .games: GamesHubView()
                    case .link: PhoneLinkView()
                    case .pocket2048: Pocket2048View()
                    case .lightsOut: PocketLightsOutView()
                    case .catanHarvest: CatanHarvestView()
                    }
                }
        }
        .onOpenURL(perform: open)
        .onAppear(perform: openLaunchRoute)
    }

    private func open(_ url: URL) {
        guard url.scheme == "fielddeck" else { return }
        openRoute(url.host)
    }

    private func openLaunchRoute() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: "-FieldDeckRoute"),
              arguments.indices.contains(keyIndex + 1)
        else { return }
        openRoute(arguments[keyIndex + 1])
    }

    private func openRoute(_ route: String?) {
        path = NavigationPath()
        switch route {
        case "games": path.append(FieldDeckRoute.games)
        case "link": path.append(FieldDeckRoute.link)
        case "2048": path.append(FieldDeckRoute.pocket2048)
        case "lights": path.append(FieldDeckRoute.lightsOut)
        case "harvest": path.append(FieldDeckRoute.catanHarvest)
        default: break
        }
    }
}
