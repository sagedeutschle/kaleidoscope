import SwiftUI

struct MookiesMacMascotView: View {
    let character: MookiesMacCharacter
    var width: CGFloat
    var message: String? = nil
    var showsNameplate = true

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var isFloating = false

    var body: some View {
        VStack(spacing: 8) {
            if let message {
                Text(message)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(MookiesMacBrand.nearBlack)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(MookiesMacBrand.warmWhite, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .bottom) {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.caption)
                            .foregroundStyle(MookiesMacBrand.warmWhite)
                            .offset(y: 8)
                    }
            }

            Image(character.assetName)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: width, height: width)
                .shadow(color: character.accent.opacity(0.36), radius: 18, y: 8)
                .offset(y: accessibilityReduceMotion ? 0 : (isFloating ? -4 : 4))
                .animation(
                    accessibilityReduceMotion
                        ? nil
                        : .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                    value: isFloating
                )

            if showsNameplate {
                VStack(spacing: 1) {
                    Text(character.displayName)
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                    Text(character.role.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(MookiesMacBrand.brassHighlight)
                }
                .foregroundStyle(MookiesMacBrand.warmWhite)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(MookiesMacBrand.nearBlack.opacity(0.82), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(character.accent.opacity(0.9), lineWidth: 1.5)
                }
            }
        }
        .frame(width: width + 28)
        .onAppear {
            isFloating = !accessibilityReduceMotion
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(character.accessibilityLabel)
        .accessibilityValue(message ?? character.role)
    }
}
