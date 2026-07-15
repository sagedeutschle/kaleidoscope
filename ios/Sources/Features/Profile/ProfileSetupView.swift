import SwiftUI

/// First-run profile setup: display name + emoji/color avatar.
struct ProfileSetupView: View {
    let userID: UUID
    @ObservedObject var profiles: ProfileStore

    @State private var name = ""
    @State private var emoji = "🎴"
    @State private var colorHex = "B88A2E"
    @State private var saving = false

    private let emojis = ["🎴", "🦊", "🐉", "🌙", "⚡️", "🎲", "🔮", "🦉", "🌸", "🛡️", "👾", "🎯"]
    private let colorChoices = ["B88A2E", "B0494C", "4C8C6B", "3C76A8", "75569E", "C76B3A"]
    private let colorChoiceColumns = [
        GridItem(.adaptive(minimum: 44, maximum: 44), spacing: 10),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Set up your profile").font(PrismetDesign.title(30)).foregroundStyle(PrismetDesign.ink)
                Text(emoji).font(.system(size: 72))
                    .frame(width: 110, height: 110)
                    .background(Circle().fill(Color(hex: colorHex).opacity(0.2)))
                    .overlay(Circle().strokeBorder(Color(hex: colorHex), lineWidth: 3))

                TextField("Display name", text: $name)
                    .textFieldStyle(.roundedBorder).font(.title3).frame(maxWidth: 320)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 46))], spacing: 10) {
                    ForEach(emojis, id: \.self) { e in
                        Button { emoji = e } label: {
                            Text(e).font(.title)
                                .frame(minWidth: 44, minHeight: 44)
                                .background(Circle().fill(emoji == e ? PrismetDesign.gold.opacity(0.25) : .clear))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(emojiName(for: e)) avatar")
                        .accessibilityValue(emoji == e ? "Selected" : "Not selected")
                        .accessibilityAddTraits(emoji == e ? .isSelected : [])
                    }
                }
                .frame(maxWidth: 320)

                LazyVGrid(columns: colorChoiceColumns, spacing: 10) {
                    ForEach(colorChoices, id: \.self) { c in
                        Button { colorHex = c } label: {
                            Circle().fill(Color(hex: c))
                                .frame(width: 44, height: 44)
                                .overlay(Circle().strokeBorder(Color.white, lineWidth: colorHex == c ? 3 : 0))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(colorName(for: c))
                        .accessibilityValue(colorHex == c ? "Selected" : "Not selected")
                        .accessibilityAddTraits(colorHex == c ? .isSelected : [])
                    }
                }
                .frame(maxWidth: 320)

                Button { Task { await save() } } label: {
                    HStack { if saving { ProgressView() }; Text("Start playing") }.frame(maxWidth: 320)
                }
                .buttonStyle(AccentButtonStyle(accent: PrismetDesign.gold))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || saving)

                if let err = profiles.lastError {
                    Text(err).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FacetBackdrop(accent: PrismetDesign.gold, multiHue: true))
    }

    private func save() async {
        saving = true
        let profile = Profile(id: userID, phone: nil,
                              displayName: name.trimmingCharacters(in: .whitespaces),
                              avatarEmoji: emoji, avatarColor: colorHex)
        _ = await profiles.upsert(profile)
        saving = false
    }

    private func emojiName(for value: String) -> String {
        switch value {
        case "🎴": return "Card"
        case "🦊": return "Fox"
        case "🐉": return "Dragon"
        case "🌙": return "Moon"
        case "⚡️": return "Lightning"
        case "🎲": return "Dice"
        case "🔮": return "Crystal ball"
        case "🦉": return "Owl"
        case "🌸": return "Blossom"
        case "🛡️": return "Shield"
        case "👾": return "Alien"
        case "🎯": return "Target"
        default: return "Custom"
        }
    }

    private func colorName(for value: String) -> String {
        switch value {
        case "B88A2E": return "Gold"
        case "B0494C": return "Ruby red"
        case "4C8C6B": return "Emerald green"
        case "3C76A8": return "Sapphire blue"
        case "75569E": return "Amethyst purple"
        case "C76B3A": return "Copper orange"
        default: return "Color"
        }
    }
}
