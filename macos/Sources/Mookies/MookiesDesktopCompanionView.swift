import SwiftUI

struct MookiesDesktopCompanionView: View {
    let character: MookiesMacCharacter
    let title: String
    let message: String
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @State private var isPresented = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            MookiesMacMascotView(
                character: character,
                width: 108,
                showsNameplate: false
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(MookiesMacBrand.warmWhite)
                Text(message)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(MookiesMacBrand.warmWhite.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button("Dismiss companion", systemImage: "xmark.circle.fill", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.title2)
                .foregroundStyle(MookiesMacBrand.warmWhite.opacity(0.82))
                .frame(
                    minWidth: MookiesMacBrand.minimumTarget,
                    minHeight: MookiesMacBrand.minimumTarget
                )
                .keyboardShortcut(.cancelAction)
                .help("Dismiss companion")
                .accessibilityLabel("Dismiss \(character.displayName)")
        }
        .padding(16)
        .frame(maxWidth: 520)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(MookiesMacBrand.arcadeBackground.opacity(0.82))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    differentiateWithoutColor
                        ? MookiesMacBrand.warmWhite
                        : character.accent.opacity(0.92),
                    lineWidth: differentiateWithoutColor ? 3 : 1.5
                )
        }
        .shadow(color: .black.opacity(0.34), radius: 22, y: 10)
        .scaleEffect(accessibilityReduceMotion ? 1 : (isPresented ? 1 : 0.96))
        .opacity(isPresented ? 1 : 0)
        .animation(
            accessibilityReduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78),
            value: isPresented
        )
        .onAppear { isPresented = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(character.displayName) companion. \(title). \(message)")
    }
}
