import SwiftUI

struct CatanAdventurerCreatorView: View {
    @ObservedObject var store: CatanAdventurerStore
    var onSaved: (CatanAdventurer) -> Void
    var onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedSwap: CatanAbility?
    @State private var secondSwap: CatanAbility?
    @State private var validationMessage: String?
    @State private var showCredits = false
    @State private var showResetConfirmation = false

    private let accent = Color(red: 0.80, green: 0.52, blue: 0.24)
    private var draft: CatanAdventurerDraft { store.draft ?? .new() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heading
                    progressRail
                    stepBody
                    navigation
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .facetBackground(accent, multiHue: true)
            .navigationTitle("Quick Adventurer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel).accessibilityLabel("Cancel adventurer creator")
                }
            }
            .sheet(isPresented: $showCredits) { CatanRulesCreditsView() }
            .confirmationDialog(
                "Reset adventurer?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset adventurer", role: .destructive, action: resetAdventurer)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes your saved adventurer and unfinished draft. Existing Catan matches stay unchanged.")
            }
        }
    }

    private var heading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                crest
                headingCopy
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 12) {
                crest
                headingCopy
            }
        }
    }

    private var crest: some View {
        CatanCrestMedallion(crest: draft.crest, classChoice: draft.classChoice, size: 58)
            .transition(
                reduceMotion
                    ? .opacity.animation(.easeInOut(duration: 0.18))
                    : .scale.combined(with: .opacity).animation(.spring(response: 0.38, dampingFraction: 0.75))
            )
            .id("\(draft.crest.rawValue)-\(draft.classChoice.rawValue)")
    }

    private var headingCopy: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Quick Adventurer").font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(PrismetDesign.ink)
            Text("Level 1 • 5E-compatible")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PrismetDesign.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Text("A personal seat identity for your next Catan match.")
                .font(.caption)
                .foregroundStyle(PrismetDesign.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var progressRail: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Step \(currentIndex + 1) of \(CatanCreatorStep.allCases.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PrismetDesign.ink2)
                    Text(CatanCreatorStep.allCases[currentIndex].displayName)
                        .font(.headline)
                        .foregroundStyle(PrismetDesign.ink)
                    HStack(spacing: 5) {
                        ForEach(CatanCreatorStep.allCases.indices, id: \.self) { index in
                            Capsule().fill(index <= currentIndex ? accent : PrismetDesign.outline)
                                .frame(height: 8)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Creator progress, step \(currentIndex + 1) of \(CatanCreatorStep.allCases.count), \(CatanCreatorStep.allCases[currentIndex].displayName)")
            } else {
                HStack(spacing: 5) {
                    ForEach(Array(CatanCreatorStep.allCases.enumerated()), id: \.element.id) { index, step in
                        VStack(spacing: 5) {
                            Capsule().fill(index <= currentIndex ? accent : PrismetDesign.outline)
                                .frame(height: 6)
                            Text(step.displayName).font(.caption2.weight(index == currentIndex ? .bold : .regular))
                                .foregroundStyle(index <= currentIndex ? PrismetDesign.ink : PrismetDesign.ink3)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Step \(index + 1): \(step.displayName)")
                        .accessibilityValue(index == currentIndex ? "Current" : (index < currentIndex ? "Complete" : "Upcoming"))
                    }
                }
                .accessibilityLabel("Creator progress")
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: currentIndex)
    }

    @ViewBuilder private var stepBody: some View {
        switch draft.step {
        case .calling: callingStep
        case .origin: originStep
        case .abilities: abilitiesStep
        case .identity: identityStep
        case .review: reviewStep
        }
    }

    private var callingStep: some View {
        stepSection(title: "Choose your calling", detail: "Choose the outlook you want at the Catan table.") {
            choiceGrid(CatanAdventurerClass.allCases, columns: [GridItem(.adaptive(minimum: 145), spacing: 10)]) { choice in
                choiceCard(title: choice.displayName, detail: choice.summary, symbol: choice.symbolName, selected: draft.classChoice == choice) {
                    store.updateDraft { $0.chooseClass(choice) }
                }
            }
        }
    }

    private var originStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepSection(title: "Choose your origin", detail: "These are story choices only; Catan rules stay exactly the same.") {
                Text("Species").font(.headline).foregroundStyle(PrismetDesign.ink)
                choiceGrid(CatanAdventurerSpecies.allCases, columns: [GridItem(.adaptive(minimum: 145), spacing: 10)]) { choice in
                    choiceCard(title: choice.displayName, detail: choice.summary, symbol: choice.symbolName, selected: draft.species == choice) {
                        store.updateDraft { $0.species = choice }
                    }
                }
            }
            stepSection(title: "Background", detail: "Pick the path that colors your adventure.") {
                choiceGrid(CatanAdventurerBackground.allCases, columns: [GridItem(.adaptive(minimum: 145), spacing: 10)]) { choice in
                    choiceCard(title: choice.displayName, detail: choice.summary, symbol: choice.symbolName, selected: draft.background == choice) {
                        store.updateDraft { $0.background = choice }
                    }
                }
            }
        }
    }

    private var abilitiesStep: some View {
        stepSection(title: "Arrange your abilities", detail: "Your calling starts with a smart standard array. Select two rows, then swap their values.") {
            VStack(spacing: 8) {
                ForEach(CatanAbility.allCases, id: \.self) { ability in
                    abilityRow(ability)
                }
            }
            VStack(spacing: 10) {
                Button("Swap values") { swapSelectedAbilities() }
                    .buttonStyle(AccentButtonStyle(accent: accent)).frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(selectedSwap == nil || secondSwap == nil)
                    .accessibilityLabel("Swap selected ability values")
                Button("Restore smart assignment") {
                    selectedSwap = nil
                    secondSwap = nil
                    validationMessage = nil
                    store.updateDraft {
                        $0.abilities = .recommended(for: $0.classChoice)
                        $0.didCustomizeAbilities = false
                    }
                }
                .buttonStyle(GlassButtonStyle()).frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityLabel("Restore smart ability assignment")
            }
            if let validationMessage {
                validationError(validationMessage)
            }
        }
    }

    private var identityStep: some View {
        stepSection(title: "Name your adventurer", detail: "This name appears only on newly started Catan matches.") {
            TextField("Adventurer name", text: Binding(get: { draft.name }, set: { name in
                validationMessage = nil
                store.updateDraft { $0.name = name }
            }))
            .textInputAutocapitalization(.words).autocorrectionDisabled()
            .padding(12).background(PrismetDesign.panelHi, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(PrismetDesign.outline))
            .accessibilityLabel("Adventurer name")
            Text("Up to 24 characters. Your name is trimmed when saved.").font(.caption).foregroundStyle(PrismetDesign.ink3)
            Text("Choose a crest").font(.headline).foregroundStyle(PrismetDesign.ink)
            choiceGrid(CatanAdventurerCrest.allCases, columns: [GridItem(.adaptive(minimum: 105), spacing: 10)]) { crest in
                choiceCard(title: crest.displayName, detail: crest.summary, symbol: crest.symbolName, selected: draft.crest == crest) {
                    store.updateDraft { $0.crest = crest }
                }
            }
        }
    }

    private var reviewStep: some View {
        stepSection(title: "Review your adventurer", detail: "Saving changes your identity for future matches only.") {
            HStack(alignment: .top, spacing: 14) {
                CatanCrestMedallion(crest: draft.crest, classChoice: draft.classChoice)
                VStack(alignment: .leading, spacing: 5) {
                    Text(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unnamed adventurer" : draft.name)
                        .font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(PrismetDesign.ink)
                    Text("Level 1 \(draft.classChoice.displayName)").font(.headline).foregroundStyle(accent)
                    Text("\(draft.species.displayName) • \(draft.background.displayName)").font(.subheadline).foregroundStyle(PrismetDesign.ink2)
                }
                Spacer(minLength: 0)
            }
            .prismetCard()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(CatanAbility.allCases, id: \.self) { ability in
                    let score = draft.abilities[ability]
                    VStack(spacing: 2) {
                        Text(ability.displayName).font(.caption.weight(.semibold))
                        Text("\(score) \(modifierText(score))").font(.system(.headline, design: .rounded, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).padding(8).background(PrismetDesign.panelHi, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            if let validationMessage { Text(validationMessage).font(.subheadline.weight(.semibold)).foregroundStyle(.red).accessibilityLabel("Validation error: \(validationMessage)") }
            if let message = store.message { Text(message).font(.caption).foregroundStyle(PrismetDesign.ink2) }
            Button("Save for next match", action: saveDraft)
                .buttonStyle(AccentButtonStyle(accent: accent)).frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityLabel("Save adventurer for next Catan match")
            Button("Rules & Credits") { showCredits = true }
                .buttonStyle(GlassButtonStyle()).frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityLabel("Open Rules and Credits")
            if store.active != nil {
                Button("Reset adventurer", role: .destructive) { showResetConfirmation = true }
                    .buttonStyle(GlassButtonStyle())
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityLabel("Reset saved adventurer")
            }
        }
    }

    private var navigation: some View {
        HStack(spacing: 10) {
            if currentIndex > 0 {
                Button("Back") { setStep(currentIndex - 1) }.buttonStyle(GlassButtonStyle()).frame(minHeight: 44)
            }
            Spacer()
            if currentIndex < CatanCreatorStep.allCases.count - 1 {
                Button("Continue") { setStep(currentIndex + 1) }.buttonStyle(AccentButtonStyle(accent: accent)).frame(minHeight: 44)
            }
        }
    }

    private var currentIndex: Int { CatanCreatorStep.allCases.firstIndex(of: draft.step) ?? 0 }

    private func setStep(_ index: Int) {
        validationMessage = nil
        store.updateDraft { $0.step = CatanCreatorStep.allCases[index] }
    }
    private func swapSelectedAbilities() {
        guard let first = selectedSwap, let second = secondSwap else { return }
        selectedSwap = nil
        secondSwap = nil
        store.updateDraft { $0.swapAbilities(first, second) }
    }
    private func abilityRow(_ ability: CatanAbility) -> some View {
        let selected = selectedSwap == ability || secondSwap == ability
        return Button {
            if selectedSwap == ability { selectedSwap = nil }
            else if secondSwap == ability { secondSwap = nil }
            else if selectedSwap == nil { selectedSwap = ability }
            else if secondSwap == nil { secondSwap = ability }
            else { selectedSwap = ability; secondSwap = nil }
        } label: {
            HStack { Text(ability.displayName).font(.headline); Spacer(); Text("\(draft.abilities[ability]) \(modifierText(draft.abilities[ability]))").font(.system(.headline, design: .rounded, weight: .bold)); if selected { Image(systemName: "checkmark.circle.fill") } }
                .foregroundStyle(selected ? accent : PrismetDesign.ink).padding(12).frame(maxWidth: .infinity, minHeight: 44)
                .background(PrismetDesign.panelHi, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(selected ? accent : PrismetDesign.outline, lineWidth: selected ? 3 : 1))
        }
        .buttonStyle(.plain).accessibilityLabel("\(ability.displayName), \(draft.abilities[ability])").accessibilityValue(selected ? "Selected for swap" : "Double tap to select for swap").accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func modifierText(_ score: Int) -> String { let value = CatanAbilityScores.modifier(forScore: score); return value >= 0 ? "+\(value)" : "\(value)" }
    private func saveDraft() {
        do {
            onSaved(try store.completeDraft())
        } catch let error as CatanAdventurerValidationError {
            validationMessage = validationText(error)
            let recoveryStep = Self.recoveryStep(for: error, from: draft.step)
            if recoveryStep != draft.step {
                store.updateDraft { $0.step = recoveryStep }
            }
        } catch {
            validationMessage = "Your adventurer could not be saved. Please try again."
        }
    }
    static func recoveryStep(for error: CatanAdventurerValidationError, from currentStep: CatanCreatorStep) -> CatanCreatorStep {
        error == .invalidStandardArray ? .abilities : currentStep
    }
    private func resetAdventurer() {
        store.deleteActive()
        if store.active == nil { onCancel() }
    }
    private func validationError(_ message: String) -> some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.red)
            .accessibilityLabel("Validation error: \(message)")
    }
    private func validationText(_ error: CatanAdventurerValidationError) -> String { switch error { case .emptyName: return "Add an adventurer name before saving."; case .nameTooLong: return "Names must be 24 characters or fewer."; case .invalidStandardArray: return "Abilities must use the standard array: 15, 14, 13, 12, 10, 8." } }
    private func stepSection<Content: View>(title: String, detail: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 12) { Text(title).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(PrismetDesign.ink); Text(detail).font(.subheadline).foregroundStyle(PrismetDesign.ink2); content() }.prismetCard() }
    private func choiceGrid<Item: Identifiable, Content: View>(_ items: [Item], columns: [GridItem], @ViewBuilder content: @escaping (Item) -> Content) -> some View { LazyVGrid(columns: columns, spacing: 10) { ForEach(items) { content($0) } } }
    private func choiceCard(title: String, detail: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View { Button(action: action) { VStack(alignment: .leading, spacing: 7) { HStack { Image(systemName: symbol).font(.title3); Spacer(); if selected { Image(systemName: "checkmark.circle.fill") } }; Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(PrismetDesign.ink2).fixedSize(horizontal: false, vertical: true) }.foregroundStyle(selected ? accent : PrismetDesign.ink).padding(12).frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading).background(PrismetDesign.panelHi, in: RoundedRectangle(cornerRadius: 13, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(selected ? accent : PrismetDesign.outline, lineWidth: selected ? 3 : 1)) }.buttonStyle(.plain).accessibilityLabel(title).accessibilityValue(selected ? "Selected. \(detail)" : detail).accessibilityAddTraits(selected ? .isSelected : []) }
}

struct CatanCrestMedallion: View {
    let crest: CatanAdventurerCrest
    let classChoice: CatanAdventurerClass
    var size: CGFloat = 88
    private var color: Color { switch classChoice { case .barbarian, .fighter: return .red; case .bard, .paladin: return .orange; case .cleric, .druid: return .green; case .monk, .ranger: return .blue; case .rogue, .warlock: return .purple; case .sorcerer, .wizard: return .pink } }
    var body: some View { ZStack { Circle().fill(LinearGradient(colors: [color, color.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)); Circle().strokeBorder(PrismetDesign.gold, lineWidth: 3); Image(systemName: crest.symbolName).font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(.white) }.frame(width: size, height: size).accessibilityLabel("\(crest.displayName) crest for \(classChoice.displayName)") }
}

struct CatanRulesCreditsView: View {
    private let accent = Color(red: 0.80, green: 0.52, blue: 0.24)
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) { Text("Rules & Credits").font(.system(.title, design: .serif, weight: .bold)); Text(CatanRulesAttribution.notice).font(.body); Link("Open SRD 5.2.1", destination: CatanRulesAttribution.sourceURL); Link("Creative Commons BY 4.0", destination: CatanRulesAttribution.licenseURL) }.foregroundStyle(PrismetDesign.ink).padding(20) }.facetBackground(accent, multiHue: true).accessibilityLabel("Rules and Credits") }
}
