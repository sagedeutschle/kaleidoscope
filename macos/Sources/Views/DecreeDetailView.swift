import SwiftUI

/// Tap-through detail for a single decree. The fun, ornate royal proclamation
/// stays the headline ("the official publish"); below it the same prophecy is
/// SIMPLIFIED to plain language, followed by the specifics (how it's judged,
/// when, where it came from, the council's private confidence) and — once the
/// Court Historian has ruled — the reckoning.
struct DecreeDetailView: View {
    let decree: Decree
    @Environment(\.dismiss) private var dismiss

    private let parchment = Color(red: 0.96, green: 0.93, blue: 0.85)
    private let ink = Color(red: 0.20, green: 0.16, blue: 0.12)
    private let gold = Color(red: 0.72, green: 0.56, blue: 0.20)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                tierBadge(decree.tier)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(decree.title)
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)

                    section("👑 The royal decree", "as published") {
                        Text(decree.regal.isEmpty ? decree.claim : decree.regal)
                            .font(.system(.body, design: .serif).italic())
                            .foregroundStyle(ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    section("📋 In plain terms", "the actual prediction") {
                        Text(decree.claim.isEmpty ? "—" : decree.claim)
                            .font(.body)
                            .foregroundStyle(ink.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let criteria = decree.criteria, !criteria.isEmpty {
                        section("⚖️ How it's judged", "the Court Historian's test") {
                            Text(criteria)
                                .font(.callout)
                                .foregroundStyle(ink.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let correction = decree.correction, !correction.isEmpty {
                        section(rulingTitle(decree.tier), "the reckoning") {
                            Text(correction)
                                .font(.callout)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    specifics
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 460, idealWidth: 540, minHeight: 420, idealHeight: 600)
        .background(parchment.opacity(0.5))
    }

    // MARK: - Sections

    private func section<C: View>(_ title: String, _ subtitle: String,
                                  @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title).font(.headline.weight(.bold)).foregroundStyle(ink.opacity(0.85))
                Text(subtitle).font(.caption2).foregroundStyle(ink.opacity(0.5))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var specifics: some View {
        VStack(alignment: .leading, spacing: 10) {
            spec("Resolves", decree.resolves, "calendar")
            spec("Domain",
                 decree.domain.replacingOccurrences(of: "-", with: " ").capitalized, "tag")
            if let s = decree.source, !s.isEmpty {
                spec("Sourced",
                     s == "free-pick" ? "the King web-searched it himself" : "laid before the court",
                     "magnifyingglass")
            }
            spec("Private confidence",
                 String(format: "%.0f%% — the council's true odds; the public decree is absolute regardless",
                        decree.confidence * 100),
                 "lock")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.5)))
    }

    private func spec(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(gold).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(ink.opacity(0.8))
                Text(value).font(.caption).foregroundStyle(ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Tier styling (self-contained, royal palette)

    private func rulingTitle(_ tier: String) -> String {
        switch tier {
        case "vindicated": return "⚜︎ Vindicated"
        case "cliffnotes": return "✎ Cliffnotes correction"
        case "apology": return "🙇 Royal apology"
        case "cancellation", "cancelled": return "🚫 Cancelled"
        default: return "The reckoning"
        }
    }

    private func tierBadge(_ tier: String) -> some View {
        Text(tierLabel(tier))
            .font(.caption.weight(.bold)).foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(tierColor(tier)))
    }

    private func tierLabel(_ t: String) -> String {
        switch t {
        case "standing": return "⚖︎ STANDING"
        case "vindicated": return "⚜︎ VINDICATED"
        case "cliffnotes": return "✎ CLIFFNOTES"
        case "apology": return "🙇 APOLOGY"
        case "cancellation", "cancelled": return "🚫 CANCELLED"
        default: return t.uppercased()
        }
    }

    private func tierColor(_ t: String) -> Color {
        switch t {
        case "vindicated": return .green
        case "apology": return .red
        case "cliffnotes": return .orange
        case "cancellation", "cancelled": return .gray
        default: return .blue
        }
    }
}
