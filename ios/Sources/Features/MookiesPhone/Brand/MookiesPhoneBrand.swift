import SwiftUI

/// Canonical identity and compact header seam for the phone shell or a future Casino entry point.
public enum MookiesPhoneBrand {
    public static let appFacingName = "Mookie's Arcade"
    public static let studioName = "Prismet"
    public static let studioCredit = "from Prismet"
    public static let hostAssetName = "MookieHost"
    public static let compactHostSize: CGFloat = 56

    public static var compactHeaderAccessibilityLabel: String {
        "\(appFacingName), \(studioCredit)"
    }
}

/// A non-interactive, compact-width identity header that a commander can insert above a destination.
/// Use `MookiesPhoneBrandHeader()` directly at the intended shell seam; it owns no navigation or state.
public struct MookiesPhoneBrandHeader: View {
    private let showsStudioCredit: Bool

    public init(showsStudioCredit: Bool = true) {
        self.showsStudioCredit = showsStudioCredit
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(MookiesPhoneBrand.hostAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: MookiesPhoneBrand.compactHostSize, height: MookiesPhoneBrand.compactHostSize)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.72), lineWidth: 2))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(MookiesPhoneBrand.appFacingName)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if showsStudioCredit {
                    Text(MookiesPhoneBrand.studioCredit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(showsStudioCredit ? MookiesPhoneBrand.compactHeaderAccessibilityLabel : MookiesPhoneBrand.appFacingName)
    }
}
