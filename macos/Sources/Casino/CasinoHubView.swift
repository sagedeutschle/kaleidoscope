import PrismetShared
import SwiftUI

struct CasinoHubView: View {
    @StateObject private var blackjackSession: PracticeBlackjackSession
    @StateObject private var session: PracticeCasinoSession
    @State private var entryStatus: CasinoEntryAccessStatus
    @Environment(\.dismiss) private var dismiss

    private let suppliedLeaveAction: (() -> Void)?
    private let entryAccessPolicy: any CasinoEntryAccessPolicy

    init(
        previewSeed: UInt64? = nil,
        onLeave: (() -> Void)? = nil,
        entryAccessPolicy: any CasinoEntryAccessPolicy = PlannedCasinoEntryAccessPolicy()
    ) {
        _blackjackSession = StateObject(wrappedValue: PracticeBlackjackSession(previewSeed: previewSeed))
        if let previewSeed {
            _session = StateObject(wrappedValue: PracticeCasinoSession(seedSource: { previewSeed }))
        } else {
            _session = StateObject(wrappedValue: PracticeCasinoSession())
        }
        suppliedLeaveAction = onLeave
        self.entryAccessPolicy = entryAccessPolicy
        _entryStatus = State(initialValue: entryAccessPolicy.initialStatus)
    }

    init(
        session: PracticeBlackjackSession,
        onLeave: (() -> Void)? = nil,
        entryAccessPolicy: any CasinoEntryAccessPolicy = PlannedCasinoEntryAccessPolicy()
    ) {
        _blackjackSession = StateObject(wrappedValue: session)
        _session = StateObject(wrappedValue: PracticeCasinoSession())
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
                casinoExperience
            }
        }
    }

    private var casinoExperience: some View {
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
        .onExitCommand(perform: leave)
    }

    private var hubHeader: some View {
        HStack(spacing: 14) {
            Label("Fair Play Casino", systemImage: "checkmark.shield")
                .font(.headline)
            Text("Practice only · no money or transferable value")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Button("Leave Game", systemImage: "door.left.hand.open", action: leave)
                .buttonStyle(.bordered)
                .frame(minHeight: CasinoTheme.minimumTarget)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var tableSurface: some View {
        switch session.selectedGameID {
        case .blackjack:
            PracticeBlackjackView(session: blackjackSession, onLeave: leave)
        case .fiveCardDraw:
            PracticePokerView(session: session, descriptor: PrismetPracticeCasinoCatalog[.fiveCardDraw], onLeave: leave)
        default:
            PracticeChanceGameView(
                session: session,
                descriptor: PrismetPracticeCasinoCatalog[session.selectedGameID],
                onLeave: leave
            )
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

            Text("Practice only · no money or transferable value")
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

    private func enterPracticeCasino() {
        entryStatus = entryAccessPolicy.enterPracticeCasino()
    }

    private func leave() {
        if let suppliedLeaveAction { suppliedLeaveAction() } else { dismiss() }
    }
}
