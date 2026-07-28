import SwiftUI

/// This threshold intentionally records nothing; the hub owns the resulting
/// access state only while this visit's view hierarchy is alive.
protocol CasinoEntryAccessPolicy {
    var initialStatus: CasinoEntryAccessStatus { get }
    func enterPracticeCasino() -> CasinoEntryAccessStatus
}

enum CasinoEntryAccessStatus: Equatable {
    case threshold
    case sessionAccess
}

struct PlannedCasinoEntryAccessPolicy: CasinoEntryAccessPolicy {
    let initialStatus: CasinoEntryAccessStatus = .threshold

    func enterPracticeCasino() -> CasinoEntryAccessStatus {
        .sessionAccess
    }
}

struct CasinoEntryGateView: View {
    let onEnter: () -> Void
    let onNotNow: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            CasinoTheme.feltBackground
                .ignoresSafeArea()

            CasinoProbabilityRosette(style: .watermark, diameter: 560)
                .opacity(reduceMotion ? 0.2 : 0.28)
                .offset(x: 270, y: -180)
                .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: 24) {
                    CasinoProbabilityRosette(style: .wheel, diameter: 184)
                        .accessibilityLabel("Twelve equal probability segments mark the practice-casino threshold")

                    VStack(spacing: 10) {
                        Text("Casino Practice")
                            .font(.system(size: 38, weight: .bold, design: .serif))
                        Text("Adults 18+ only")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(CasinoTheme.brassSoft)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label(
                            "Practice only. No money, purchases, wagering, prizes, rewards, or transferable value.",
                            systemImage: "checkmark.shield"
                        )
                        Label(
                            "This screen does not verify age.",
                            systemImage: "person.badge.questionmark"
                        )
                        Label(
                            "Choosing \"I'm 18 or older — Enter\" opens Casino Practice for this visit; the access decision is not stored.",
                            systemImage: "eye.slash"
                        )
                    }
                    .font(.body.weight(.medium))
                    .frame(maxWidth: 460, alignment: .leading)
                    .padding(18)
                    .background(CasinoTheme.panel, in: RoundedRectangle(cornerRadius: CasinoTheme.cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: CasinoTheme.cornerRadius)
                            .stroke(CasinoTheme.panelBorder, lineWidth: 1)
                    }
                    .accessibilityElement(children: .combine)

                    HStack(spacing: 12) {
                        Button("Not Now", action: onNotNow)
                            .buttonStyle(.bordered)
                            .frame(minWidth: 132, minHeight: CasinoTheme.minimumTarget)
                            .accessibilityHint("Leaves the practice casino")

                        Button("I'm 18 or older — Enter", action: onEnter)
                            .buttonStyle(.borderedProminent)
                            .tint(CasinoTheme.brass)
                            .foregroundStyle(CasinoTheme.ink)
                            .keyboardShortcut(.defaultAction)
                            .frame(minWidth: 204, minHeight: CasinoTheme.minimumTarget)
                            .accessibilityHint("Opens Casino Practice for this visit only; this screen does not verify age")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .contain)

                    Text("Return enters for this visit. Escape chooses Not Now.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            }
        }
        .onExitCommand(perform: onNotNow)
        .accessibilityElement(children: .contain)
    }
}
