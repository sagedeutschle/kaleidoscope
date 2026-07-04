import SwiftUI

// PRISM: RELEASE Agent-A 2026-06-27 — Brick Bench now on real CC0 wood texture (see docs/ASSET_ATTRIBUTIONS.md)

struct LegoBuilderView: View {
    @ObservedObject var session: LegoBuilderSession
    @State private var exportedXML = ""
    @State private var importXML = ""
    @State private var importMessage = ""
    @State private var capturingAction: BrickControlAction? = nil
    @State private var showingSettings = false
    @State private var gizmoColors: GizmoAxisColors = .classic

    private let gridSize = 12

    var body: some View {
        HStack(spacing: 18) {
            builderCanvas
            controlPanel
        }
        .padding(18)
        .background(
            Image("brickbench_wood")
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.10))
                .clipped()
                .ignoresSafeArea()
        )
    }

    private var builderCanvas: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brick Bench")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.18, green: 0.22, blue: 0.18))
                    Text("Clean-room LEGO-style layout. Export generates BrickLink-compatible wanted-list XML.")
                        .foregroundStyle(Color.black.opacity(0.62))
                }
                Spacer()
                Picker("View", selection: $session.canvasStyle.animation(.easeInOut)) {
                    ForEach(BoardStyle.allCases) { style in
                        Label(style.rawValue, systemImage: style.icon).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .help("Hot-swap between the flat 2D layout and the 3D build view")
            }

            canvasBody
        }
        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
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
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.black.opacity(0.14), lineWidth: 2))
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
            .background(Color.white.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.black.opacity(0.14), lineWidth: 2))
        }
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Palette")
                    .font(.title2.bold())
                Spacer()
                Button {
                    showingSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .imageScale(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Brick Bench settings")
                .popover(isPresented: $showingSettings, arrowEdge: .trailing) {
                    settingsPopover
                }
            }

            Picker("Brick", selection: $session.selectedSize) {
                ForEach(LegoBrickSize.allCases) { size in
                    Text(size.displayName).tag(size)
                }
            }

            Picker("Color", selection: $session.selectedColor) {
                ForEach(LegoBrickColor.allCases) { color in
                    Text(color.displayName).tag(color)
                }
            }

            Stepper("Layer \(session.selectedLayer)", value: $session.selectedLayer, in: 0...12)

            HStack {
                Button("Add Brick") {
                    placeSelectedBrick()
                }
                .buttonStyle(.borderedProminent)
                .help("Place brick (\(BrickControls.keyName(forKeyCode: session.controls.keyCodes[.placeBrick] ?? -1)))")

                Button("Clear") {
                    session.clearDocument()
                    exportedXML = ""
                }
            }

            Text(session.selectedBrickID == nil
                 ? "Tip: press E to place. Click a brick to select it, then move with arrows or ←→ ↑↓, raise/lower with Space/Tab, and rotate with Q/R."
                 : "Brick selected — move with arrows or ←→ ↑↓ · Space raises, Tab lowers · Q/R rotate · Esc undo, Page Down redo.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text("Parts")
                .font(.headline)
            if session.document.partsSummary.isEmpty {
                Text("No bricks placed yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(session.document.partsSummary) { part in
                    HStack {
                        Circle().fill(part.color.swatch).frame(width: 12, height: 12)
                        Text("\(part.quantity)x \(part.partNumber)")
                        Spacer()
                        Text(part.color.displayName).foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button("Export XML") {
                    exportedXML = BrickLinkWantedListExporter.xml(for: session.document)
                }
                .disabled(session.document.bricks.isEmpty)

                Button("Import XML") {
                    importWantedList()
                }
            }

            TextEditor(text: $importXML)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 74)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.12)))
                .overlay(alignment: .topLeading) {
                    if importXML.isEmpty {
                        Text("Paste BrickLink wanted-list XML")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                }

            if !importMessage.isEmpty {
                Text(importMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !exportedXML.isEmpty {
                TextEditor(text: $exportedXML)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 140)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.12)))
            }

            Spacer()
        }
        .frame(width: 292)
        .padding(18)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                        .buttonStyle(.bordered)
                        .controlSize(.small)
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
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Reset to defaults") {
                    session.controls = .defaults
                    capturingAction = nil
                }
                .controlSize(.small)
            }
            .padding(.top, 4)
            .font(.caption)
        }
        .font(.caption)
    }

    // Tucked-away advanced setting: recolor the move gizmo's axis arrows.
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
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .font(.caption)
    }

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
