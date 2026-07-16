import SwiftUI

struct CatanAdventurerDock: View {
    let matchAdventurer: CatanAdventurer?
    let activeAdventurer: CatanAdventurer?
    let counsel: CatanCounsel?
    let storeMessage: String?
    var onCreate: () -> Void
    var onEdit: () -> Void
    var onBegin: () -> Void

    private let accent = Color(red: 0.80, green: 0.52, blue: 0.24)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let storeMessage {
                characterNotice(storeMessage)
            }
            Group {
                if let matchAdventurer {
                    inMatch(matchAdventurer)
                } else if let activeAdventurer {
                    ready(activeAdventurer)
                } else {
                    empty
                }
            }
        }
        .foregroundStyle(PrismetDesign.ink)
        .prismetCard()
    }

    private func characterNotice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Character notice").font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(PrismetDesign.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Character notice: \(message)")
    }

    private var empty: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 13) {
                emptyIdentity
                Spacer(minLength: 8)
                createButton
            }
            VStack(alignment: .leading, spacing: 12) {
                emptyIdentity
                createButton.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var emptyIdentity: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 38))
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Bring a hero to the table").font(.headline)
                Text("Create an optional identity for future Catan matches.")
                    .font(.caption)
                    .foregroundStyle(PrismetDesign.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var createButton: some View {
        Button("Create adventurer", action: onCreate)
            .buttonStyle(AccentButtonStyle(accent: accent))
            .frame(minHeight: 44)
            .accessibilityLabel("Create adventurer")
    }

    private func ready(_ adventurer: CatanAdventurer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    identity(adventurer, size: 48)
                    Spacer(minLength: 8)
                    editButton(adventurer)
                }
                VStack(alignment: .leading, spacing: 10) {
                    identity(adventurer, size: 48)
                    editButton(adventurer)
                }
            }
            Text("Ready for next match")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
            Button("Begin as \(adventurer.name)", action: onBegin)
                .buttonStyle(AccentButtonStyle(accent: accent))
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityLabel("Begin a new Catan match as \(adventurer.name)")
        }
    }

    private func inMatch(_ adventurer: CatanAdventurer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            identity(adventurer, size: 52, includeBackground: true)
            if let counsel {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hero's Counsel").font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(counsel.message)
                        .font(.caption)
                        .foregroundStyle(PrismetDesign.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PrismetDesign.panelHi, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Hero's Counsel: \(counsel.message)")
            }
        }
    }

    private func identity(_ adventurer: CatanAdventurer, size: CGFloat, includeBackground: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            CatanCrestMedallion(crest: adventurer.crest, classChoice: adventurer.classChoice, size: size)
            VStack(alignment: .leading, spacing: 3) {
                Text(adventurer.name).font(.headline)
                Text("Level 1 \(adventurer.classChoice.displayName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                Text(includeBackground
                     ? "\(adventurer.species.displayName) • \(adventurer.background.displayName)"
                     : adventurer.species.displayName)
                    .font(.caption)
                    .foregroundStyle(PrismetDesign.ink2)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func editButton(_ adventurer: CatanAdventurer) -> some View {
        Button("Edit", action: onEdit)
            .buttonStyle(GlassButtonStyle())
            .frame(minHeight: 44)
            .accessibilityLabel("Edit \(adventurer.name)")
    }
}
