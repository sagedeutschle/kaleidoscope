import PrismetShared
import SwiftUI

struct CasinoHubView: View {
    @State private var entryStatus: CasinoEntryAccessStatus
    @Environment(\.dismiss) private var dismiss

    private let suppliedLeaveAction: (() -> Void)?
    private let entryAccessPolicy: any CasinoEntryAccessPolicy
    private let previewSeed: UInt64?
    private let previewBlackjackSession: PracticeBlackjackSession?

    init(
        previewSeed: UInt64? = nil,
        onLeave: (() -> Void)? = nil,
        entryAccessPolicy: any CasinoEntryAccessPolicy = PlannedCasinoEntryAccessPolicy()
    ) {
        self.previewSeed = previewSeed
        previewBlackjackSession = nil
        suppliedLeaveAction = onLeave
        self.entryAccessPolicy = entryAccessPolicy
        _entryStatus = State(initialValue: entryAccessPolicy.initialStatus)
    }

    init(
        session: PracticeBlackjackSession,
        onLeave: (() -> Void)? = nil,
        entryAccessPolicy: any CasinoEntryAccessPolicy = PlannedCasinoEntryAccessPolicy()
    ) {
        previewSeed = nil
        previewBlackjackSession = session
        suppliedLeaveAction = onLeave
        self.entryAccessPolicy = entryAccessPolicy
        _entryStatus = State(initialValue: entryAccessPolicy.initialStatus)
    }

    var body: some View {
        Group {
            switch entryStatus {
            case .threshold:
                CasinoEntryGateView(onEnter: enterPracticeCasino, onNotNow: leave)
            case .sessionAccess:
                // The experience and its sessions do not exist before entry.
                CasinoExperienceHost(
                    previewSeed: previewSeed,
                    previewBlackjackSession: previewBlackjackSession,
                    onLeave: leave
                )
            }
        }
    }

    private func enterPracticeCasino() {
        entryStatus = entryAccessPolicy.enterPracticeCasino()
    }

    private func leave() {
        // Revoke the in-memory decision before routing away so returning always
        // re-presents the honest threshold.
        entryStatus = .threshold
        if let suppliedLeaveAction { suppliedLeaveAction() } else { dismiss() }
    }
}

/// The complete Casino state tree. This type is intentionally constructed only
/// after the visitor chooses to enter from `CasinoEntryGateView`.
private struct CasinoExperienceHost: View {
    @StateObject private var blackjackSession: PracticeBlackjackSession
    @StateObject private var session: PracticeCasinoSession
    let onLeave: () -> Void

    init(
        previewSeed: UInt64?,
        previewBlackjackSession: PracticeBlackjackSession?,
        onLeave: @escaping () -> Void
    ) {
        _blackjackSession = StateObject(
            wrappedValue: previewBlackjackSession ?? PracticeBlackjackSession(previewSeed: previewSeed)
        )
        _session = StateObject(wrappedValue: PracticeCasinoSession(previewSeed: previewSeed))
        self.onLeave = onLeave
    }

    var body: some View {
        VStack(spacing: 0) {
            hubHeader
            Divider()
            GeometryReader { proxy in
                switch CasinoMacLayoutPolicy.presentation(for: proxy.size.width) {
                case .split:
                    HStack(spacing: 0) {
                        gameSidebar.frame(width: CasinoMacLayoutPolicy.sidebarWidth(for: proxy.size.width))
                        Divider()
                        tableSurface
                    }
                case .stacked:
                    VStack(spacing: 0) {
                        compactGameStrip
                        Divider()
                        tableSurface
                    }
                }
            }
        }
        .background {
            ZStack(alignment: .trailing) {
                CasinoTheme.feltBackground
                CasinoProbabilityRosette(style: .watermark, diameter: 440)
                    .offset(x: 110)
                    .opacity(0.78)
                    .accessibilityHidden(true)
            }
        }
        .task {
            await blackjackSession.restoreOrDeal()
            if session.selectedGameID != .blackjack, blackjackSession.loadState == .ready {
                blackjackSession.endHand()
            }
        }
        .onExitCommand(perform: onLeave)
    }

    private var hubHeader: some View {
        HStack(spacing: 14) {
            Label("Fair Play Casino", systemImage: "checkmark.shield")
                .font(.headline)
            Text("Adults 18+ only · no money, purchases, wagering, prizes, rewards, or transferable value")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Chance, Poker, and Study Lab state is visit-only")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Button("Leave Game", systemImage: "door.left.hand.open", action: onLeave)
                .buttonStyle(.bordered)
                .frame(minHeight: CasinoTheme.minimumTarget)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var tableSurface: some View {
        let descriptor = PrismetPracticeCasinoCatalog[session.selectedGameID]
        switch descriptor.kind {
        case .blackjack:
            PracticeBlackjackView(session: blackjackSession, onLeave: onLeave)
        case .poker:
            PracticePokerView(session: session, descriptor: descriptor, onLeave: onLeave)
        case .fairChance:
            PracticeChanceGameView(
                session: session,
                descriptor: descriptor,
                onLeave: onLeave
            )
        case .studyLab:
            PracticeStudyLabView(session: session, descriptor: descriptor, onLeave: onLeave)
        }
    }

    private var gameSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Casino", systemImage: "suit.spade.fill")
                .font(.system(size: 25, weight: .bold, design: .rounded))
            Text("Probability practice room")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(PrismetPracticeCasinoCatalog.all) { descriptor in
                        gameChoice(descriptor)
                    }
                }
            }
            .scrollIndicators(.automatic)

            Text("Adults 18+ only · no money or transferable value · visit state only")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
    }

    private var compactGameStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(PrismetPracticeCasinoCatalog.all) { descriptor in
                    gameChoice(descriptor)
                        .frame(width: 190)
                }
            }
            .padding(12)
        }
        .scrollIndicators(.automatic)
        .background(.regularMaterial)
    }

    private func gameChoice(_ descriptor: PrismetPracticeCasinoGameDescriptor) -> some View {
        let selected = session.selectedGameID == descriptor.id
        return Button {
            selectGame(descriptor.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: descriptor.symbol)
                    .frame(width: 23)
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(descriptor.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
                if selected { Image(systemName: "checkmark.circle.fill") }
            }
            .padding(10)
            .frame(minHeight: CasinoTheme.minimumTarget, alignment: .leading)
            .background(selected ? CasinoTheme.brassSoft : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? CasinoTheme.brass : Color.primary.opacity(0.1), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(descriptor.title)\(selected ? ", Selected" : "")")
        .disabled(isBlackjackSwitchBlocked && descriptor.id != .blackjack)
    }

    private func selectGame(_ gameID: PrismetPracticeCasinoGameID) {
        guard gameID != session.selectedGameID else { return }
        if session.selectedGameID == .blackjack {
            blackjackSession.endHand()
        }
        session.select(gameID)
    }

    private var isBlackjackSwitchBlocked: Bool {
        blackjackSession.loadState != .ready
    }

}
