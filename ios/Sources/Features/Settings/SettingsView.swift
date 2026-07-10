// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — Prismet section (prismet.xyz link)
import SwiftUI

/// Presented as a sheet from Home's gear button. No-arg init by contract:
/// the Home screen references `SettingsView()`.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    /// Persisted app-wide font choice. Same key the root reads to cascade the font.
    @AppStorage(AppFont.storageKey) private var fontRaw = AppFont.default.rawValue

    /// Persisted reading paper. Same key PrismetDesign reads statically; default mirrors
    /// PrismetDesign.paper's dark fallback so the radio reflects the true paper.
    @AppStorage(PrismetDesign.paperKey) private var paperRaw = PrismetPaper.dark.rawValue

    /// Feel toggles — read app-wide by FeedbackCoordinator; unset = on.
    @AppStorage(FeedbackSettings.soundKey) private var soundEnabled = true
    @AppStorage(FeedbackSettings.hapticsKey) private var hapticsEnabled = true

    init() {}

    private var selectedFont: AppFont { AppFont(stored: fontRaw) }
    private var selectedPaper: PrismetPaper { PrismetPaper(rawValue: paperRaw) ?? .dark }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    appearanceSection
                    soundHapticsSection
                    gameThemesSection
                    prismetSection
                    creditsSection
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(FacetBackdrop(accent: PrismetDesign.gold))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PrismetDesign.ground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PrismetDesign.gold)
                }
            }
        }
        // Reflect the choices live within the sheet too, so the whole sheet retypes
        // and re-papers as the user picks.
        .fontDesign(selectedFont.design)
        .id(paperRaw)
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Appearance", systemImage: "paintpalette.fill")

            // Reading paper — the ground every surface sits on.
            VStack(spacing: 0) {
                ForEach(Array(PrismetPaper.allCases.enumerated()), id: \.element.id) { index, paper in
                    paperRow(paper)
                    if index < PrismetPaper.allCases.count - 1 {
                        ledgerRule
                    }
                }
            }
            .prismetCard()

            preview

            VStack(spacing: 0) {
                ForEach(Array(AppFont.allCases.enumerated()), id: \.element.id) { index, font in
                    fontRow(font)
                    if index < AppFont.allCases.count - 1 {
                        ledgerRule
                    }
                }
            }
            .prismetCard()
        }
    }

    /// A gilt hairline between ledger rows, inset past the leading ornament.
    private var ledgerRule: some View {
        Divider().overlay(PrismetDesign.hairline).padding(.leading, 44)
    }

    // MARK: - Sound & Haptics

    private var soundHapticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Sound & Haptics", systemImage: "speaker.wave.2.fill")
            VStack(spacing: 0) {
                Toggle(isOn: $soundEnabled) {
                    Text("Sound Effects")
                        .font(PrismetDesign.title(17))
                        .foregroundStyle(PrismetDesign.ink)
                }
                .tint(PrismetDesign.gold)
                .padding(.vertical, 8)
                ledgerRule
                Toggle(isOn: $hapticsEnabled) {
                    Text("Haptics")
                        .font(PrismetDesign.title(17))
                        .foregroundStyle(PrismetDesign.ink)
                }
                .tint(PrismetDesign.gold)
                .padding(.vertical, 8)
            }
            .prismetCard()
        }
        // Flipping sound on gives an immediate audible confirmation.
        .onChange(of: soundEnabled) { _, isOn in
            if isOn { FeedbackCoordinator.fire(.select) }
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(PrismetDesign.gold)
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(PrismetDesign.ink3)
        }
    }

    /// One reading-paper choice: a true-color swatch of that paper, serif title, radio.
    private func paperRow(_ paper: PrismetPaper) -> some View {
        let swatch = PrismetDesign.palette(for: paper)
        return Button {
            paperRaw = paper.rawValue
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(swatch.ground)
                    Circle().strokeBorder(swatch.outline, lineWidth: 1)
                    Circle().fill(swatch.panel).frame(width: 10, height: 10)
                }
                .frame(width: 24, height: 24)

                Text(paper.rawValue)
                    .font(PrismetDesign.title(17))
                    .foregroundStyle(PrismetDesign.ink)

                Spacer(minLength: 8)

                radio(isOn: paper == selectedPaper)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(paper.rawValue) reading paper")
        .accessibilityAddTraits(paper == selectedPaper ? .isSelected : [])
    }

    /// Live preview of the currently selected font.
    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prismet")
                .font(.system(size: 30, weight: .bold, design: selectedFont.design))
                .foregroundStyle(PrismetDesign.ink)
            Text("The quick brown fox jumps over the lazy dog. 0123456789")
                .font(.system(size: 16, weight: .regular, design: selectedFont.design))
                .foregroundStyle(PrismetDesign.ink2)
            Text(selectedFont.blurb)
                .font(.footnote)
                .foregroundStyle(PrismetDesign.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .prismetCard()
    }

    private func fontRow(_ font: AppFont) -> some View {
        Button {
            fontRaw = font.rawValue
        } label: {
            HStack(spacing: 12) {
                Image(systemName: font.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PrismetDesign.gold)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(font.displayName)
                        .font(.system(size: 17, weight: .semibold, design: font.design))
                        .foregroundStyle(PrismetDesign.ink)
                    Text(font.blurb)
                        .font(.caption)
                        .foregroundStyle(PrismetDesign.ink3)
                }

                Spacer(minLength: 8)

                radio(isOn: font == selectedFont)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(font.displayName) font")
        .accessibilityAddTraits(font == selectedFont ? .isSelected : [])
    }

    @ViewBuilder
    private func radio(isOn: Bool) -> some View {
        if isOn {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PrismetDesign.gold)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(PrismetDesign.ink3)
        }
    }

    // MARK: - Game themes

    /// Signpost only — each game keeps its skins behind its own in-world affordance.
    private var gameThemesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Game Themes", systemImage: "paintbrush.pointed.fill")

            HStack(spacing: 12) {
                Image(systemName: "paintbrush.pointed")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PrismetDesign.gold)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inside each game")
                        .font(PrismetDesign.title(17))
                        .foregroundStyle(PrismetDesign.ink)
                    Text("Boards, felts, and card backs have their own looks — find the paintbrush or gear inside a game to restyle it.")
                        .font(.caption)
                        .foregroundStyle(PrismetDesign.ink3)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .prismetCard()
        }
    }

    // MARK: - Prismet

    /// Link out to the prismet.xyz web tools (Steam Rewind explorer + Debt Clock).
    private var prismetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Prismet", systemImage: "globe")

            Link(destination: URL(string: "https://prismet.xyz")!) {
                HStack(spacing: 12) {
                    Image(systemName: "safari")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PrismetDesign.gold)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("prismet.xyz")
                            .font(PrismetDesign.title(17))
                            .foregroundStyle(PrismetDesign.ink)
                        Text("Steam Rewind and the Debt Clock, on the web.")
                            .font(.caption)
                            .foregroundStyle(PrismetDesign.ink3)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PrismetDesign.ink3)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .prismetCard()
            .accessibilityLabel("Open prismet.xyz in your browser")
        }
    }

    // MARK: - Credits

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Credits", systemImage: "sparkles")

            VStack(alignment: .leading, spacing: 8) {
                Text("Game Tiles")
                    .font(PrismetDesign.title(17))
                    .foregroundStyle(PrismetDesign.ink)
                Text("Every game tile is original Prismet artwork.")
                    .font(.footnote)
                    .foregroundStyle(PrismetDesign.ink2)

                Text("Sound")
                    .font(PrismetDesign.title(17))
                    .foregroundStyle(PrismetDesign.ink)
                    .padding(.top, 4)
                Text("Piece & tile sounds by Kenney (kenney.nl) and artisticdude — all CC0 / public domain. Other sounds are synthesized in-app.")
                    .font(.footnote)
                    .foregroundStyle(PrismetDesign.ink2)

                Text("Chess Set")
                    .font(PrismetDesign.title(17))
                    .foregroundStyle(PrismetDesign.ink)
                    .padding(.top, 4)
                Text("2D chess pieces are the “Cburnett” set by Colin M.L. Burnett, used under CC BY-SA 3.0.")
                    .font(.footnote)
                    .foregroundStyle(PrismetDesign.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .prismetCard()
        }
    }
}

#if DEBUG
#Preview {
    SettingsView()
}
#endif
