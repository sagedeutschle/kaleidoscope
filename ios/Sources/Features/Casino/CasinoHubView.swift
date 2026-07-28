import PrismetShared
import SwiftUI

/// The threshold wrapper deliberately owns no table/session state. The complete
/// experience host is constructed only after the in-memory adult self-attestation.
public struct CasinoHubView: View {
    @State private var entryAccessStatus: CasinoEntryAccessStatus
    @Environment(\.dismiss) private var dismiss
    private let entryAccessPolicy: CasinoEntryAccessPolicy
    private let previewSeed: UInt64?

    public init(previewSeed: UInt64? = nil, entryAccessPolicy: CasinoEntryAccessPolicy = .practiceOnly) {
        self.previewSeed = previewSeed
        self.entryAccessPolicy = entryAccessPolicy
        _entryAccessStatus = State(initialValue: entryAccessPolicy.initialStatus)
    }

    public var body: some View {
        Group {
            if entryAccessStatus.canEnterCasino {
                CasinoExperienceHost(previewSeed: previewSeed, leaveCasino: leaveCasino)
            } else {
                CasinoEntryGateView(onEnterPractice: { entryAccessStatus = entryAccessPolicy.enterPracticeSession() }, onLeave: { dismiss() })
            }
        }
    }

    private func leaveCasino() {
        // Revoke first so StateObjects hosted below are released before navigation dismisses.
        entryAccessStatus = .threshold
        DispatchQueue.main.async { dismiss() }
    }
}

private struct CasinoExperienceHost: View {
    @StateObject private var session: PracticeBlackjackSession
    @StateObject private var casinoSession: PracticeCasinoSession
    @State private var showingResetConfirmation = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let leaveCasino: () -> Void

    init(previewSeed: UInt64?, leaveCasino: @escaping () -> Void) {
        _session = StateObject(wrappedValue: PracticeBlackjackSession(previewSeed: previewSeed))
        _casinoSession = StateObject(wrappedValue: PracticeCasinoSession(previewSeed: previewSeed))
        self.leaveCasino = leaveCasino
    }

    var body: some View {
        VStack(spacing: 0) {
            hubHeader
            Divider()
            GeometryReader { proxy in
                let layout = CasinoMobileLayoutPolicy.layout(isCompactWidth: horizontalSizeClass == .compact, usableWidth: proxy.size.width)
                switch layout {
                case .compact:
                    VStack(spacing: 12) { compactGamePicker; compactTableRegion }.padding(.horizontal, 12).padding(.top, 12)
                case .regular(let sidebarWidth): regularHubLayout(sidebarWidth: sidebarWidth)
                }
            }
        }
        .background(CasinoTheme.feltBackground.ignoresSafeArea())
        .alert("Reset Session", isPresented: $showingResetConfirmation) {
            Button("Reset Session", role: .destructive) { casinoSession.resetSession() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Clear chance-table, Five-Card Draw, and Study Lab visit state while preserving the Blackjack audit save?")
        }
        .task {
            await session.restoreOrDeal()
            if casinoSession.selectedGameID != .blackjack, session.loadState == .ready { session.endHand() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            Task { await session.persist() }
        }
    }

    private var hubHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Casino").font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(CasinoTheme.headerPrimary)
                Spacer(minLength: 12)
                Button(action: leaveCasino) { Label("Leave Game", systemImage: "door.left.hand.open").frame(minHeight: CasinoTheme.minimumTarget) }
                    .buttonStyle(.bordered).tint(CasinoTheme.headerPrimary)
            }
            Text("18+ practice only · no money or transferable value.").font(.subheadline.weight(.semibold)).foregroundStyle(CasinoTheme.headerPrimary)
            Text("Calm practice tables with open rules").font(.subheadline).foregroundStyle(CasinoTheme.headerSecondary)
            Text(CasinoFairPlayCopy.disclosure).font(.footnote.weight(.semibold)).foregroundStyle(CasinoTheme.headerPrimary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background { ZStack(alignment: .trailing) { CasinoTheme.feltBackground; CasinoProbabilityRosette(style: .watermark, diameter: 126).offset(x: 22).accessibilityHidden(true) } }.clipped()
    }

    private var casinoLibrary: some View {
        VStack(alignment: .leading, spacing: 8) { Text("Tables").font(.headline).foregroundStyle(.primary); ForEach(PrismetPracticeCasinoCatalog.all) { game in gameChoice(game) } }.casinoPanel()
    }

    private var compactGamePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tables").font(.headline)
            ScrollView(.horizontal, showsIndicators: true) { HStack(spacing: 8) { ForEach(PrismetPracticeCasinoCatalog.all) { game in gameChoice(game).frame(width: 172) } } }
        }.casinoPanel()
    }

    @ViewBuilder private var tableSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            tableHeader
            switch casinoSession.descriptor.kind {
            case .blackjack: PracticeBlackjackView(session: session)
            case .poker: PracticePokerView(session: casinoSession)
            case .fairChance: PracticeChanceGameView(session: casinoSession)
            case .studyLab: PracticeStudyLabView(session: casinoSession)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: casinoSession.descriptor.kind == .blackjack ? .infinity : nil, alignment: .top)
    }

    private var tableHeader: some View {
        VStack(alignment: .leading, spacing: 4) { Text(casinoSession.descriptor.title).font(.title2.bold()).foregroundStyle(.primary); Text(casinoSession.descriptor.subtitle).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading).casinoPanel()
    }

    @ViewBuilder private var compactTableRegion: some View {
        if casinoSession.descriptor.kind == .blackjack { tableSurface }
        else { ScrollView { VStack(spacing: 12) { tableSurface; rulesInspector }.padding(.bottom, 24) } }
    }

    private func regularHubLayout(sidebarWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: CasinoMobileLayoutPolicy.hubSpacing) {
            ScrollView { casinoLibrary }.frame(width: CasinoMobileLayoutPolicy.libraryWidth)
            regularTableRegion.frame(maxWidth: .infinity, maxHeight: .infinity)
            ScrollView { rulesInspector }.frame(width: sidebarWidth)
        }.padding(CasinoMobileLayoutPolicy.hubPadding)
    }

    @ViewBuilder private var regularTableRegion: some View {
        if casinoSession.descriptor.kind == .blackjack { tableSurface }
        else { ScrollView { ZStack { RoundedRectangle(cornerRadius: 24, style: .continuous).fill(CasinoTheme.feltBackground); CasinoProbabilityRosette(style: .watermark, diameter: 286).opacity(0.72).accessibilityHidden(true); tableSurface.padding(12) }.frame(minHeight: CasinoMobileLayoutPolicy.regularTableMinimumHeight) } }
    }

    private var rulesInspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rules & Fairness").font(.headline).foregroundStyle(.primary)
            Text(casinoSession.descriptor.rules).foregroundStyle(.secondary)
            Text(casinoSession.descriptor.fairness).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            Button("Reset Session") { showingResetConfirmation = true }.buttonStyle(CasinoActionButtonStyle())
            Text("Reset clears chance-table, Five-Card Draw, and Study Lab visit state while preserving the Blackjack audit save.").font(.footnote).foregroundStyle(.secondary)
        }.casinoPanel()
    }

    private func gameChoice(_ game: PrismetPracticeCasinoGameDescriptor) -> some View {
        let selected = casinoSession.selectedGameID == game.id
        return Button { selectGame(game.id) } label: {
            HStack(spacing: 8) { Image(systemName: game.symbol).frame(width: 20); Text(game.title).font(.subheadline.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.86).multilineTextAlignment(.leading); Spacer(minLength: 2); if selected { Image(systemName: "checkmark.circle.fill").accessibilityHidden(true) } }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(CasinoActionButtonStyle(prominent: selected)).accessibilityValue(selected ? "Selected" : "").disabled(isBlackjackSwitchBlocked && game.id != .blackjack)
    }

    private func selectGame(_ gameID: PrismetPracticeCasinoGameID) {
        guard gameID != casinoSession.selectedGameID else { return }
        if casinoSession.selectedGameID == .blackjack { session.endHand() }
        casinoSession.select(gameID)
    }

    private var isBlackjackSwitchBlocked: Bool { session.loadState != .ready }
}
