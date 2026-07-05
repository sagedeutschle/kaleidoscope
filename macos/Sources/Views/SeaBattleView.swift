import SwiftUI

// MARK: - Sea battle visual skin

private enum SeaBattleMaterial {
    static let accent = Color(red: 0.16, green: 0.42, blue: 0.68)
    static let deep = Color(red: 0.075, green: 0.285, blue: 0.455)
    static let deep2 = Color(red: 0.043, green: 0.180, blue: 0.330)
    static let water = Color(red: 0.160, green: 0.545, blue: 0.800)
    static let waterAlt = Color(red: 0.130, green: 0.495, blue: 0.755)
    static let gridLine = Color.white.opacity(0.18)
    static let hull = Color(red: 0.560, green: 0.605, blue: 0.650)
    static let hullHi = Color(red: 0.760, green: 0.800, blue: 0.835)
    static let hullDeck = Color(red: 0.820, green: 0.850, blue: 0.875)
    static let hullShadow = Color(red: 0.300, green: 0.340, blue: 0.385)
    static let hullSunk = Color(red: 0.150, green: 0.175, blue: 0.210)
    static let hullSunkHi = Color(red: 0.250, green: 0.280, blue: 0.320)
    static let hitRed = Color(red: 0.905, green: 0.255, blue: 0.195)
    static let hitGlow = Color(red: 1.00, green: 0.780, blue: 0.360)
    static let splash = Color(red: 0.930, green: 0.975, blue: 1.000)
    static let ember = Color(red: 0.420, green: 0.110, blue: 0.080)
    static let emberHi = Color(red: 0.640, green: 0.190, blue: 0.130)
    static let sonar = Color(red: 0.360, green: 0.700, blue: 0.820)
}

struct SeaBattleView: View {
    @ObservedObject private var session: SeaBattleSession

    @State private var hoverTarget: SeaBattlePoint?
    @State private var dragPlacementID: SeaBattlePlacement.ID?
    @State private var dragAnchor: SeaBattlePoint?
    @State private var dragOrientation: SeaBattleOrientation = .horizontal
    @State private var dragPreviewCells: Set<SeaBattlePoint> = []

    private let gap: CGFloat = 3

    init(session: SeaBattleSession = SeaBattleSession()) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 20) {
            GameHeader(title: "Sea Battle",
                       systemImage: "scope",
                       accent: SeaBattleMaterial.accent,
                       subtitle: statusText) {
                HStack(spacing: 8) {
                    StatBadge(label: "Phase", value: session.isDeploymentPhase ? "Deploy" : "Battle", accent: SeaBattleMaterial.accent)
                    if session.isDeploymentPhase {
                        StatBadge(label: "Fleet", value: "\(session.deployment.placements.count)/\(SeaBattleGame.fleet.count)", accent: SeaBattleMaterial.accent)
                    } else {
                        StatBadge(label: "Turn", value: session.game.currentPlayer == .host ? "You" : "AI", accent: SeaBattleMaterial.accent)
                    }
                }
            }
            .frame(maxWidth: 780)

            if session.isDeploymentPhase {
                deploymentSection
            } else {
                battleSection
            }

            controls
        }
        .padding(24)
        .frame(minWidth: 860, maxWidth: .infinity, minHeight: 620, maxHeight: .infinity)
        .facetBackground(SeaBattleMaterial.deep)
    }

    private var statusText: String {
        if session.isDeploymentPhase {
            if let next = session.deployment.nextLength {
                return "Place your \(shipName(forLength: next))"
            }
            return "Fleet set. Press Ready to start."
        }

        if let winner = session.game.winner {
            return winner == .host ? "You win." : "AI controls the waters."
        }

        if session.isAIThinking {
            return "AI calculating"
        }

        return session.canFireCurrentTurn ? "Fire by clicking a target." : "Waiting for AI"
    }

    private var deploymentSection: some View {
        VStack(spacing: 14) {
            sectionTitle("Standard five-ship deployment")

            oceanPanel {
                deploymentBoard
            }

            HStack(spacing: 10) {
                ForEach(Array(SeaBattleGame.fleet.enumerated()), id: \.offset) { index, length in
                    let targetCount = SeaBattleGame.fleet.prefix(index + 1).filter { $0 == length }.count
                    let placedCount = session.deployment.placements.filter { $0.length == length }.count
                    Capsule()
                        .fill(placedCount >= targetCount ? SeaBattleMaterial.hull : Color.primary.opacity(0.2))
                        .frame(width: CGFloat(length) * 10, height: 7)
                }
                Spacer()
                Text(session.deployment.nextLength.map { "Next: \(shipName(forLength: $0))" } ?? "Fleet complete")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Picker("Direction", selection: Binding(
                    get: { session.deploymentOrientation },
                    set: { session.setDeploymentOrientation($0) }
                )) {
                    Label("Horizontal", systemImage: "arrow.left.and.right").tag(SeaBattleOrientation.horizontal)
                    Label("Vertical", systemImage: "arrow.up.and.down").tag(SeaBattleOrientation.vertical)
                }
                .pickerStyle(.segmented)

                Button {
                    _ = session.autoDeploy()
                } label: {
                    Label("Auto", systemImage: "wand.and.stars")
                }
                .buttonStyle(GlassButtonStyle())
                .disabled(!session.isDeploymentPhase || session.setup.isReady(.host))

                Button {
                    _ = session.clearDeployment()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(GlassButtonStyle())

                Button {
                    _ = session.commitDeployment()
                } label: {
                    Label("Ready", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(AccentButtonStyle(accent: SeaBattleMaterial.accent))
                .disabled(!session.deployment.isComplete)
            }

            StatBadge(label: "Orientation", value: session.deploymentOrientation == .horizontal ? "Rows" : "Columns", accent: SeaBattleMaterial.accent)
        }
    }

    private var battleSection: some View {
        VStack(spacing: 14) {
            sectionTitle("Battle")

            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 10) {
                    Text("Target grid")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.8))
                    targetBoard
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    Text("Your fleet")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.8))
                    ownBoard
                    shipStatus
                }
                .frame(width: 240)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("AI", selection: Binding(
                get: { session.difficulty },
                set: { session.setDifficulty($0) }
            )) {
                ForEach(SeaBattleAIDifficulty.allCases) { difficulty in
                    Text(difficulty.title).tag(difficulty)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            Button {
                session.resetBattle()
                hoverTarget = nil
            } label: {
                Label("New Battle", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(AccentButtonStyle(accent: SeaBattleMaterial.accent))

            Menu {
                Button("Save") { session.saveNow() }
                Button("Load") { session.reloadSavedState() }
            } label: {
                Label("State", systemImage: "externaldrive")
            }
            .buttonStyle(GlassButtonStyle())

            Spacer()
        }
    }

    private var deploymentBoard: some View {
        GeometryReader { geo in
            let cellSize = (min(geo.size.width, geo.size.height) - gap * CGFloat(SeaBattleGame.size - 1)) / CGFloat(SeaBattleGame.size)
            SeaBattleBoardView(
                cellSize: cellSize,
                gap: gap,
                size: SeaBattleGame.size,
                board: nil,
                deployment: session.deployment,
                showShips: true,
                showShots: false,
                showCrosshair: false,
                hover: $hoverTarget,
                previewCells: dragPreviewCells,
                isInteractive: session.isDeploymentPhase && !session.setup.isReady(.host),
                onTap: { point in
                    _ = session.tapDeploymentCell(point)
                },
                onHover: { _, _ in },
                onDragStart: { point in
                    beginDeploymentDrag(from: point)
                },
                onDragChanged: { point, translation, stride in
                    moveDeploymentDrag(from: point, translation: translation, stride: stride)
                },
                onDragEnded: {
                    endDeploymentDrag()
                }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private var targetBoard: some View {
        GeometryReader { geo in
            let cellSize = (min(geo.size.width, geo.size.height) - gap * CGFloat(SeaBattleGame.size - 1)) / CGFloat(SeaBattleGame.size)
            SeaBattleBoardView(
                cellSize: cellSize,
                gap: gap,
                size: SeaBattleGame.size,
                board: session.game.board(for: .guest),
                deployment: nil,
                showShips: false,
                showShots: true,
                showCrosshair: !session.game.isGameOver && session.canFireCurrentTurn,
                hover: $hoverTarget,
                previewCells: [],
                isInteractive: !session.isDeploymentPhase,
                onTap: { point in
                    guard session.canFire(at: point) else { return }
                    let aiTurn = session.fire(point)
                    if aiTurn {
                        queueAIMove()
                    }
                },
                onHover: { point, hovering in
                    hoverTarget = hovering ? point : nil
                },
                onDragStart: { _ in },
                onDragChanged: { _, _, _ in },
                onDragEnded: {}
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private var ownBoard: some View {
        let board = session.game.board(for: .host)
        return GeometryReader { geo in
            let cellSize = (min(geo.size.width, geo.size.height) - gap * CGFloat(SeaBattleGame.size - 1)) / CGFloat(SeaBattleGame.size)
            SeaBattleBoardView(
                cellSize: cellSize,
                gap: gap,
                size: SeaBattleGame.size,
                board: board,
                deployment: nil,
                showShips: true,
                showShots: true,
                showCrosshair: false,
                hover: .constant(nil),
                previewCells: [],
                isInteractive: false,
                onTap: { _ in },
                onHover: { _, _ in },
                onDragStart: { _ in },
                onDragChanged: { _, _, _ in },
                onDragEnded: {}
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 240)
        .frame(maxWidth: .infinity)
    }

    private var shipStatus: some View {
        let board = session.game.board(for: .host)
        let statuses = shipStatuses(on: board)

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(statuses.enumerated()), id: \.offset) { _, status in
                HStack(spacing: 6) {
                    Capsule()
                        .fill(status.isSunk ? Color.secondary.opacity(0.3) : SeaBattleMaterial.hull)
                        .frame(width: CGFloat(status.length) * 9, height: 7)
                    Text("\(shipName(forLength: status.length))")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(status.isSunk ? .secondary : .primary)
                    if status.isSunk {
                        Spacer()
                        Image(systemName: "drop.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SeaBattleMaterial.sonar)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }

    private func oceanPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [SeaBattleMaterial.deep, SeaBattleMaterial.deep2], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }

    private func shipName(forLength length: Int) -> String {
        switch length {
        case 5: return "Carrier"
        case 4: return "Battleship"
        case 3: return "Destroyer"
        case 2: return "Patrol"
        default: return "Boat"
        }
    }

    private func beginDeploymentDrag(from point: SeaBattlePoint) {
        guard !session.setup.isReady(.host) else { return }
        guard let placement = session.deployment.placement(containing: point) else {
            dragPlacementID = nil
            dragAnchor = nil
            dragPreviewCells = []
            return
        }

        dragPlacementID = placement.id
        dragAnchor = placement.origin
        dragOrientation = placement.orientation
        dragPreviewCells = Set(placement.cells)
    }

    private func moveDeploymentDrag(from point: SeaBattlePoint, translation: CGSize, stride: CGFloat) {
        guard !session.setup.isReady(.host), stride > 0 else { return }
        if dragPlacementID == nil {
            beginDeploymentDrag(from: point)
        }
        guard let id = dragPlacementID, let anchor = dragAnchor else { return }
        let rowShift = Int((translation.height / stride).rounded())
        let colShift = Int((translation.width / stride).rounded())
        let candidate = SeaBattlePoint(row: anchor.row + rowShift, col: anchor.col + colShift)
        if session.moveHostShip(id: id, to: candidate, orientation: dragOrientation) {
            if let updated = session.deployment.placement(id: id) {
                dragPreviewCells = Set(updated.cells)
            }
        }
    }

    private func endDeploymentDrag() {
        dragPlacementID = nil
        dragAnchor = nil
        dragPreviewCells = []
    }

    private func queueAIMove() {
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                if session.canFireCurrentTurn {
                    _ = session.fireByAI()
                }
            }
        }
    }

    private func shipStatuses(on board: SeaBattleBoard) -> [(length: Int, isSunk: Bool)] {
        let segments = shipSegments(in: board.shipCells)
        let sortedSegments = segments.sorted { $0.count > $1.count }
        var matched = Array(repeating: false, count: sortedSegments.count)
        var result: [(length: Int, isSunk: Bool)] = []

        for length in SeaBattleGame.fleet {
            guard let index = sortedSegments.indices.first(where: { !matched[$0] && sortedSegments[$0].count == length }) else {
                continue
            }
            let segment = sortedSegments[index]
            matched[index] = true
            let sunk = segment.allSatisfy { board.shots.contains($0) }
            result.append((length: length, isSunk: sunk))
        }

        return result
    }

    private func shipSegments(in cells: Set<SeaBattlePoint>) -> [[SeaBattlePoint]] {
        var remaining = cells
        var segments: [[SeaBattlePoint]] = []

        while let start = remaining.first {
            var queue: [SeaBattlePoint] = [start]
            var segment: [SeaBattlePoint] = []
            remaining.remove(start)

            while let point = queue.popLast() {
                segment.append(point)
                let neighbors = [
                    SeaBattlePoint(row: point.row + 1, col: point.col),
                    SeaBattlePoint(row: point.row - 1, col: point.col),
                    SeaBattlePoint(row: point.row, col: point.col + 1),
                    SeaBattlePoint(row: point.row, col: point.col - 1)
                ]
                for neighbor in neighbors where remaining.contains(neighbor) {
                    remaining.remove(neighbor)
                    queue.append(neighbor)
                }
            }
            segments.append(segment)
        }

        return segments
    }
}

private struct SeaBattleBoardView: View {
    let cellSize: CGFloat
    let gap: CGFloat
    let size: Int
    let board: SeaBattleBoard?
    let deployment: SeaBattleFleetDeployment?
    let showShips: Bool
    let showShots: Bool
    let showCrosshair: Bool
    let hover: Binding<SeaBattlePoint?>
    let previewCells: Set<SeaBattlePoint>
    let isInteractive: Bool
    let onTap: (SeaBattlePoint) -> Void
    let onHover: (SeaBattlePoint, Bool) -> Void
    let onDragStart: (SeaBattlePoint) -> Void
    let onDragChanged: (SeaBattlePoint, CGSize, CGFloat) -> Void
    let onDragEnded: () -> Void

    private let labelFont = Font.system(size: 11, weight: .heavy, design: .rounded)
    private let railW: CGFloat = 15

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: gap) {
                Color.clear.frame(width: railW, height: 12)
                ForEach(0..<size, id: \.self) { col in
                    Text("\(col + 1)")
                        .font(labelFont)
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: gap) {
                VStack(spacing: gap) {
                    ForEach(0..<size, id: \.self) { row in
                        Text(Self.rowLetter(row))
                            .font(labelFont)
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(width: railW)
                    }
                }
                gridBoard
            }
        }
    }

    private var gridBoard: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: size), spacing: gap) {
            ForEach(0..<(size * size), id: \.self) { index in
                let point = SeaBattlePoint(row: index / size, col: index % size)
                cell(point)
                    .frame(width: cellSize, height: cellSize)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap(point)
                    }
                    .onHover { hovering in
                        onHover(point, hovering)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { value in
                                onDragStart(point)
                                onDragChanged(point, value.translation, cellSize + gap)
                            }
                            .onEnded { _ in onDragEnded() }
                    )
                    .disabled(!isInteractive)
            }
        }
    }

    private func cell(_ point: SeaBattlePoint) -> some View {
        let shot = (showShots && (board?.shots.contains(point) ?? false))
        let shipCells = deployment?.shipCells ?? board?.shipCells ?? []
        let hasShip = shipCells.contains(point)
        let isPreview = previewCells.contains(point)
        let aimed = showCrosshair && hover.wrappedValue == point

        let isSunkSegment = hasShip ? isSegmentSunk(point: point, in: shipCells, with: board?.shots ?? []) : false
        let (up, down, left, right) = shipNeighbors(point, in: shipCells)

        return ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill((point.row + point.col).isMultiple(of: 2) ? SeaBattleMaterial.water : SeaBattleMaterial.waterAlt)
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(SeaBattleMaterial.gridLine, lineWidth: 0.5)
                )

            if hasShip && (showShips || shot) {
                let style: HullStyle = isSunkSegment ? .sunk : .full
                HullSegment(
                    up: up,
                    down: down,
                    left: left,
                    right: right,
                    style: style,
                    cellSize: cellSize,
                    gap: gap
                )
            }

            if isSunkSegment && showShots && hasShip {
                PegView(ember: true)
                    .padding(4)
            } else if shot {
                if hasShip {
                    PegView(ember: false)
                        .padding(4)
                } else {
                    SplashView()
                }
            }

            if isPreview {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(SeaBattleMaterial.hitGlow.opacity(0.86), lineWidth: 1.4)
                    .padding(2)
            }

            if aimed {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(SeaBattleMaterial.hitGlow, lineWidth: 1.5)
                    .overlay(
                        Image(systemName: "scope")
                            .font(.system(size: cellSize * 0.52, weight: .bold))
                            .foregroundStyle(SeaBattleMaterial.hitGlow.opacity(0.9))
                    )
            }
        }
    }

    private func shipNeighbors(_ point: SeaBattlePoint, in cells: Set<SeaBattlePoint>) -> (Bool, Bool, Bool, Bool) {
        let up = cells.contains(SeaBattlePoint(row: point.row - 1, col: point.col))
        let down = cells.contains(SeaBattlePoint(row: point.row + 1, col: point.col))
        let left = cells.contains(SeaBattlePoint(row: point.row, col: point.col - 1))
        let right = cells.contains(SeaBattlePoint(row: point.row, col: point.col + 1))
        return (up, down, left, right)
    }

    private func isSegmentSunk(point: SeaBattlePoint, in shipCells: Set<SeaBattlePoint>, with shots: Set<SeaBattlePoint>) -> Bool {
        guard board != nil else { return false }
        guard shipCells.contains(point) else { return false }

        var stack: [SeaBattlePoint] = [point]
        var visited: Set<SeaBattlePoint> = []
        var segment: Set<SeaBattlePoint> = []
        visited.insert(point)

        while let current = stack.popLast() {
            segment.insert(current)
            let neighbors = [
                SeaBattlePoint(row: current.row + 1, col: current.col),
                SeaBattlePoint(row: current.row - 1, col: current.col),
                SeaBattlePoint(row: current.row, col: current.col + 1),
                SeaBattlePoint(row: current.row, col: current.col - 1)
            ]
            for next in neighbors where shipCells.contains(next) && !visited.contains(next) {
                visited.insert(next)
                stack.append(next)
            }
        }

        return segment.isSubset(of: shots)
    }

    private static func rowLetter(_ row: Int) -> String {
        let bounded = min(max(row, 0), 25)
        guard let scalar = UnicodeScalar(65 + bounded) else {
            return "A"
        }
        return String(scalar)
    }

    enum HullStyle {
        case full
        case sunk
    }
}

private struct HullSegment: View {
    let up: Bool
    let down: Bool
    let left: Bool
    let right: Bool
    let style: SeaBattleBoardView.HullStyle
    let cellSize: CGFloat
    let gap: CGFloat

    var body: some View {
        let horizontal = left || right
        let nose = cellSize * 0.42
        let tight: CGFloat = 2
        let inset = cellSize * 0.13
        let endInset: CGFloat = 1.5
        let bridge = gap / 2 + 0.3

        let shape = UnevenRoundedRectangle(
            topLeadingRadius: (left || up) ? tight : nose,
            bottomLeadingRadius: (left || down) ? tight : nose,
            bottomTrailingRadius: (right || down) ? tight : nose,
            topTrailingRadius: (right || up) ? tight : nose,
            style: .continuous
        )

        let isMiddle = (left && right) || (up && down)

        ZStack {
            switch style {
            case .full:
                shape.fill(
                    LinearGradient(
                        colors: [SeaBattleMaterial.hullHi, SeaBattleMaterial.hull],
                        startPoint: horizontal ? .top : .leading,
                        endPoint: horizontal ? .bottom : .trailing
                    )
                )
                .overlay(shape.strokeBorder(SeaBattleMaterial.hullShadow.opacity(0.85), lineWidth: 1))

                if isMiddle {
                    Circle()
                        .fill(SeaBattleMaterial.hullDeck)
                        .frame(width: cellSize * 0.20, height: cellSize * 0.20)
                }
            case .sunk:
                shape.fill(
                    LinearGradient(
                        colors: [SeaBattleMaterial.hullSunkHi, SeaBattleMaterial.hullSunk],
                        startPoint: horizontal ? .top : .leading,
                        endPoint: horizontal ? .bottom : .trailing
                    )
                )
                .overlay(shape.strokeBorder(Color.black.opacity(0.45), lineWidth: 1))
            }

            if style == .full && isMiddle {
                SonarTrack(color: SeaBattleMaterial.sonar.opacity(0.18))
            }
        }
        .padding(.top, up ? -bridge : (horizontal ? inset : endInset))
        .padding(.bottom, down ? -bridge : (horizontal ? inset : endInset))
        .padding(.leading, left ? -bridge : (horizontal ? endInset : inset))
        .padding(.trailing, right ? -bridge : (horizontal ? endInset : inset))
    }
}

private struct SonarTrack: View {
    var color: Color

    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 3)
            .strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: [3, 2.5]))
            .padding(1.8)
    }
}

private struct PegView: View {
    var ember: Bool

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: ember ? [SeaBattleMaterial.emberHi, SeaBattleMaterial.ember] : [SeaBattleMaterial.hitGlow, SeaBattleMaterial.hitRed],
                    center: UnitPoint(x: 0.35, y: 0.32),
                    startRadius: 0,
                    endRadius: 18
                )
            )
            .overlay(Circle().strokeBorder(Color.black.opacity(0.28), lineWidth: 0.8))
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(SeaBattleMaterial.splash.opacity(0.45), lineWidth: 1.1)
                .padding(4)
            Circle()
                .fill(SeaBattleMaterial.splash.opacity(0.92))
        }
    }
}

#if DEBUG
#Preview {
    SeaBattleView()
}
#endif
