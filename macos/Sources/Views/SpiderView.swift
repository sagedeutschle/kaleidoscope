import SwiftUI
import UniformTypeIdentifiers

// MARK: - Spider — "The Two-Deck Table"

// Matches the iOS v10 visual direction: real card faces + green felt + run tray.
private enum SpiderTheme {
    static let feltHi = Color(red: 0.157, green: 0.416, blue: 0.267)
    static let felt = Color(red: 0.098, green: 0.325, blue: 0.208)
    static let feltLo = Color(red: 0.047, green: 0.216, blue: 0.129)
    static let feltRail = Color(red: 0.075, green: 0.267, blue: 0.169)
    static let goldLine = PrismetDesign.gold.opacity(0.55)

    static let ivory = Color(red: 0.978, green: 0.966, blue: 0.925)
    static let ivoryLo = Color(red: 0.936, green: 0.915, blue: 0.856)
    static let cardEdge = Color(red: 0.22, green: 0.20, blue: 0.16).opacity(0.55)
    static let inkBlack = Color(red: 0.12, green: 0.13, blue: 0.17)
    static let inkRed = Color(red: 0.71, green: 0.16, blue: 0.18)
    static let backGround = Color(red: 0.082, green: 0.239, blue: 0.157)
}

private enum SpiderSelection: Equatable {
    case card(column: Int, index: Int)

    init?(_ payload: String) {
        let parts = payload.split(separator: ":", omittingEmptySubsequences: true)
        guard parts.count == 2,
              let column = Int(parts[0]),
              let index = Int(parts[1]) else { return nil }
        self = .card(column: column, index: index)
    }

    var payload: String {
        switch self {
        case .card(let column, let index):
            return "\(column):\(index)"
        }
    }
}

private extension SpiderSelection {
    var column: Int {
        switch self {
        case .card(let column, _): return column
        }
    }

    var index: Int {
        switch self {
        case .card(_, let index): return index
        }
    }
}

struct SpiderView: View {
    private static let accent = Color(red: 0.24, green: 0.52, blue: 0.36)

    @ObservedObject var session: SpiderSession
    private let windowSessionID: String

    @State private var selected: SpiderSelection?
    @State private var hovered: SpiderSelection?
    @State private var dropTargetColumn: Int?
    @State private var sweepVisible = false
    @State private var sweepFly = false
    @State private var trayPulse = false
    @State private var showWin = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(session: SpiderSession = SpiderSession(), windowSessionID: String = "spider") {
        self.session = session
        self.windowSessionID = windowSessionID
    }

    var body: some View {
        VStack(spacing: 14) {
            GameHeader(
                title: "Spider",
                systemImage: "suit.spade.fill",
                accent: Self.accent,
                subtitle: session.game.isWon ? "All suits cleared" : "Build King to Ace runs"
            ) {
                StatBadge(label: "Moves", value: "\(session.moves)", accent: Self.accent)
            }

            board
            feltRail
        }
        .padding(20)
        .frame(minWidth: 780, minHeight: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(Self.accent)
        .overlay {
            if showWin {
                SpiderWinBanner(moves: session.moves) { newGame() }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            session.configurePersistence(windowSessionID: windowSessionID)
            showWin = session.game.isWon
        }
        .onChange(of: session.game.completedSets) { oldValue, newValue in
            if newValue > oldValue {
                runCompletedSweep()
            }
        }
        .onChange(of: session.game.isWon) { _, won in
            if won {
                Task { @MainActor in
                    if !reduceMotion {
                        try? await Task.sleep(nanoseconds: 950_000_000)
                    }
                    guard session.game.isWon else { return }
                    withAnimation(.easeOut(duration: 0.25)) { showWin = true }
                }
            } else {
                showWin = false
            }
        }
        .onDisappear { session.saveNow() }
    }

    // MARK: - Board

    private var board: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 4
            let hPad: CGFloat = 8
            let cardWidth = max(24, (geo.size.width - hPad * 2 - spacing * 9) / 10)
            let cardHeight = cardWidth * 1.42
            let baseUp = cardHeight * 0.30
            let baseDown = cardHeight * 0.14
            let maxFanSum = session.game.tableau.map { fanSum($0, up: baseUp, down: baseDown) }.max() ?? 0
            let availableFan = geo.size.height - hPad * 2 - cardHeight
            let squeeze = maxFanSum > 0 ? min(1, max(0.30, availableFan / maxFanSum)) : 1

            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<SpiderGame.columnCount, id: \.self) { column in
                    pile(column,
                         cardWidth: cardWidth,
                         cardHeight: cardHeight,
                         upFan: baseUp * squeeze,
                         downFan: baseDown * squeeze)
                }
            }
            .padding(hPad)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .contentShape(Rectangle())
        }
        .aspectRatio(0.86, contentMode: .fit)
        .background(feltPanel)
        .overlay(alignment: .center) { sweepOverlay }
    }

    private var feltPanel: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                RadialGradient(
                    colors: [SpiderTheme.feltHi, SpiderTheme.felt, SpiderTheme.feltLo],
                    center: .center,
                    startRadius: 40,
                    endRadius: 460
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(SpiderTheme.goldLine, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.30), radius: 14, y: 8)
    }

    private func pile(_ column: Int, cardWidth: CGFloat, cardHeight: CGFloat,
                      upFan: CGFloat, downFan: CGFloat) -> some View {
        let cards = session.game.tableau[column]
        let offsets = fanOffsets(cards, up: upFan, down: downFan)

        return ZStack(alignment: .top) {
            if cards.isEmpty {
                emptySlot(width: cardWidth, height: cardHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { moveSelection(to: column) }
                    .overlay(alignment: .top) {
                        if dropTargetColumn == column {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.yellow.opacity(0.85), lineWidth: 2)
                                .frame(width: cardWidth, height: cardHeight)
                        }
                    }
                    .accessibilityLabel("Empty column")
                    .accessibilityAddTraits(.isButton)
            } else {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    let source = SpiderSelection.card(column: column, index: index)
                    let inSelectedRun = {
                        guard let selected, case .card(let selectedColumn, let selectedIndex) = selected else { return false }
                        return selectedColumn == column && index >= selectedIndex
                    }()
                    let isTop = index == cards.count - 1
                    let isHovered = hovered == source
                    let selectedLift = inSelectedRun || isHovered

                    cardView(card, width: cardWidth, height: cardHeight,
                             isSelectedRun: inSelectedRun, isTop: isTop)
                        .offset(y: offsets[index] - (selectedLift ? 3 : 0))
                        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8),
                                   value: inSelectedRun)
                        .onTapGesture { handleCardTap(column: column, index: index) }
                        .onHover { hovering in
                            hovered = hovering ? source : nil
                        }
                        .onDrag {
                            guard card.isFaceUp else { return NSItemProvider() }
                            return Self.dragProvider(for: source)
                        }
                        .overlay(alignment: .top) {
                            if dropTargetColumn == column {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(Color.yellow.opacity(0.85), lineWidth: 2)
                                    .padding(.trailing, 0)
                            }
                        }
                        .accessibilityLabel(card.isFaceUp
                            ? "\(card.card.rank.shortLabel) of \(card.card.suit.rawValue)"
                            : "Face down card")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .frame(width: cardWidth,
               height: max(cardHeight, (offsets.last ?? 0) + cardHeight),
               alignment: .top)
        .contentShape(Rectangle())
        .onDrop(
            of: [UTType.plainText],
            isTargeted: Binding(
                get: { dropTargetColumn == column },
                set: { targeted in
                    dropTargetColumn = targeted ? column : nil
                }
            ),
            perform: { providers in
                handleDrop(to: column, providers: providers)
            }
        )
    }

    private func fanOffsets(_ cards: [SpiderCard], up: CGFloat, down: CGFloat) -> [CGFloat] {
        var offsets: [CGFloat] = []
        var y: CGFloat = 0
        for index in cards.indices {
            if index > 0 { y += cards[index - 1].isFaceUp ? up : down }
            offsets.append(y)
        }
        return offsets
    }

    private func fanSum(_ cards: [SpiderCard], up: CGFloat, down: CGFloat) -> CGFloat {
        guard cards.count > 1 else { return 0 }
        var total: CGFloat = 0
        for index in 0..<(cards.count - 1) {
            total += cards[index].isFaceUp ? up : down
        }
        return total
    }

    private static func dragProvider(for source: SpiderSelection) -> NSItemProvider {
        NSItemProvider(item: source.payload as NSString, typeIdentifier: UTType.plainText.identifier)
    }

    private func handleDrop(to destinationColumn: Int, providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            if let item {
                let payload = Self.stringPayload(from: item)
                guard let payload,
                      let source = SpiderSelection(payload),
                      source.column != destinationColumn else { return }
                DispatchQueue.main.async {
                    if session.moveRun(from: source.column, cardIndex: source.index, to: destinationColumn) {
                        selected = nil
                    }
                    dropTargetColumn = nil
                }
            }
        }

        return true
    }

    private static func stringPayload(from item: NSSecureCoding) -> String? {
        switch item {
        case let text as String:
            return text
        case let text as NSString:
            return text as String
        case let data as Data:
            return String(data: data, encoding: .utf8)
        default:
            return nil
        }
    }

    private var dealDisabled: Bool {
        session.game.stockRows.isEmpty || session.game.tableau.contains(where: \.isEmpty)
    }

    // MARK: - Table rail

    private var feltRail: some View {
        HStack(spacing: 12) {
            dealControl
            Spacer(minLength: 8)
            setsTray
            Spacer(minLength: 8)
            newDealChip
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpiderTheme.feltRail)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(SpiderTheme.goldLine, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 10, y: 5)
        )
    }

    private var dealControl: some View {
        Button {
            if session.dealRow() {
                selected = nil
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if session.game.stockRows.isEmpty {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.3), lineWidth: 1)
                            .frame(width: 24, height: 34)
                    } else {
                        ForEach(0..<session.game.stockRows.count, id: \.self) { index in
                            SpiderCardBackView(width: 24, height: 34, ornate: index == session.game.stockRows.count - 1)
                                .offset(x: CGFloat(index) * 2.5, y: CGFloat(index) * -1.5)
                        }
                    }
                }
                .frame(width: 36, height: 42, alignment: .bottomLeading)

                Text("DEAL · \(session.game.stockRows.count)")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .monospacedDigit()
                    .foregroundStyle(SpiderTheme.ivory.opacity(0.9))
            }
            .opacity(dealDisabled ? 0.35 : 1)
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(dealDisabled)
        .accessibilityLabel("Deal a row")
        .accessibilityValue("\(session.game.stockRows.count) deals remaining")
    }

    private var setsTray: some View {
        HStack(spacing: 3) {
            ForEach(0..<8, id: \.self) { index in
                traySlot(index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completed runs")
        .accessibilityValue("\(session.completedSets) of 8")
    }

    private func traySlot(_ index: Int) -> some View {
        let filled = index < session.completedSets
        let isNewest = filled && index == session.completedSets - 1

        return ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(filled
                      ? AnyShapeStyle(LinearGradient(colors: [SpiderTheme.ivory, SpiderTheme.ivoryLo],
                                                     startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(SpiderTheme.feltLo.opacity(0.6)))
            if filled {
                VStack(spacing: -2) {
                    Text("K")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                    Text("♠")
                        .font(.system(size: 8))
                }
                .foregroundStyle(SpiderTheme.inkBlack)
            }
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(filled ? PrismetDesign.gold.opacity(0.55) : Color.black.opacity(0.3), lineWidth: 1)
        }
        .frame(width: 16, height: 23)
        .scaleEffect(isNewest && trayPulse ? 1.3 : 1)
        .shadow(color: isNewest && trayPulse ? PrismetDesign.gold.opacity(0.8) : .clear, radius: 6)
    }

    private var newDealChip: some View {
        Button {
            newGame()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                Text("NEW")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.8)
            }
            .foregroundStyle(SpiderTheme.ivory.opacity(0.9))
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New deal")
    }

    // MARK: - Interaction

    private func handleCardTap(column: Int, index: Int) {
        let source = SpiderSelection.card(column: column, index: index)
        let cards = session.game.tableau[column]
        guard cards.indices.contains(index) else { return }

        if let selected {
            if selected == source {
                self.selected = nil
            } else if session.moveRun(from: selected.column, cardIndex: selected.index, to: column) {
                self.selected = nil
            } else if cards[index].isFaceUp {
                self.selected = source
            }
        } else if cards[index].isFaceUp {
            selected = source
        }
    }

    private func moveSelection(to column: Int) {
        guard let selected,
              session.moveRun(from: selected.column, cardIndex: selected.index, to: column)
        else {
            return
        }
        self.selected = nil
    }

    private func runCompletedSweep() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { trayPulse = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            withAnimation(.easeOut(duration: 0.3)) { trayPulse = false }
        }
        guard !reduceMotion else { return }
        sweepFly = false
        withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { sweepVisible = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation(.easeIn(duration: 0.45)) { sweepFly = true }
            try? await Task.sleep(nanoseconds: 500_000_000)
            sweepVisible = false
            sweepFly = false
        }
    }

    private var sweepOverlay: some View {
        if sweepVisible {
            return AnyView(
                SpiderCardFaceView(card: Card(rank: .king, suit: .spades), width: 58, height: 82)
                    .shadow(color: PrismetDesign.gold.opacity(0.65), radius: 14)
                    .scaleEffect(sweepFly ? 0.28 : 1.08)
                    .offset(y: sweepFly ? 260 : 0)
                    .opacity(sweepFly ? 0 : 1)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            )
        }
        return AnyView(EmptyView())
    }

    private func cardView(_ card: SpiderCard,
                          width: CGFloat,
                          height: CGFloat,
                          isSelectedRun: Bool,
                          isTop: Bool) -> some View {
        Group {
            if card.isFaceUp {
                SpiderCardFaceView(card: card.card, width: width, height: height,
                                   selected: isSelectedRun)
            } else {
                SpiderCardBackView(width: width, height: height, ornate: isTop)
            }
        }
        .shadow(color: Color.black.opacity(isTop || isSelectedRun ? 0.25 : 0),
                radius: isSelectedRun ? 5 : 1.5,
                y: isSelectedRun ? 3 : 1)
    }

    private func emptySlot(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(SpiderTheme.feltLo.opacity(0.55))
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.black.opacity(0.25), lineWidth: 1)
            Image(systemName: "suit.spade")
                .font(.system(size: min(width * 0.42, 18)))
                .foregroundStyle(Color.white.opacity(0.12))
        }
        .frame(width: width, height: height)
    }

    private func newGame() {
        showWin = false
        session.newGame()
        selected = nil
    }
}

// MARK: - Card face (shared Solitaire language)

private struct SpiderCardFaceView: View {
    let card: Card
    let width: CGFloat
    let height: CGFloat
    var selected: Bool = false

    private var pipColor: Color { card.isRed ? SpiderTheme.inkRed : SpiderTheme.inkBlack }
    private var corner: CGFloat { min(8, max(3.5, width * 0.13)) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(colors: [SpiderTheme.ivory, SpiderTheme.ivoryLo],
                                   startPoint: .top, endPoint: .bottom)
                )
            if width >= 44 {
                fullFace
            } else {
                compactFace
            }
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(selected ? PrismetDesign.gold : SpiderTheme.cardEdge, lineWidth: selected ? 2 : 1)
        }
        .frame(width: width, height: height)
    }

    private var compactFace: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0.5) {
                Text(card.rank.shortLabel)
                Text(card.suit.symbol)
            }
            .font(.system(size: max(7.5, width * 0.30), weight: .heavy, design: .rounded))
            .foregroundStyle(pipColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.leading, max(2, width * 0.09))
            .padding(.top, max(1.5, width * 0.05))

            VStack(spacing: 0) {
                Text(card.rank.shortLabel)
                    .font(.system(size: min(width * 0.42, 18), weight: .heavy, design: .serif))
                Text(card.suit.symbol)
                    .font(.system(size: min(width * 0.38, 16)))
            }
            .foregroundStyle(pipColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var fullFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(2, corner * 0.6), style: .continuous)
                .strokeBorder(SpiderTheme.cardEdge.opacity(0.35), lineWidth: 0.8)
                .padding(3)

            cornerIndex
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(width * 0.08)
            cornerIndex
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(width * 0.08)

            centerContent
                .padding(.horizontal, width * 0.22)
                .padding(.vertical, height * 0.18)
        }
    }

    private var cornerIndex: some View {
        VStack(spacing: -1) {
            Text(card.rank.shortLabel)
                .font(.system(size: width * 0.17, weight: .bold, design: .serif))
            Text(card.suit.symbol)
                .font(.system(size: width * 0.15))
        }
        .foregroundStyle(pipColor)
    }

    @ViewBuilder
    private var centerContent: some View {
        switch card.rank {
        case .ace:
            Text(card.suit.symbol)
                .font(.system(size: width * 0.42))
                .foregroundStyle(pipColor)
        case .jack, .queen, .king:
            courtMedallion
        default:
            pipGrid
        }
    }

    private var courtMedallion: some View {
        ZStack {
            Circle()
                .strokeBorder(PrismetDesign.gold.opacity(0.75), lineWidth: 1.2)
            Circle()
                .strokeBorder(pipColor.opacity(0.25), lineWidth: 0.8)
                .padding(3)
            VStack(spacing: -2) {
                Text(card.rank.shortLabel)
                    .font(.system(size: width * 0.26, weight: .bold, design: .serif))
                Text(card.suit.symbol)
                    .font(.system(size: width * 0.14))
            }
            .foregroundStyle(pipColor)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var pipGrid: some View {
        GeometryReader { geometry in
            let points = Self.pipLayout[card.rank.rawValue] ?? []
            ForEach(0..<points.count, id: \.self) { index in
                Text(card.suit.symbol)
                    .font(.system(size: width * 0.17))
                    .foregroundStyle(pipColor)
                    .rotationEffect(.degrees(points[index].y > 0.5 ? 180 : 0))
                    .position(x: geometry.size.width * points[index].x,
                              y: geometry.size.height * points[index].y)
            }
        }
    }

    private static let pipLayout: [Int: [CGPoint]] = [
        2: [CGPoint(x: 0.5, y: 0.12), CGPoint(x: 0.5, y: 0.88)],
        3: [CGPoint(x: 0.5, y: 0.12), CGPoint(x: 0.5, y: 0.50), CGPoint(x: 0.5, y: 0.88)],
        4: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12),
            CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)],
        5: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12), CGPoint(x: 0.5, y: 0.50),
            CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)],
        6: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12),
            CGPoint(x: 0.26, y: 0.50), CGPoint(x: 0.74, y: 0.50),
            CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)],
        7: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12), CGPoint(x: 0.5, y: 0.31),
            CGPoint(x: 0.26, y: 0.50), CGPoint(x: 0.74, y: 0.50),
            CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)],
        8: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12), CGPoint(x: 0.5, y: 0.31),
            CGPoint(x: 0.26, y: 0.50), CGPoint(x: 0.74, y: 0.50), CGPoint(x: 0.5, y: 0.69),
            CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)],
        9: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12),
            CGPoint(x: 0.26, y: 0.375), CGPoint(x: 0.74, y: 0.375), CGPoint(x: 0.5, y: 0.50),
            CGPoint(x: 0.26, y: 0.625), CGPoint(x: 0.74, y: 0.625),
            CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)],
        10: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12), CGPoint(x: 0.5, y: 0.245),
             CGPoint(x: 0.26, y: 0.375), CGPoint(x: 0.74, y: 0.375),
             CGPoint(x: 0.26, y: 0.625), CGPoint(x: 0.74, y: 0.625), CGPoint(x: 0.5, y: 0.755),
             CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)]
    ]
}

// MARK: - Card back (kaleidoscope rosette in an ivory margin frame)

private struct SpiderCardBackView: View {
    let width: CGFloat
    let height: CGFloat
    var ornate: Bool = true

    private var corner: CGFloat { min(8, max(3.5, width * 0.13)) }
    private var inset: CGFloat { max(1.5, width * 0.07) }
    private var rosetteSize: CGFloat { min(width, height) * 0.72 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(SpiderTheme.ivory)
            RoundedRectangle(cornerRadius: max(2, corner - 2), style: .continuous)
                .fill(SpiderTheme.backGround)
                .padding(inset)
            if ornate {
                rosette
            }
            RoundedRectangle(cornerRadius: max(2, corner - 2), style: .continuous)
                .strokeBorder(PrismetDesign.gold.opacity(0.35), lineWidth: 0.8)
                .padding(inset)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(SpiderTheme.cardEdge, lineWidth: 1)
        }
        .frame(width: width, height: height)
    }

    private var rosette: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Ellipse()
                    .fill(PrismetDesign.wheel[index % PrismetDesign.wheel.count].opacity(0.85))
                    .frame(width: rosetteSize * 0.18, height: rosetteSize * 0.52)
                    .offset(y: -rosetteSize * 0.26)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
            Circle()
                .fill(PrismetDesign.gold)
                .frame(width: rosetteSize * 0.16, height: rosetteSize * 0.16)
        }
        .frame(width: rosetteSize, height: rosetteSize)
    }
}

// MARK: - Win banner

private struct SpiderWinBanner: View {
    let moves: Int
    let onNewDeal: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                SpiderCardFaceView(card: Card(rank: .king, suit: .spades), width: 64, height: 90)
                    .shadow(color: PrismetDesign.gold.opacity(0.6), radius: 12)

                Text("Table Cleared")
                    .font(PrismetDesign.title(30))
                    .foregroundStyle(.white)

                Text("All eight runs in \(moves) moves")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.85))

                Button(action: onNewDeal) {
                    Text("New Deal")
                        .font(.headline)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(PrismetDesign.gold.gradient))
                        .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.04))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityLabel("New deal")
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(colors: [SpiderTheme.felt, SpiderTheme.feltLo],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(PrismetDesign.gold.opacity(0.7), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 22, y: 10)
            )
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { appeared = true }
            }
        }
    }
}

#Preview {
    NavigationStack { SpiderView() }
}
