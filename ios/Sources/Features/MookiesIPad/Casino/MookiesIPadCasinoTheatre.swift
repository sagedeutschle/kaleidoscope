import PrismetShared
import SwiftUI

/// A regular-width presentation shell for the existing Casino library, table,
/// and fairness inspector. It owns no navigation, session, odds, or result state.
///
/// Integration seam: use this in `CasinoExperienceHost.regularHubLayout` and pass
/// the existing `casinoLibrary`, `regularTableRegion`, and `rulesInspector` views.
public struct MookiesIPadCasinoTheatre<
    Library: View,
    Table: View,
    Inspector: View
>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var mascotVisibility = MookiesCasinoMascotVisibility()

    private let library: Library
    private let table: Table
    private let inspector: Inspector
    private let mascotPlan: MookiesCasinoMascotPresencePlan

    public init(
        mascotPlan: MookiesCasinoMascotPresencePlan = .casino,
        @ViewBuilder library: () -> Library,
        @ViewBuilder table: () -> Table,
        @ViewBuilder inspector: () -> Inspector
    ) {
        self.mascotPlan = mascotPlan
        self.library = library()
        self.table = table()
        self.inspector = inspector()
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = MookiesIPadCasinoLayoutPolicy.layout(
                width: proxy.size.width,
                height: proxy.size.height,
                isRegularWidth: horizontalSizeClass == .regular,
                usesAccessibilityText: dynamicTypeSize.isAccessibilitySize
            )

            ZStack {
                MookiesIPadCasinoBackdrop(motionMode: MookiesCasinoMotionPolicy.mode(reduceMotion: reduceMotion))
                composition(for: layout)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("mookies-ipad-casino-theatre")
        }
    }

    @ViewBuilder
    private func composition(for layout: MookiesIPadCasinoLayout) -> some View {
        switch layout {
        case .stacked:
            ScrollView {
                VStack(spacing: 16) {
                    hostRail
                    libraryPanel
                    tableStage(minimumHeight: 540)
                    inspectorPanel
                }
                .padding(16)
            }
        case .balanced:
            VStack(spacing: 14) {
                hostRail
                HStack(alignment: .top, spacing: 14) {
                    ScrollView {
                        VStack(spacing: 14) {
                            libraryPanel
                            inspectorPanel
                        }
                    }
                    .frame(width: 270)

                    tableStage(minimumHeight: 560)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(16)
        case .panoramic:
            VStack(spacing: 14) {
                hostRail
                HStack(alignment: .top, spacing: 14) {
                    ScrollView { libraryPanel }
                        .frame(width: 216)

                    tableStage(minimumHeight: 560)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ScrollView { inspectorPanel }
                        .frame(width: 294)
                }
            }
            .padding(16)
        }
    }

    private var hostRail: some View {
        MookiesIPadCasinoHostRail(
            plan: mascotPlan,
            visibility: $mascotVisibility
        )
    }

    private var libraryPanel: some View {
        library
            .padding(12)
            .background(MookiesIPadCasinoPalette.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(MookiesIPadCasinoPalette.brass.opacity(0.62), lineWidth: 1)
            }
    }

    private var inspectorPanel: some View {
        inspector
            .padding(12)
            .background(MookiesIPadCasinoPalette.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(MookiesIPadCasinoPalette.brass.opacity(0.62), lineWidth: 1)
            }
    }

    private func tableStage(minimumHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            MookiesIPadCasinoStageMarquee()
            table
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .environment(\.colorScheme, .dark)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(MookiesIPadCasinoPalette.tableFelt)
                .shadow(color: .black.opacity(0.42), radius: 22, y: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            MookiesIPadCasinoPalette.brassLight,
                            MookiesIPadCasinoPalette.brass,
                            MookiesIPadCasinoPalette.brassDark,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        }
    }
}
