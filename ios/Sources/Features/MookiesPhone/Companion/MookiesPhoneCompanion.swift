import Combine
import SwiftUI

/// The compact, non-blocking moods that Mookie can express beside a game or destination.
/// These are presentation-only messages; they never inspect or modify game state.
public enum MookiesPhoneCompanionState: String, CaseIterable, Equatable, Sendable {
    case welcome
    case encouragement
    case celebration

    public var message: String {
        switch self {
        case .welcome:
            return "I’ll keep you company from over here."
        case .encouragement:
            return "Take your time — the next move is yours."
        case .celebration:
            return "Nice one! I’m cheering from the sidelines."
        }
    }

    public var accessibilityLabel: String {
        "Mookie, your arcade host. \(message)"
    }
}

/// Presentation state for `MookiesPhoneCompanion`.
///
/// Commander integration seam: retain this with `@StateObject` in the destination that
/// presents the companion, then place `MookiesPhoneCompanion(model: model)` in that
/// destination's `VStack` or `safeAreaInset`. This object intentionally owns no
/// navigation, game, odds, result, progress, or token state.
@MainActor
public final class MookiesPhoneCompanionModel: ObservableObject {
    @Published public private(set) var isPresented: Bool
    @Published public var state: MookiesPhoneCompanionState

    private var hasReportedDismissal = false
    private let onDismiss: () -> Void

    public init(
        isPresented: Bool = true,
        state: MookiesPhoneCompanionState = .welcome,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.isPresented = isPresented
        self.state = state
        self.onDismiss = onDismiss
    }

    public func present(state: MookiesPhoneCompanionState? = nil) {
        if let state {
            self.state = state
        }
        hasReportedDismissal = false
        isPresented = true
    }

    public func dismiss() {
        guard isPresented else { return }
        isPresented = false
        guard !hasReportedDismissal else { return }
        hasReportedDismissal = true
        onDismiss()
    }
}

/// A compact Mookie host card for narrow phone surfaces.
/// It participates in normal layout instead of overlaying a table or a primary play control.
public struct MookiesPhoneCompanion: View {
    public static let hostAssetName = "MookieHost"
    public static let dismissAccessibilityLabel = "Dismiss Mookie companion"
    public static let integrationSeam = "Place in a destination VStack or safe-area inset with a MookiesPhoneCompanionModel; it owns no navigation, game, odds, result, progress, or token state."

    @ObservedObject private var model: MookiesPhoneCompanionModel
    @ScaledMetric(relativeTo: .body) private var hostDiameter: CGFloat = 64
    private let companionInk = Color(red: 0.08, green: 0.15, blue: 0.13)

    public init(model: MookiesPhoneCompanionModel) {
        self.model = model
    }

    public var body: some View {
        if model.isPresented {
            ViewThatFits(in: .horizontal) {
                companionContent(axis: .horizontal)
                companionContent(axis: .vertical)
            }
            .padding(12)
            .background(companionBackground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("mookies-phone-companion")
        }
    }

    @ViewBuilder
    private func companionContent(axis: Axis) -> some View {
        if axis == .horizontal {
            HStack(alignment: .center, spacing: 12) {
                hostArtwork
                copy
                dismissButton
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    hostArtwork
                    copy
                }
                dismissButton.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var hostArtwork: some View {
        Image(Self.hostAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: hostDiameter, height: hostDiameter)
            .accessibilityHidden(true)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Mookie")
                .font(.headline.weight(.bold))
            Text(model.state.message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(companionInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.state.accessibilityLabel)
    }

    private var dismissButton: some View {
        Button(action: model.dismiss) {
            Label("Dismiss", systemImage: "xmark")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .tint(companionInk)
        .controlSize(.regular)
        .accessibilityLabel(Self.dismissAccessibilityLabel)
        .accessibilityHint("Hides Mookie without changing the game.")
    }

    private var companionBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(red: 0.969, green: 0.957, blue: 0.918))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color(red: 0.486, green: 0.361, blue: 1.0).opacity(0.45), lineWidth: 1)
            }
    }
}
