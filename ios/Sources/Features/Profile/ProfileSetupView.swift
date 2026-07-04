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

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Set up your profile").font(Kaleido.title(30)).foregroundStyle(Kaleido.ink)
                Text(emoji).font(.system(size: 72))
                    .frame(width: 110, height: 110)
                    .background(Circle().fill(Color(hex: colorHex).opacity(0.2)))
                    .overlay(Circle().strokeBorder(Color(hex: colorHex), lineWidth: 3))

                TextField("Display name", text: $name)
                    .textFieldStyle(.roundedBorder).font(.title3).frame(maxWidth: 320)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 46))], spacing: 10) {
                    ForEach(emojis, id: \.self) { e in
                        Text(e).font(.title).padding(6)
                            .background(Circle().fill(emoji == e ? Kaleido.gold.opacity(0.25) : .clear))
                            .onTapGesture { emoji = e }
                    }
                }
                .frame(maxWidth: 320)

                HStack(spacing: 12) {
                    ForEach(colorChoices, id: \.self) { c in
                        Circle().fill(Color(hex: c)).frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(Color.white, lineWidth: colorHex == c ? 3 : 0))
                            .onTapGesture { colorHex = c }
                    }
                }

                Button { Task { await save() } } label: {
                    HStack { if saving { ProgressView() }; Text("Start playing") }.frame(maxWidth: 320)
                }
                .buttonStyle(AccentButtonStyle(accent: Kaleido.gold))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || saving)

                if let err = profiles.lastError {
                    Text(err).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FacetBackdrop(accent: Kaleido.gold, multiHue: true))
    }

    private func save() async {
        saving = true
        let profile = Profile(id: userID, phone: nil,
                              displayName: name.trimmingCharacters(in: .whitespaces),
                              avatarEmoji: emoji, avatarColor: colorHex)
        _ = await profiles.upsert(profile)
        saving = false
    }
}
