import SwiftUI

// PRISM: RELEASE Agent-A 2026-06-27 — Brick Bench now on real CC0 wood texture (see docs/ASSET_ATTRIBUTIONS.md)
// PRISM: RELEASE Agent-Design(brickbench-macos) 2026-07-04 — mirrored iOS v10/v11 "Toy Workshop"
// chrome (molded plastic buttons, studded-brick swatches, iris-ring header) onto the desktop
// two-pane layout. Chrome only: LegoBuilderSession API, palette state, BrickLink import/export,
// and 3D viewport wiring are unchanged.

// MARK: - Workshop theme (game-local tokens, ported from the iOS "Toy Workshop" pass)

/// Brick Bench's local material language: molded ABS plastic on a wooden bench.
/// The chrome accent IS the canonical LEGO red from the brick palette, so UI
/// and bricks never disagree about what red is.
private enum WorkshopTheme {
    static let accent = LegoBrickColor.classicRed.swatch          // (0.76, 0.05, 0.08)
    static let accentEdge = Color(red: 0.46, green: 0.03, blue: 0.05)
    static let studHighlight = Color.white.opacity(0.45)
    static let studShade = Color.black.opacity(0.22)
    static let moldLine = Color.black.opacity(0.24)
    static let capCorner: CGFloat = 10
    static let edgeDepth: CGFloat = 2
}

// MARK: - Molded plastic button (replaces flat bordered buttons on this surface)

/// A chunky injection-molded button: a raised cap sitting on a darker base
/// edge. Pressing sinks the cap into the edge — the whole button reads as a
/// physical part, not a system control.
private struct PlasticButtonStyle: ButtonStyle {
    var accent: Color? = nil          // nil = neutral plastic in the panel's tone
    var edge: Color? = nil
    var compact = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let face: Color = accent ?? Kaleido.panelHi
        let edgeColor: Color = edge ?? Color.black.opacity(Kaleido.isDark ? 0.55 : 0.30)
        let textColor: Color = accent == nil ? Kaleido.ink : .white
        let shape = RoundedRectangle(cornerRadius: WorkshopTheme.capCorner, style: .continuous)

        configuration.label
            .font(Kaleido.rounded(compact ? 12 : 13, .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, compact ? 9 : 14)
            .padding(.vertical, compact ? 5 : 8)
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
    var width: CGFloat = 34
    var height: CGFloat = 34
    var corner: CGFloat = 8

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

// MARK: - Main view

struct LegoBuilderView: View {
    @ObservedObject var session: LegoBuilderSession
    @State private var exportedXML = ""
    @State private var importXML = ""
    @State private var importMessage = ""
    @State private var capturingAction: BrickControlAction? = nil
    @State private var showingSettings = false
    @State private var gizmoColors: GizmoAxisColors = .classic
    // UI-only filter (which element family the size shelf shows); doesn't touch
    // persisted session state beyond keeping `selectedSize` in the same family.
    @State private var selectedKind: LegoElementKind = .brick

    private let gridSize = 12

    var body: some View {
        HStack(spacing: 18) {
            builderCanvas
            controlPanel
        }
        .padding(18)
        .background(woodWorkbenchBackground)
        .onAppear { selectedKind = session.selectedSize.elementKind }
        .onChange(of: selectedKind) { _, newKind in
            if session.selectedSize.elementKind != newKind {
                session.selectedSize = LegoBrickSize.allCases.first { $0.elementKind == newKind } ?? session.selectedSize
            }
        }
    }

    // The Brick Bench's signature workbench: real wood texture with a light
    // darkening wash tuned per paper so cards on top of it stay readable.
    private var woodWorkbenchBackground: some View {
        Image("brickbench_wood")
            .resizable()
            .scaledToFill()
            .overlay(Color.black.opacity(Kaleido.isDark ? 0.30 : 0.10))
            .clipped()
            .ignoresSafeArea()
    }

    private var builderCanvas: some View {
        VStack(alignment: .leading, spacing: 14) {
            workshopHeader
            canvasBody
        }
        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
    }

    // In-canvas header: the shared iris ring, but the glyph inside is a real
    // molded 2x2 brick tile instead of a stock SF symbol — same motif as the
    // iOS "Toy Workshop" header.
    private var workshopHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle().fill(WorkshopTheme.accent.opacity(0.16))
                Circle().strokeBorder(
                    AngularGradient(gradient: Gradient(colors: irisColors(WorkshopTheme.accent)), center: .center),
                    lineWidth: 2.5
                )
                BrickStudTile(color: WorkshopTheme.accent, studsWide: 2, studsDeep: 2,
                              width: 26, height: 26, corner: 6)
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Brick Bench")
                    .font(Kaleido.title(26))
                    .foregroundStyle(Kaleido.ink)
                Text("Clean-room LEGO-style layout. Export generates BrickLink-compatible wanted-list XML.")
                    .font(.subheadline)
                    .foregroundStyle(Kaleido.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                StatBadge(label: "Bricks", value: "\(session.document.bricks.count)", accent: WorkshopTheme.accent)
                StatBadge(label: "Layer", value: "\(session.selectedLayer)", accent: WorkshopTheme.accent)
            }

            Picker("View", selection: $session.canvasStyle.animation(.easeInOut)) {
                ForEach(BoardStyle.allCases) { style in
                    Label(style.rawValue, systemImage: style.icon).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Hot-swap between the flat 2D layout and the 3D build view")
        }
    }

    @ViewBuilder
    private var canvasBody: some View {
        switch session.canvasStyle {
        case .flat:
            flatCanvas.transition(.opacity)
        case .iso:
            LegoBuilder3DView(
                document: session.document,
                selectedOrigin: $session.selectedOrigin,
                selectedSize: session.selectedSize,
                selectedColor: session.selectedColor,
                selectedLayer: session.selectedLayer,
                selectedBrickID: $session.selectedBrickID,
                onMove: { id, dx, dy, dLayer in
                    session.moveBrick(id: id, dx: dx, dy: dy, dLayer: dLayer, gridSize: gridSize)
                    exportedXML = ""
                },
                onRotate: { id, quarters in
                    session.rotateBrick(id: id, by: quarters, gridSize: gridSize)
                    exportedXML = ""
                },
                onCommand: handleBrickCommand,
                controls: session.controls,
                capturingAction: $capturingAction,
                onRebind: { action, keyCode in
                    if keyCode != 53 {            // Esc cancels without rebinding
                        session.controls.bind(action, to: keyCode)
                    }
                    capturingAction = nil
                },
                axisColors: gizmoColors
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(WorkshopTheme.moldLine, lineWidth: 2))
            .transition(.opacity)
        }
    }

    private var flatCanvas: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(gridSize)

            ZStack(alignment: .topLeading) {
                grid(cell: cell)
                ForEach(session.document.bricks) { brick in
                    brickView(brick, cell: cell)
                }
                selectionGhost(cell: cell)
            }
            .frame(width: side, height: side)
            .background(Kaleido.panelHi.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(WorkshopTheme.moldLine, lineWidth: 2))
        }
    }

    // MARK: - Control panel ("tool shelf")

    private var controlPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                toolShelfHeader

                PaletteShelf(
                    selectedKind: $selectedKind,
                    selectedSize: $session.selectedSize,
                    selectedColor: $session.selectedColor,
                    selectedLayer: $session.selectedLayer,
                    accent: WorkshopTheme.accent
                )

                addBrickRow

                Text(session.selectedBrickID == nil
                     ? "Tip: press E to place. Click a brick to select it, then move with arrows or ←→ ↑↓, raise/lower with Space/Tab, and rotate with Q/R."
                     : "Brick selected — move with arrows or ←→ ↑↓ · Space raises, Tab lowers · Q/R rotate · Esc undo, Page Down redo.")
                    .font(.caption)
                    .foregroundStyle(Kaleido.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                PartsShelf(parts: session.document.partsSummary)

                Divider()

                importExportShelf
            }
            .padding(16)
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Kaleido.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.10), .clear],
                                             startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Kaleido.outline, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var toolShelfHeader: some View {
        HStack {
            Text("Palette")
                .font(Kaleido.title(19))
                .foregroundStyle(Kaleido.ink)
            Spacer()
            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .imageScale(.medium)
            }
            .buttonStyle(PlasticButtonStyle(compact: true))
            .help("Brick Bench settings")
            .popover(isPresented: $showingSettings, arrowEdge: .trailing) {
                settingsPopover
            }
        }
    }

    // Mirrors the iOS "Add Brick" bar: a preview tile of exactly what will be
    // placed, plus the chunky molded action button.
    private var addBrickRow: some View {
        HStack(spacing: 12) {
            BrickStudTile(
                color: session.selectedColor.swatch,
                studsWide: max(session.selectedSize.studsWide, session.selectedSize.studsDeep),
                studsDeep: min(session.selectedSize.studsWide, session.selectedSize.studsDeep),
                width: 42, height: 30, corner: 7
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Button("Add Brick") {
                    placeSelectedBrick()
                }
                .buttonStyle(PlasticButtonStyle(accent: WorkshopTheme.accent, edge: WorkshopTheme.accentEdge))
                .help("Place brick (\(BrickControls.keyName(forKeyCode: session.controls.keyCodes[.placeBrick] ?? -1)))")

                Button("Clear") {
                    session.clearDocument()
                    exportedXML = ""
                }
                .buttonStyle(PlasticButtonStyle(compact: true))
            }

            Spacer()
        }
    }

    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Brick Bench settings", systemImage: "gearshape")
                    .font(.headline)
                Spacer()
                Button {
                    showingSettings = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            controlsSettings
            Divider()
            gizmoColorSettings
        }
        .padding(16)
        .frame(width: 320)
    }

    // Tucked-away advanced setting: rebind keys (press-to-capture) + behavior.
    private var controlsSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard")
                .font(.subheadline.bold())
            VStack(alignment: .leading, spacing: 6) {
                ForEach(BrickControlAction.allCases) { action in
                    HStack {
                        Text(action.displayName)
                        Spacer()
                        Button {
                            capturingAction = action
                        } label: {
                        Text(capturingAction == action
                             ? "press a key…"
                             : BrickControls.keyName(forKeyCode: session.controls.keyCodes[action] ?? -1))
                                .frame(minWidth: 70)
                        }
                        .buttonStyle(PlasticButtonStyle(compact: true))
                    }
                }
                Divider()
                Toggle("Invert ↑ / ↓", isOn: $session.controls.invertForwardBack)
                Toggle("Invert raise / lower", isOn: $session.controls.invertVertical)
                HStack {
                    Button("Undo") { session.undo() }
                        .disabled(!session.canUndo)
                    Button("Redo") { session.redo() }
                        .disabled(!session.canRedo)
                }
                .buttonStyle(PlasticButtonStyle(compact: true))
                Button("Reset to defaults") {
                    session.controls = .defaults
                    capturingAction = nil
                }
                .buttonStyle(PlasticButtonStyle(compact: true))
            }
            .padding(.top, 4)
            .font(.caption)
        }
        .font(.caption)
    }

    // Tucked-away advanced setting: recolor the move gizmo's axis arrows.
    // These native ColorPickers are left untouched — only the surrounding
    // chrome changes.
    private var gizmoColorSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gizmo colors")
                .font(.subheadline.bold())
            ColorPicker("X axis", selection: $gizmoColors.x, supportsOpacity: false)
            ColorPicker("Y axis", selection: $gizmoColors.y, supportsOpacity: false)
            ColorPicker("Z axis", selection: $gizmoColors.z, supportsOpacity: false)
            HStack {
                Button("RGB") { gizmoColors = .classic }
                Button("Colorblind-safe") { gizmoColors = .colorblindSafe }
            }
            .buttonStyle(PlasticButtonStyle(compact: true))
        }
        .font(.caption)
    }

    private var importExportShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BrickLink")
                .font(.headline)
                .foregroundStyle(Kaleido.ink)

            HStack(spacing: 10) {
                Button("Export XML") {
                    exportedXML = BrickLinkWantedListExporter.xml(for: session.document)
                }
                .buttonStyle(PlasticButtonStyle(accent: WorkshopTheme.accent, edge: WorkshopTheme.accentEdge))
                .disabled(session.document.bricks.isEmpty)

                Button("Import XML") {
                    importWantedList()
                }
                .buttonStyle(PlasticButtonStyle(compact: true))
            }

            TextEditor(text: $importXML)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 74)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Kaleido.panelHi)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(WorkshopTheme.moldLine, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if importXML.isEmpty {
                        Text("Paste BrickLink wanted-list XML")
                            .font(.caption)
                            .foregroundStyle(Kaleido.ink3)
                            .padding(10)
                            .allowsHitTesting(false)
                    }
                }

            if !importMessage.isEmpty {
                Text(importMessage)
                    .font(.caption)
                    .foregroundStyle(Kaleido.ink2)
            }

            if !exportedXML.isEmpty {
                TextEditor(text: $exportedXML)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Kaleido.panelHi)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(WorkshopTheme.moldLine, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Flat canvas drawing (unchanged geometry/interaction)

    private func grid(cell: CGFloat) -> some View {
        ForEach(0..<gridSize, id: \.self) { y in
            ForEach(0..<gridSize, id: \.self) { x in
                Rectangle()
                    .fill((x + y).isMultiple(of: 2) ? Color.black.opacity(0.035) : Color.white.opacity(0.14))
                    .frame(width: cell, height: cell)
                    .position(x: CGFloat(x) * cell + cell / 2, y: CGFloat(y) * cell + cell / 2)
                    .onTapGesture {
                        session.selectedOrigin = clampedOrigin(LegoGridPoint(x: x, y: y), for: session.selectedSize)
                    }
            }
        }
    }

    private func selectionGhost(cell: CGFloat) -> some View {
        let origin = clampedOrigin(session.selectedOrigin, for: session.selectedSize)
        return RoundedRectangle(cornerRadius: 8)
            .fill(session.selectedColor.swatch.opacity(0.28))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(session.selectedColor.swatch, lineWidth: 2))
            .frame(width: CGFloat(session.selectedSize.studsWide) * cell, height: CGFloat(session.selectedSize.studsDeep) * cell)
            .position(
                x: CGFloat(origin.x) * cell + CGFloat(session.selectedSize.studsWide) * cell / 2,
                y: CGFloat(origin.y) * cell + CGFloat(session.selectedSize.studsDeep) * cell / 2
            )
    }

    private func brickView(_ brick: LegoBrick, cell: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(brick.color.swatch.gradient)
                .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 4)
            studs(for: brick, cell: cell)
        }
        .frame(width: CGFloat(brick.footprintWide) * cell, height: CGFloat(brick.footprintDeep) * cell)
        .position(
            x: CGFloat(brick.origin.x) * cell + CGFloat(brick.footprintWide) * cell / 2,
            y: CGFloat(brick.origin.y) * cell + CGFloat(brick.footprintDeep) * cell / 2 - CGFloat(brick.layer) * 3
        )
    }

    private func studs(for brick: LegoBrick, cell: CGFloat) -> some View {
        ForEach(0..<(brick.footprintWide * brick.footprintDeep), id: \.self) { index in
            let x = index % brick.footprintWide
            let y = index / brick.footprintWide
            Circle()
                .fill(Color.white.opacity(0.32))
                .overlay(Circle().stroke(.black.opacity(0.12), lineWidth: 1))
                .frame(width: cell * 0.42, height: cell * 0.42)
                .position(x: CGFloat(x) * cell + cell / 2, y: CGFloat(y) * cell + cell / 2)
        }
    }

    private func clampedOrigin(_ origin: LegoGridPoint, for size: LegoBrickSize) -> LegoGridPoint {
        LegoGridPoint(
            x: min(max(origin.x, 0), gridSize - size.studsWide),
            y: min(max(origin.y, 0), gridSize - size.studsDeep)
        )
    }

    private func placeSelectedBrick() {
        session.addBrick(size: session.selectedSize,
                         color: session.selectedColor,
                         origin: clampedOrigin(session.selectedOrigin, for: session.selectedSize),
                         layer: session.selectedLayer)
        exportedXML = ""
    }

    private func handleBrickCommand(_ action: BrickControlAction) {
        switch action {
        case .placeBrick:
            placeSelectedBrick()
        case .undo:
            session.undo()
            exportedXML = ""
        case .redo:
            session.redo()
            exportedXML = ""
        default:
            break
        }
    }

    private func importWantedList() {
        do {
            let imported = try BrickLinkWantedListImporter.document(from: importXML)
            session.replaceDocument(imported)
            exportedXML = ""
            importMessage = "Imported \(imported.bricks.count) placed parts."
        } catch {
            importMessage = "Import failed: check wanted-list XML."
        }
    }
}

// MARK: - Palette shelf (kind tabs, size chips, color swatches, layer stepper)

/// The molded-plastic palette: Brick/Plate tabs, stud-dot size chips, and
/// studded-brick color swatches — the same "the palette is made of the toy"
/// language as the iOS Toy Workshop pass, adapted to a desktop side panel.
private struct PaletteShelf: View {
    @Binding var selectedKind: LegoElementKind
    @Binding var selectedSize: LegoBrickSize
    @Binding var selectedColor: LegoBrickColor
    @Binding var selectedLayer: Int
    let accent: Color

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
            layerRow
        }
    }

    private var kindTabs: some View {
        HStack(spacing: 8) {
            ForEach(LegoElementKind.allCases) { kind in
                kindTab(kind)
            }
        }
    }

    private func kindTab(_ kind: LegoElementKind) -> some View {
        let isSelected = kind == selectedKind
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Button {
            selectedKind = kind
        } label: {
            HStack(spacing: 8) {
                BrickProfileShape(kind: kind)
                    .fill(isSelected ? Color.white : Kaleido.ink3)
                    .frame(width: 24, height: 15)
                Text(kind.displayName)
                    .font(Kaleido.rounded(13, .semibold))
            }
            .foregroundStyle(isSelected ? .white : Kaleido.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                shape.fill(isSelected ? accent : Kaleido.panelHi)
                    .overlay(
                        shape.fill(LinearGradient(
                            colors: [Color.white.opacity(isSelected ? 0.22 : 0.10), .clear],
                            startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(shape.strokeBorder(WorkshopTheme.moldLine, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .help(kind.displayName)
    }

    private var layerRow: some View {
        HStack(spacing: 10) {
            arrowButton("minus") { selectedLayer = max(0, selectedLayer - 1) }
            Text("Layer \(selectedLayer)")
                .font(Kaleido.rounded(14, .semibold))
                .monospacedDigit()
                .foregroundStyle(Kaleido.ink)
                .frame(minWidth: 72)
            arrowButton("plus") { selectedLayer = min(12, selectedLayer + 1) }
            Spacer()
        }
    }

    private func arrowButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(Kaleido.rounded(12, .bold))
                .frame(width: 26, height: 15)
        }
        .buttonStyle(PlasticButtonStyle(compact: true))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Kaleido.rounded(11, .semibold))
            .foregroundStyle(Kaleido.ink2)
            .textCase(.uppercase)
    }

    // Size chips show the actual footprint as a stud-dot glyph with a compact
    // monospaced dimension label.
    private func sizeChip(_ size: LegoBrickSize) -> some View {
        let isSelected = size == selectedSize
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return Button {
            selectedSize = size
        } label: {
            VStack(spacing: 4) {
                studDots(size, selected: isSelected)
                Text("\(size.studsWide)×\(size.studsDeep)")
                    .font(Kaleido.rounded(10, .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(isSelected ? Color.white : Kaleido.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                shape.fill(isSelected ? accent : Kaleido.panelHi)
                    .overlay(shape.strokeBorder(isSelected ? WorkshopTheme.moldLine : Kaleido.hairline,
                                                lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .help(size.displayName)
    }

    private func studDots(_ size: LegoBrickSize, selected: Bool) -> some View {
        let dot: CGFloat = 4
        return VStack(spacing: 2) {
            ForEach(0..<size.studsWide, id: \.self) { _ in
                HStack(spacing: 2) {
                    ForEach(0..<size.studsDeep, id: \.self) { _ in
                        Circle()
                            .fill(selected ? Color.white.opacity(0.92) : Kaleido.ink3)
                            .frame(width: dot, height: dot)
                    }
                }
            }
        }
        .frame(height: 10, alignment: .center)
    }

    // Color swatches are mini studded bricks — the palette itself is made of
    // the toy. Selection is a canonical-red ring, not a wash.
    private func colorSwatch(_ color: LegoBrickColor) -> some View {
        let isSelected = color == selectedColor
        return Button {
            selectedColor = color
        } label: {
            VStack(spacing: 3) {
                BrickStudTile(color: color.swatch, studsWide: 2, studsDeep: 2,
                              width: 34, height: 34, corner: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(accent, lineWidth: 2.5)
                            .padding(-3)
                            .opacity(isSelected ? 1 : 0)
                    )
                Text(color.displayName)
                    .font(Kaleido.rounded(10, .regular))
                    .foregroundStyle(isSelected ? Kaleido.ink : Kaleido.ink2)
                    .lineLimit(1)
            }
            .frame(width: 50)
        }
        .buttonStyle(.plain)
        .help(color.displayName)
    }
}

// MARK: - Parts shelf

/// The build's bill of materials as mini studded tiles — a live preview of
/// the BrickLink export, mirroring the iOS Parts manifest.
private struct PartsShelf: View {
    let parts: [LegoPartSummary]

    private var totalParts: Int {
        parts.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PARTS")
                    .font(Kaleido.rounded(11, .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Kaleido.ink2)
                Spacer()
                Text("\(totalParts) part\(totalParts == 1 ? "" : "s")")
                    .font(Kaleido.rounded(11, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Kaleido.ink2)
            }
            if parts.isEmpty {
                Text("No bricks placed yet.")
                    .font(Kaleido.rounded(12, .regular))
                    .foregroundStyle(Kaleido.ink3)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(parts) { part in
                            partChip(part)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func partChip(_ part: LegoPartSummary) -> some View {
        let size = LegoBrickSize.partNumber(part.partNumber)
        let cols = max(size?.studsWide ?? 2, size?.studsDeep ?? 2)
        let rows = min(size?.studsWide ?? 2, size?.studsDeep ?? 2)
        return HStack(spacing: 6) {
            BrickStudTile(color: part.color.swatch, studsWide: cols, studsDeep: rows,
                          width: 30, height: 22, corner: 6)
            VStack(alignment: .leading, spacing: 0) {
                Text("×\(part.quantity)")
                    .font(Kaleido.rounded(11, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Kaleido.ink)
                Text(part.color.displayName)
                    .font(.system(size: 9))
                    .foregroundStyle(Kaleido.ink3)
            }
        }
        .help("\(part.quantity) \(part.color.displayName) \(size?.displayName ?? part.partNumber)")
    }
}
