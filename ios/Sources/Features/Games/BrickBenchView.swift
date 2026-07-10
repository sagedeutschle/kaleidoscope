// PRISM: RELEASE Agent-Design(brickbench) 2026-07-03 - v10 design pass
// PRISM: RELEASE Agent-Design(brickbench) 2026-07-03 — ported desktop wood workbench bg + canonical LegoBrickColor palette + 12x12 board
// PRISM: RELEASE Agent-Design(brickbench-3d) 2026-07-03 — 3D-primary: real SceneKit LegoBuilder3DView is now the main canvas; fake 2D Canvas preview removed
import SwiftUI
import UIKit

// MARK: - Workshop theme (game-local tokens, v10 "The Toy Workshop")

/// Brick Bench's local material language: molded ABS plastic on a wooden bench.
/// The chrome accent IS the canonical LEGO red from the brick palette, so UI
/// and bricks never disagree about what red is.
private enum WorkshopTheme {
    static let accent = LegoBrickColor.classicRed.swatch          // (0.76, 0.05, 0.08)
    static let accentEdge = Color(red: 0.46, green: 0.03, blue: 0.05)
    static let manualRedDeep = Color(red: 0.60, green: 0.04, blue: 0.06)
    static let studHighlight = Color.white.opacity(0.45)
    static let studShade = Color.black.opacity(0.22)
    static let moldLine = Color.black.opacity(0.24)
    static let capCorner: CGFloat = 11
    static let edgeDepth: CGFloat = 3
    static let maxContentWidth: CGFloat = 700
}

// MARK: - Molded plastic button (replaces glass capsules on this surface)

/// A chunky injection-molded button: a raised cap sitting on a darker base
/// edge. Pressing sinks the cap into the edge — the whole button reads as a
/// physical part, not a system pill.
private struct PlasticButtonStyle: ButtonStyle {
    var accent: Color? = nil          // nil = neutral plastic in the paper's tone
    var edge: Color? = nil
    var compact = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let face: Color = accent ?? PrismetDesign.panelHi
        let edgeColor: Color = edge ?? Color.black.opacity(PrismetDesign.isDark ? 0.55 : 0.30)
        let textColor: Color = accent == nil ? PrismetDesign.ink : .white
        let shape = RoundedRectangle(cornerRadius: WorkshopTheme.capCorner, style: .continuous)

        configuration.label
            .font(PrismetDesign.rounded(compact ? 13 : 14, .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 7 : 9)
            .background(
                shape.fill(face)
                    .overlay(
                        shape.fill(LinearGradient(
                            colors: [Color.white.opacity(0.22), .clear, Color.black.opacity(0.10)],
                            startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(shape.strokeBorder(WorkshopTheme.moldLine, lineWidth: 1))
            )
            .offset(y: configuration.isPressed ? WorkshopTheme.edgeDepth - 1 : 0)
            .background(shape.fill(edgeColor).offset(y: WorkshopTheme.edgeDepth))
            .padding(.bottom, WorkshopTheme.edgeDepth)
            .opacity(isEnabled ? 1 : 0.45)
    }
}

// MARK: - Mini studded brick (the signature swatch / glyph renderer)

/// A miniature top-down LEGO element: a plastic slab with a grid of studs,
/// each catching a top-left highlight so it reads molded, not painted.
private struct BrickStudTile: View {
    let color: Color
    var studsWide: Int = 2   // columns
    var studsDeep: Int = 2   // rows
    var width: CGFloat = 40
    var height: CGFloat = 40
    var corner: CGFloat = 9

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(0.28), .clear, Color.black.opacity(0.16)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(WorkshopTheme.moldLine, lineWidth: 1)
                )
            studGrid
        }
        .frame(width: width, height: height)
    }

    private var studGrid: some View {
        let cell = min((width - 8) / CGFloat(max(studsWide, 1)),
                       (height - 8) / CGFloat(max(studsDeep, 1)))
        let stud = cell * 0.68
        let gap = max(cell - stud, 1)
        return VStack(spacing: gap) {
            ForEach(0..<max(studsDeep, 1), id: \.self) { _ in
                HStack(spacing: gap) {
                    ForEach(0..<max(studsWide, 1), id: \.self) { _ in
                        Circle()
                            .fill(color)
                            .overlay(
                                Circle().fill(LinearGradient(
                                    colors: [WorkshopTheme.studHighlight, .clear],
                                    startPoint: .topLeading, endPoint: .center))
                            )
                            .overlay(Circle().strokeBorder(WorkshopTheme.studShade, lineWidth: 0.8))
                            .frame(width: stud, height: stud)
                    }
                }
            }
        }
    }
}

struct BrickBenchView: View {
    private let accountID: UUID?
    @StateObject private var persistence = PersistedGameSession<BrickBenchSnapshot>(gameID: .brickBench)
    @State private var document = LegoBuildDocument()
    @State private var selectedKind: LegoElementKind = .brick
    @State private var selectedSize: LegoBrickSize = .twoByFour
    @State private var selectedColor: LegoBrickColor = .classicRed
    @State private var selectedLayer: Int = 0
    @State private var selectedBrickID: UUID?
    // Placement ghost anchor (top-left stud). A tap on the 3D baseplate moves it
    // here; "Add Brick" places the current palette selection at this stud.
    @State private var selectedOrigin = LegoGridPoint(x: 0, y: 0)

    @State private var showExport = false
    @State private var showImport = false
    @State private var importText = ""

    // Match the desktop Brick Bench board (LegoSceneGeometry.gridSize = 12).
    private let gridSize = 12
    private let accent = WorkshopTheme.accent

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    private var selectedBrick: LegoBrick? {
        guard let id = selectedBrickID else { return nil }
        return document.bricks.first { $0.id == id }
    }

    private var totalParts: Int {
        document.partsSummary.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                workshopHeader

                // MAIN CANVAS: a genuine SceneKit 3D LEGO scene. Tap the baseplate
                // to aim the placement ghost, tap a brick to select it; drag to
                // orbit the turntable camera, pinch to zoom.
                LegoBuilder3DView(
                    document: document,
                    selectedOrigin: $selectedOrigin,
                    selectedSize: selectedSize,
                    selectedColor: selectedColor,
                    selectedLayer: selectedLayer,
                    selectedBrickID: $selectedBrickID
                )
                .frame(minHeight: 340)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .prismetCard()
                .onChange(of: selectedBrickID) { _, _ in save() }
                .onChange(of: selectedOrigin) { _, _ in save() }

                addBrickBar

                if let brick = selectedBrick {
                    EditBar(
                        brick: brick,
                        accent: accent,
                        onMove: { dx, dy in
                            document.move(id: brick.id, dx: dx, dy: dy, dLayer: 0, gridSize: gridSize)
                            save()
                        },
                        onLayer: { dLayer in
                            document.move(id: brick.id, dx: 0, dy: 0, dLayer: dLayer, gridSize: gridSize)
                            save()
                        },
                        onRotate: {
                            document.rotate(id: brick.id, by: 1, gridSize: gridSize)
                            save()
                        },
                        onDuplicate: {
                            if let id = document.duplicate(id: brick.id, gridSize: gridSize) {
                                selectedBrickID = id
                            }
                            save()
                        },
                        onDelete: {
                            document.bricks.removeAll { $0.id == brick.id }
                            selectedBrickID = nil
                            save(forceCloud: true)
                        },
                        onDeselect: {
                            selectedBrickID = nil
                            save()
                        }
                    )
                    .prismetCard()
                }

                PaletteView(
                    selectedKind: $selectedKind,
                    selectedSize: $selectedSize,
                    selectedColor: $selectedColor,
                    selectedLayer: $selectedLayer,
                    accent: accent,
                    colorFor: legoColor
                )
                .prismetCard()

                PartsManifest(parts: document.partsSummary, totalParts: totalParts)

                actionButtons
            }
            .frame(maxWidth: WorkshopTheme.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(16)
        }
        .navigationTitle("Brick Bench")
        .navigationBarTitleDisplayMode(.inline)
        .background(woodWorkbenchBackground)
        .sensoryFeedback(.impact(weight: .light), trigger: document.bricks.count)
        .onChange(of: selectedKind) { _, newKind in
            if selectedSize.elementKind != newKind {
                selectedSize = LegoBrickSize.allCases.first { $0.elementKind == newKind } ?? selectedSize
            }
            save()
        }
        .onChange(of: selectedSize) { _, _ in save() }
        .onChange(of: selectedColor) { _, _ in save() }
        .onChange(of: selectedLayer) { _, _ in save() }
        .onAppear {
            persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
        }
        .onDisappear { save(forceCloud: true) }
        .sheet(isPresented: $showExport) {
            ExportSheet(xml: BrickLinkWantedListExporter.xml(for: document),
                        partCount: totalParts,
                        accent: accent)
        }
        .sheet(isPresented: $showImport) {
            ImportSheet(text: $importText, accent: accent) {
                if let imported = try? BrickLinkWantedListImporter.document(from: importText) {
                    document = imported
                    selectedBrickID = nil
                    save(forceCloud: true)
                }
                showImport = false
            }
        }
    }

    // In-world header: the shared iris ring, but the glyph inside is a real
    // molded 2x2 brick tile instead of a stock SF symbol.
    private var workshopHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle().fill(accent.opacity(0.16))
                Circle().strokeBorder(
                    AngularGradient(gradient: Gradient(colors: irisColors(accent)), center: .center),
                    lineWidth: 2.5
                )
                BrickStudTile(color: accent, studsWide: 2, studsDeep: 2,
                              width: 26, height: 26, corner: 6)
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Brick Bench")
                    .font(PrismetDesign.title(26))
                    .foregroundStyle(PrismetDesign.ink)
                Text("The toy workshop")
                    .font(.subheadline)
                    .foregroundStyle(PrismetDesign.ink2)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                StatBadge(label: "Bricks", value: "\(document.bricks.count)", accent: accent)
                StatBadge(label: "Layer", value: "\(selectedLayer)", accent: accent)
            }
        }
    }

    // The Brick Bench's signature workbench: the same real wood texture the
    // desktop build uses, with a light darkening wash so the cards read cleanly.
    private var woodWorkbenchBackground: some View {
        Image("brickbench_wood")
            .resizable()
            .scaledToFill()
            .overlay(Color.black.opacity(PrismetDesign.isDark ? 0.34 : 0.14))
            .clipped()
            .ignoresSafeArea()
    }

    // Explicit placement bar, mirroring the desktop "Add Brick" button: places
    // the current palette selection at the ghost's stud (set by tapping the 3D
    // baseplate). The leading tile previews exactly what will be placed.
    private var addBrickBar: some View {
        HStack(spacing: 12) {
            BrickStudTile(
                color: selectedColor.swatch,
                studsWide: max(selectedSize.studsWide, selectedSize.studsDeep),
                studsDeep: min(selectedSize.studsWide, selectedSize.studsDeep),
                width: 48, height: 34, corner: 7
            )
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedSize.displayName)")
                    .font(PrismetDesign.rounded(14, .semibold))
                    .foregroundStyle(PrismetDesign.ink)
                Text("Stud (\(selectedOrigin.x), \(selectedOrigin.y)) · Layer \(selectedLayer)")
                    .font(PrismetDesign.rounded(11, .medium))
                    .monospacedDigit()
                    .foregroundStyle(PrismetDesign.ink2)
            }
            Spacer()
            Button {
                placeSelectedBrick()
            } label: {
                Text("Add Brick")
            }
            .buttonStyle(PlasticButtonStyle(accent: accent, edge: WorkshopTheme.accentEdge))
            .accessibilityLabel("Add \(selectedColor.displayName) \(selectedSize.displayName)")
        }
        .padding(12)
        .prismetCard()
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                document.clear()
                selectedBrickID = nil
                save(forceCloud: true)
            } label: {
                Label("Clear", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlasticButtonStyle())

            Button {
                showExport = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlasticButtonStyle(accent: accent, edge: WorkshopTheme.accentEdge))

            Button {
                importText = ""
                showImport = true
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlasticButtonStyle())
        }
    }

    // MARK: - Interaction

    /// Place the current palette selection at the ghost origin (set by tapping
    /// the 3D baseplate), clamped fully onto the board. Mirrors desktop
    /// `LegoBuilderView.placeSelectedBrick()`.
    private func placeSelectedBrick() {
        let origin = LegoSceneGeometry.clampedOrigin(selectedOrigin, for: selectedSize)
        let brick = LegoBrick(
            size: selectedSize,
            color: selectedColor,
            origin: origin,
            layer: selectedLayer
        )
        document.add(brick)
        selectedBrickID = brick.id
        save()
    }

    private func snapshot() -> BrickBenchSnapshot {
        BrickBenchSnapshot(
            document: document,
            selectedKind: selectedKind,
            selectedSize: selectedSize,
            selectedColor: selectedColor,
            selectedLayer: selectedLayer,
            selectedBrickID: selectedBrickID
        )
    }

    private func restore(_ snapshot: BrickBenchSnapshot) {
        document = snapshot.document
        selectedKind = snapshot.selectedKind
        selectedSize = snapshot.selectedSize
        selectedColor = snapshot.selectedColor
        selectedLayer = snapshot.selectedLayer
        selectedBrickID = snapshot.selectedBrickID
    }

    private func save(forceCloud: Bool = false) {
        persistence.save(snapshot: snapshot(), score: document.bricks.count, forceCloud: forceCloud)
    }

    // MARK: - Color mapping

    private func legoColor(_ color: LegoBrickColor) -> Color {
        color.swatch
    }
}

// MARK: - Edit Bar

private struct EditBar: View {
    let brick: LegoBrick
    let accent: Color
    let onMove: (_ dx: Int, _ dy: Int) -> Void
    let onLayer: (_ dLayer: Int) -> Void
    let onRotate: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onDeselect: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(brick.size.displayName)")
                    .font(PrismetDesign.rounded(15, .semibold))
                    .foregroundStyle(PrismetDesign.ink)
                Spacer()
                Text("Layer \(brick.layer)")
                    .font(PrismetDesign.rounded(12, .medium))
                    .monospacedDigit()
                    .foregroundStyle(PrismetDesign.ink2)
            }

            HStack(spacing: 16) {
                dPad
                Spacer()
                layerControls
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
            LazyVGrid(columns: columns, spacing: 10) {
                Button {
                    onRotate()
                } label: {
                    Label("Rotate", systemImage: "rotate.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlasticButtonStyle())

                Button {
                    onDuplicate()
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlasticButtonStyle())

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlasticButtonStyle())

                Button {
                    onDeselect()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlasticButtonStyle(accent: accent, edge: WorkshopTheme.accentEdge))
            }
        }
    }

    private var dPad: some View {
        VStack(spacing: 6) {
            arrow("chevron.up", label: "Move back") { onMove(0, -1) }
            HStack(spacing: 6) {
                arrow("chevron.left", label: "Move left") { onMove(-1, 0) }
                arrow("chevron.right", label: "Move right") { onMove(1, 0) }
            }
            arrow("chevron.down", label: "Move forward") { onMove(0, 1) }
        }
    }

    private var layerControls: some View {
        VStack(spacing: 6) {
            Text("Layer")
                .font(PrismetDesign.rounded(11, .medium))
                .foregroundStyle(PrismetDesign.ink2)
            arrow("plus", label: "Layer up") { onLayer(1) }
            arrow("minus", label: "Layer down") { onLayer(-1) }
        }
    }

    private func arrow(_ system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(PrismetDesign.rounded(14, .bold))
                .frame(width: 32, height: 18)
        }
        .buttonStyle(PlasticButtonStyle(compact: true))
        .accessibilityLabel(label)
    }
}

// MARK: - Palette

private struct PaletteView: View {
    @Binding var selectedKind: LegoElementKind
    @Binding var selectedSize: LegoBrickSize
    @Binding var selectedColor: LegoBrickColor
    @Binding var selectedLayer: Int
    let accent: Color
    let colorFor: (LegoBrickColor) -> Color

    private var sizes: [LegoBrickSize] {
        LegoBrickSize.allCases.filter { $0.elementKind == selectedKind }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            kindTabs

            sectionLabel("Size")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sizes) { size in
                        sizeChip(size)
                    }
                }
                .padding(.vertical, 2)
            }

            sectionLabel("Color")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LegoBrickColor.allCases) { color in
                        colorSwatch(color)
                    }
                }
                .padding(.vertical, 2)
            }

            sectionLabel("Layer")
            HStack(spacing: 12) {
                Button {
                    selectedLayer = max(0, selectedLayer - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(PrismetDesign.rounded(14, .bold))
                        .frame(width: 28, height: 18)
                }
                .buttonStyle(PlasticButtonStyle(compact: true))
                .accessibilityLabel("Layer down")

                Text("Layer \(selectedLayer)")
                    .font(PrismetDesign.rounded(15, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(PrismetDesign.ink)
                    .frame(minWidth: 90)

                Button {
                    selectedLayer += 1
                } label: {
                    Image(systemName: "plus")
                        .font(PrismetDesign.rounded(14, .bold))
                        .frame(width: 28, height: 18)
                }
                .buttonStyle(PlasticButtonStyle(compact: true))
                .accessibilityLabel("Layer up")

                Spacer()
            }
        }
    }

    // Brick/Plate as two chunky molded tabs with side-profile silhouettes —
    // same `selectedKind` binding the segmented picker drove.
    private var kindTabs: some View {
        HStack(spacing: 8) {
            ForEach(LegoElementKind.allCases) { kind in
                kindTab(kind)
            }
        }
    }

    private func kindTab(_ kind: LegoElementKind) -> some View {
        let isSelected = kind == selectedKind
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        return Button {
            selectedKind = kind
        } label: {
            HStack(spacing: 8) {
                BrickProfileShape(kind: kind)
                    .fill(isSelected ? Color.white : PrismetDesign.ink3)
                    .frame(width: 26, height: 16)
                Text(kind.displayName)
                    .font(PrismetDesign.rounded(14, .semibold))
            }
            .foregroundStyle(isSelected ? .white : PrismetDesign.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                shape.fill(isSelected ? accent : PrismetDesign.panelHi)
                    .overlay(
                        shape.fill(LinearGradient(
                            colors: [Color.white.opacity(isSelected ? 0.22 : 0.10), .clear],
                            startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(shape.strokeBorder(WorkshopTheme.moldLine, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(PrismetDesign.rounded(12, .semibold))
            .foregroundStyle(PrismetDesign.ink2)
            .textCase(.uppercase)
    }

    // Size chips show the actual footprint as a stud-dot glyph (2 x 4 = a
    // 2-row, 4-column dot grid) with a compact monospaced dimension label.
    private func sizeChip(_ size: LegoBrickSize) -> some View {
        let isSelected = size == selectedSize
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Button {
            selectedSize = size
        } label: {
            VStack(spacing: 5) {
                studDots(size, selected: isSelected)
                Text("\(size.studsWide)×\(size.studsDeep)")
                    .font(PrismetDesign.rounded(11, .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(isSelected ? Color.white : PrismetDesign.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                shape.fill(isSelected ? accent : PrismetDesign.panelHi)
                    .overlay(shape.strokeBorder(isSelected ? WorkshopTheme.moldLine : PrismetDesign.hairline,
                                                lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(size.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func studDots(_ size: LegoBrickSize, selected: Bool) -> some View {
        let dot: CGFloat = 4
        return VStack(spacing: 2) {
            ForEach(0..<size.studsWide, id: \.self) { _ in
                HStack(spacing: 2) {
                    ForEach(0..<size.studsDeep, id: \.self) { _ in
                        Circle()
                            .fill(selected ? Color.white.opacity(0.92) : PrismetDesign.ink3)
                            .frame(width: dot, height: dot)
                    }
                }
            }
        }
        .frame(height: 10, alignment: .center)
        .accessibilityHidden(true)
    }

    // Color swatches are mini studded bricks — the palette itself is made of
    // the toy. Selection is a canonical-red ring, not a wash.
    private func colorSwatch(_ color: LegoBrickColor) -> some View {
        let isSelected = color == selectedColor
        return Button {
            selectedColor = color
        } label: {
            VStack(spacing: 4) {
                BrickStudTile(color: colorFor(color), studsWide: 2, studsDeep: 2,
                              width: 40, height: 40, corner: 9)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(accent, lineWidth: 2.5)
                            .padding(-3)
                            .opacity(isSelected ? 1 : 0)
                    )
                Text(color.displayName)
                    .font(PrismetDesign.rounded(11, .regular))
                    .foregroundStyle(isSelected ? PrismetDesign.ink : PrismetDesign.ink2)
                    .lineLimit(1)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// Side-profile silhouette of a brick (tall) or plate (thin) with two studs on
// top — the tab glyph for the kind switcher.
private struct BrickProfileShape: Shape {
    let kind: LegoElementKind

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let bodyH = kind == .brick ? rect.height * 0.72 : rect.height * 0.34
        let bodyTop = rect.maxY - bodyH
        p.addRoundedRect(
            in: CGRect(x: rect.minX, y: bodyTop, width: rect.width, height: bodyH),
            cornerSize: CGSize(width: 2, height: 2)
        )
        let studW = rect.width * 0.22
        let studH = min(rect.height * 0.22, bodyTop - rect.minY)
        guard studH > 0 else { return p }
        for cx in [rect.width * 0.28, rect.width * 0.72] {
            p.addRect(CGRect(x: rect.minX + cx - studW / 2, y: bodyTop - studH,
                             width: studW, height: studH))
        }
        return p
    }
}

// MARK: - Parts manifest

// Replaces the old duplicate stat badges with something useful: the build's
// bill of materials as mini studded tiles — a live preview of the BrickLink
// export.
private struct PartsManifest: View {
    let parts: [LegoPartSummary]
    let totalParts: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PARTS")
                    .font(PrismetDesign.rounded(12, .semibold))
                    .tracking(0.7)
                    .foregroundStyle(PrismetDesign.ink2)
                Spacer()
                Text("\(totalParts) part\(totalParts == 1 ? "" : "s") total")
                    .font(PrismetDesign.rounded(12, .medium))
                    .monospacedDigit()
                    .foregroundStyle(PrismetDesign.ink2)
            }
            if parts.isEmpty {
                // Contextual, not permanent: disappears with the first brick.
                Text("Tap the baseplate to aim, then Add Brick.")
                    .font(PrismetDesign.rounded(12, .regular))
                    .foregroundStyle(PrismetDesign.ink3)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(parts) { part in
                            partChip(part)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .prismetCard()
    }

    private func partChip(_ part: LegoPartSummary) -> some View {
        let size = LegoBrickSize.partNumber(part.partNumber)
        let cols = max(size?.studsWide ?? 2, size?.studsDeep ?? 2)
        let rows = min(size?.studsWide ?? 2, size?.studsDeep ?? 2)
        return HStack(spacing: 6) {
            BrickStudTile(color: part.color.swatch, studsWide: cols, studsDeep: rows,
                          width: 34, height: 24, corner: 6)
            Text("×\(part.quantity)")
                .font(PrismetDesign.rounded(12, .semibold))
                .monospacedDigit()
                .foregroundStyle(PrismetDesign.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(part.quantity) \(part.color.displayName) \(size?.displayName ?? "part")")
    }
}

// MARK: - Instruction-manual sheet header

// The red band at the top of every LEGO instruction booklet: a molded 2x2
// tile, a serif title, and a plain-speech subtitle.
private struct ManualHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            BrickStudTile(color: WorkshopTheme.accent, studsWide: 2, studsDeep: 2,
                          width: 40, height: 40, corner: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PrismetDesign.title(20))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(PrismetDesign.rounded(12, .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [WorkshopTheme.accent, WorkshopTheme.manualRedDeep],
                                     startPoint: .top, endPoint: .bottom))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Export Sheet

private struct ExportSheet: View {
    let xml: String
    let partCount: Int
    let accent: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                ManualHeader(
                    title: "Wanted List",
                    subtitle: partCount == 1 ? "BrickLink XML · 1 part" : "BrickLink XML · \(partCount) parts"
                )

                ScrollView {
                    Text(xml.isEmpty ? "<INVENTORY>\n</INVENTORY>" : xml)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(PrismetDesign.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(PrismetDesign.panel)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(PrismetDesign.hairline, lineWidth: 1)
                                )
                        )
                }

                Button {
                    UIPasteboard.general.string = xml
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlasticButtonStyle(accent: accent, edge: WorkshopTheme.accentEdge))
            }
            .padding(16)
            .background(PrismetDesign.ground.ignoresSafeArea())
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Import Sheet

private struct ImportSheet: View {
    @Binding var text: String
    let accent: Color
    let onImport: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                ManualHeader(
                    title: "Import Build",
                    subtitle: "Paste a BrickLink wanted list (XML)"
                )

                TextEditor(text: $text)
                    .font(.system(.footnote, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(PrismetDesign.panel)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(PrismetDesign.hairline, lineWidth: 1)
                    )

                Button {
                    onImport()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlasticButtonStyle(accent: accent, edge: WorkshopTheme.accentEdge))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .background(PrismetDesign.ground.ignoresSafeArea())
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
