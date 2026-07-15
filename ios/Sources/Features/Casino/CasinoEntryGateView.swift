import SwiftUI

/// In-memory only; no age verification or access decision is stored.
public enum CasinoEntryAccessStatus: Equatable {
    case threshold, practiceSession
    var canEnterCasino: Bool { self == .practiceSession }
}

public struct CasinoEntryAccessPolicy: Equatable {
    public static let practiceOnly = CasinoEntryAccessPolicy()
    public init() {}
    public var initialStatus: CasinoEntryAccessStatus { .threshold }
    public func enterPracticeSession() -> CasinoEntryAccessStatus { .practiceSession }
}

public struct CasinoEntryGateView: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onEnterPractice: () -> Void
    let onLeave: () -> Void

    public init(onEnterPractice: @escaping () -> Void, onLeave: @escaping () -> Void) {
        self.onEnterPractice = onEnterPractice
        self.onLeave = onLeave
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                CasinoTheme.feltBackground.ignoresSafeArea()
                CasinoProbabilityRosette(style: .wheel, diameter: min(max(proxy.size.width * 0.78, 220), 430))
                    .opacity(reduceMotion ? 0.62 : 0.78).accessibilityHidden(true)
                ScrollView {
                    VStack(spacing: 24) { Spacer(minLength: 24); thresholdCopy; thresholdActions; Spacer(minLength: 16) }
                        .frame(maxWidth: 620).padding(.horizontal, 24).padding(.vertical, 32)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var thresholdCopy: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Probability practice threshold", systemImage: "circle.hexagongrid.fill").font(.headline.weight(.semibold)).foregroundStyle(CasinoTheme.headerPrimary)
            Text("Casino Practice").font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(CasinoTheme.headerPrimary)
            Label("Adults 18+ only", systemImage: "18.circle.fill").font(.title3.weight(.semibold)).foregroundStyle(CasinoTheme.headerPrimary)
            if differentiateWithoutColor { Label("Information: this is a practice-only destination.", systemImage: "info.circle").font(.subheadline.weight(.semibold)).foregroundStyle(CasinoTheme.headerPrimary) }
            Text("Practice only. No money, purchases, wagering, prizes, rewards, or transferable value.").font(.body.weight(.semibold)).foregroundStyle(CasinoTheme.headerPrimary)
            Text("This screen does not verify age.").font(.body).foregroundStyle(CasinoTheme.headerSecondary)
            Text("Choosing Enter opens Casino Practice only for this visit. The access decision is not stored.").font(.footnote).foregroundStyle(CasinoTheme.headerSecondary)
        }
        .padding(24).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(CasinoTheme.accent, lineWidth: 2) }
        .accessibilityElement(children: .combine)
    }

    private var thresholdActions: some View {
        VStack(spacing: 12) {
            Button(action: onEnterPractice) { Label("I'm 18 or older — Enter", systemImage: "arrow.right.circle.fill").frame(maxWidth: .infinity, minHeight: CasinoTheme.minimumTarget) }
                .buttonStyle(CasinoActionButtonStyle(prominent: true)).accessibilityHint("Self-attests that you are 18 or older and opens a practice-only session for this visit.")
            Button(action: onLeave) { Label("Not Now", systemImage: "xmark.circle").frame(maxWidth: .infinity, minHeight: CasinoTheme.minimumTarget) }
                .buttonStyle(.bordered).tint(CasinoTheme.headerPrimary).accessibilityHint("Leaves Casino Practice.")
        }
    }
}
