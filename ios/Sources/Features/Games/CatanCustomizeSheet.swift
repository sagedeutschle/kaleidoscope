import SwiftUI

// PRISM: CLAIM Claude 2026-07-13 — Catan 3D overhaul (research branch). Customization sheet.
//
// The customization surface: board style (3D/2D), board theme, your color, piece style, motion
// options, and new-game settings (player count + bot difficulty). Binds directly to CatanView's
// state, which persists to CatanPrefs and drives the live 3D board.

struct CatanCustomizeSheet: View {
    @Binding var themeID: String
    @Binding var pieceStyle: CatanPieceStyle
    @Binding var playerColorID: String
    @Binding var boardStyle: CatanBoardStyle
    @Binding var autoRotate: Bool
    @Binding var reduceMotion: Bool
    @Binding var difficulty: CatanBotDifficulty
    @Binding var playerCount: Int
    let accent: Color
    let onStartNewGame: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let themeColumns = [GridItem(.adaptive(minimum: 140), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("Board") {
                        Picker("Board Style", selection: $boardStyle) {
                            ForEach(CatanBoardStyle.allCases) { Text($0.name).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    section("Theme") {
                        LazyVGrid(columns: themeColumns, spacing: 10) {
                            ForEach(CatanTheme.all) { themeCard($0) }
                        }
                    }

                    section("Your Color") {
                        HStack(spacing: 12) {
                            ForEach(CatanPlayerColor.choices) { c in colorDot(c) }
                        }
                    }

                    section("Pieces") {
                        Picker("Pieces", selection: $pieceStyle) {
                            ForEach(CatanPieceStyle.allCases) { Text($0.name).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text(pieceStyle.blurb).font(.caption).foregroundStyle(PrismetDesign.ink3)
                    }

                    section("Motion") {
                        Toggle("Gently rotate the board", isOn: $autoRotate)
                        Toggle("Reduce motion", isOn: $reduceMotion)
                    }
                    .tint(accent)

                    section("New Game") {
                        Stepper(value: $playerCount, in: 2...4) {
                            Text("Players: \(playerCount)  (you + \(playerCount - 1) bot\(playerCount - 1 == 1 ? "" : "s"))")
                                .font(.subheadline).foregroundStyle(PrismetDesign.ink)
                        }
                        Picker("Difficulty", selection: $difficulty) {
                            ForEach(CatanBotDifficulty.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text(difficulty.blurb).font(.caption).foregroundStyle(PrismetDesign.ink3)
                        Button {
                            onStartNewGame()
                            dismiss()
                        } label: {
                            Label("Start New Game", systemImage: "sparkles").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AccentButtonStyle(accent: accent))
                        .padding(.top, 2)
                    }
                }
                .padding(18)
            }
            .background(FacetBackdrop(accent: accent, multiHue: true))
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    // MARK: Pieces

    @ViewBuilder private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.caption.weight(.bold)).tracking(1).foregroundStyle(PrismetDesign.ink3)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .prismetCard()
    }

    private func themeCard(_ t: CatanTheme) -> some View {
        let selected = (t.id == themeID)
        let swatches: [CatanRGB] = [t.forest, t.fields, t.hills, t.mountains, t.water]
        return Button { themeID = t.id } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 3) {
                    ForEach(Array(swatches.enumerated()), id: \.offset) { _, c in
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(c.color)
                            .frame(height: 22)
                    }
                }
                Text(t.name).font(.subheadline.weight(.semibold)).foregroundStyle(PrismetDesign.ink)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? accent.opacity(0.16) : PrismetDesign.panelHi))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(selected ? accent : PrismetDesign.outline, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func colorDot(_ c: CatanPlayerColor) -> some View {
        let selected = (c.id == playerColorID)
        return Button { playerColorID = c.id } label: {
            Circle().fill(c.rgb.color)
                .frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(selected ? PrismetDesign.ink : Color.white.opacity(0.7), lineWidth: selected ? 3 : 1.5))
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(c.name)
    }
}
