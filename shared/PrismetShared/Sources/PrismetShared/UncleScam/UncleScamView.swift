import SwiftUI
import ImageIO

// Uncle Scam: the lens itself, one screen for both apps. A salary, a ZIP code and a filing status in; an itemized
// receipt out, then who signs off on it and what landed nearby. Words and figures are the website's
// (`UncleScam.receiptRows`); the arithmetic runs on the device.

@MainActor
final class UncleScamModel: ObservableObject {
    enum Awards: Equatable { case idle, loading, loaded(UncleScamLocalAwards), failed }

    @Published var salaryText = ""
    @Published var zip = ""
    @Published var status: UncleScamFilingStatus = .single
    @Published var pickedState = ""
    @Published var needsState = false
    @Published var salaryError = ""
    @Published var zipError = ""
    @Published var loading = true
    @Published var loadFailed = false
    @Published var live = false
    @Published var bill: UncleScamBill?
    @Published var percentOnly = false
    @Published var senators: [UncleScamCongress.Member] = []
    @Published var seats: [UncleScamSeat] = []
    @Published var awards: Awards = .idle
    @Published private(set) var printedZip = ""

    private(set) var tax: UncleScamTaxData?
    private(set) var statement: UncleScamStatement?
    private var congress: UncleScamCongress?
    private(set) var debtNow: UncleScamCongress.Debt?
    private var entry: UncleScamZipEntry?
    private let service = UncleScamService()

    var states: [(code: String, name: String)] {
        (tax?.state.states ?? [:]).map { ($0.key, $0.value.name) }.sorted { $0.1 < $1.1 }
    }

    func start() async {
        guard tax == nil else { return }
        loading = true
        async let taxData = service.taxData()
        async let picked = service.statement()
        tax = await taxData
        if let picked = await picked { statement = picked.statement; live = picked.live }
        loadFailed = tax == nil || statement == nil
        loading = false
        if let now = await service.debtNow() { debtNow = now }
    }

    func rows(percent: Bool) -> [UncleScamRow] {
        guard let bill, let statement, let tax else { return [] }
        return UncleScam.receiptRows(bill: bill, statement: statement, data: tax, percent: percent)
    }

    func stateName(_ code: String) -> String { tax?.state.states[code]?.name ?? code }

    func print() {
        guard let tax, statement != nil else { return }
        salaryError = ""; zipError = ""
        guard let wages = UncleScamFormat.parseSalary(salaryText), wages >= 1, wages <= 1e9 else {
            salaryError = "Enter a yearly salary, like 65,000."; return
        }
        let z = zip.trimmingCharacters(in: .whitespaces)
        guard z.count == 5, z.allSatisfy({ $0.isASCII && $0.isNumber }) else { zipError = "Enter a five-digit ZIP code."; return }
        let place = UncleScam.place(forZip: z, data: tax)
        if let place, place.territory {
            zipError = "\(tax.state.territories[place.code] ?? place.code) files under different rules. Uncle Scam covers the 50 states and DC for now."
            return
        }
        var code = place?.code ?? ""
        if code.isEmpty {
            needsState = true
            code = pickedState
            if code.isEmpty { zipError = "That ZIP code is not in the Census list. Pick your state below."; return }
        } else { needsState = false }
        bill = UncleScam.computeBill(wages: wages, status: status, stateCode: code, data: tax)
        printedZip = place == nil ? "" : z
        awards = .idle; senators = []; seats = []; entry = nil
        let zipForLookup = printedZip
        Task { await loadOfficials(zip: zipForLookup, stateCode: code) }
    }

    private func loadOfficials(zip: String, stateCode: String) async {
        if congress == nil { congress = await service.congress() }
        guard let congress else { return }
        if debtNow == nil { debtNow = congress.debtNow }
        let found = zip.isEmpty ? nil : await service.zipEntry(zip)
        guard zip == printedZip else { return }
        entry = found
        let o = UncleScam.officials(entry: found, stateCode: stateCode, congress: congress)
        senators = o.senators; seats = o.seats
    }

    func lookUp() async {
        let zip = printedZip
        guard !zip.isEmpty else { return }
        awards = .loading
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        do {
            let found = try await service.localAwards(zip: zip, countyFIPS: entry?.c, today: String(today))
            if zip == printedZip { awards = .loaded(found) }
        } catch { if zip == printedZip { awards = .failed } }
    }
}

public struct UncleScamView: View {
    @StateObject private var model = UncleScamModel()
    @State private var shareImage: Image?

    static let paper = Color(red: 0.957, green: 0.941, blue: 0.894)
    static let paperInk = Color(red: 0.106, green: 0.114, blue: 0.129)
    static let paperDim = Color(red: 0.353, green: 0.365, blue: 0.388)
    static let stamp = Color(red: 0.702, green: 0.149, blue: 0.118)

    private let ground: Color?

    /// `ground`: the host app's page colour, so the lens sits on the same ground as the rest of the app.
    public init(ground: Color? = nil) { self.ground = ground }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                form
                if model.loading { Text("Loading the tax tables…").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
                if model.loadFailed { Text("The tax tables did not load. Check the connection and open this lens again.").font(.footnote).foregroundStyle(.secondary) }
                if model.bill != nil {
                    receipt(percent: model.percentOnly).frame(maxWidth: 420).frame(maxWidth: .infinity)
                    actions
                    if !model.live { Text("Budget figures are a saved Treasury statement; the live one did not load.").font(.footnote).foregroundStyle(.secondary) }
                    officials
                    local
                }
                finePrint
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background((ground ?? Color.clear).ignoresSafeArea())
        .navigationTitle("Uncle Scam")
        .uncleScamInlineTitle(ground: ground)
        .task { await model.start() }
    }

    // MARK: Header and form

    private var header: some View {
        VStack(spacing: 8) {
            if let seal = Self.seal {
                seal.resizable().interpolation(.high).frame(width: 132, height: 132)
                    .accessibilityLabel("The Uncle Scam seal: an eagle in a star-banded top hat gripping a wallet and a long receipt.")
            }
            Text("Uncle Scam").font(.system(.largeTitle, design: .serif).weight(.bold))
            Text("Where is my money going?").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text("Type a salary and a ZIP code. Get the receipt nobody hands you: what you paid, what it bought, and what got put on the card.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Salary, before taxes", error: model.salaryError) {
                TextField("65,000", text: $model.salaryText).uncleScamNumberField(decimal: true)
            }
            field("ZIP code", error: model.zipError) {
                TextField("43201", text: $model.zip).uncleScamNumberField(decimal: false)
                    .onChange(of: model.zip) { _, new in
                        if new.count > 5 { model.zip = String(new.prefix(5)) }
                        model.needsState = false; model.pickedState = ""
                    }
            }
            if model.needsState {
                Picker("State", selection: $model.pickedState) {
                    Text("Pick a state").tag("")
                    ForEach(model.states, id: \.code) { Text($0.name).tag($0.code) }
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Filing status").font(.footnote).foregroundStyle(.secondary)
                // three plain choices that wrap, so "Head of household" is never cut short
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { statusChoices }
                    VStack(spacing: 8) { statusChoices }
                }
            }
            Button { model.print() } label: { Text("Print my receipt").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(model.loading || model.loadFailed)
            Text("Your salary never leaves this device. Your ZIP code only picks public data files.")
                .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var statusChoices: some View {
        ForEach(UncleScamFilingStatus.allCases, id: \.self) { status in
            let chosen = model.status == status
            Button { model.status = status } label: {
                Text(status.label).font(.callout).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8).fill(chosen ? Color.accentColor.opacity(0.22) : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(chosen ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(chosen ? .isSelected : [])
        }
    }

    private func field<Content: View>(_ label: String, error: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.footnote).foregroundStyle(.secondary)
            content().textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
            if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(.red) }
        }
    }

    // MARK: Receipt

    func receipt(percent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(model.rows(percent: percent).enumerated()), id: \.offset) { _, row in rowView(row) }
        }
        .font(.system(size: 12.5, design: .monospaced))
        .foregroundStyle(Self.paperInk)
        .padding(.horizontal, 20).padding(.vertical, 26)
        .background(Self.paper)
        .clipShape(TornEdge())
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func rowView(_ row: UncleScamRow) -> some View {
        let ink = row.style == "red" ? Self.stamp : Self.paperInk
        switch row.kind {
        case .rule:
            Line().stroke(Self.paperInk.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4, 3])).frame(height: 1).padding(.vertical, 7)
        case .barcode:
            Barcode().fill(Self.paperInk).frame(height: 36).padding(.horizontal, 38).padding(.top, 8).accessibilityHidden(true)
        case .row, .total:
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(row.text)
                Spacer(minLength: 8)
                Text(row.value).monospacedDigit().lineLimit(1).layoutPriority(1)
            }
            .fontWeight(row.kind == .total ? .heavy : row.style == "red" ? .bold : .regular)
            .font(.system(size: row.kind == .total ? 15 : 12.5, design: .monospaced))
            .foregroundStyle(ink)
            .padding(.top, row.kind == .total ? 6 : 0)
            .overlay(alignment: .top) { if row.kind == .total { Rectangle().fill(Self.paperInk).frame(height: 2) } }
            .accessibilityElement(children: .combine)
        case .stamp:
            Text(row.text).fontWeight(.heavy).kerning(1.5).foregroundStyle(Self.stamp)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .overlay(Rectangle().stroke(Self.stamp, lineWidth: 2))
                .rotationEffect(.degrees(-4)).frame(maxWidth: .infinity).padding(.vertical, 6)
        case .head:
            Text(row.text).fontWeight(.bold).kerning(1).foregroundStyle(ink).padding(.top, 2).accessibilityAddTraits(.isHeader)
        case .note:
            Text(row.text).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Self.paperDim).padding(.top, 4)
        case .center:
            Text(row.text)
                .font(row.style == "title" ? .system(size: 21, weight: .heavy, design: .serif) : .system(size: row.style == "small" ? 10.5 : 12.5, design: .monospaced))
                .foregroundStyle(row.style == "small" ? Self.paperDim : Self.paperInk)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Toggle("Percent only (hide the dollar amounts)", isOn: $model.percentOnly).font(.callout)
            if let image = shareImage {
                ShareLink(item: image, preview: SharePreview("Uncle Scam receipt", image: image)) {
                    Label("Share the receipt", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: 420).frame(maxWidth: .infinity)
        // drawn once per receipt, not on every keystroke
        .task(id: "\(model.bill?.hashValue ?? 0)-\(model.percentOnly)") { shareImage = receiptImage }
    }

    /// The receipt as a picture, for sharing: exactly what is on screen, percent-only when that is switched on.
    private var receiptImage: Image? {
        let renderer = ImageRenderer(content: receipt(percent: model.percentOnly).frame(width: 380))
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return nil }
        return Image(decorative: cg, scale: 2)
    }

    // MARK: Who signs off

    @ViewBuilder
    private var officials: some View {
        if !model.seats.isEmpty || !model.senators.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Divider()
                Text("Who signs off on it").font(.system(.title3, design: .serif).weight(.bold)).accessibilityAddTraits(.isHeader)
                if model.seats.count > 1 {
                    Text("ZIP code \(model.printedZip) crosses a district line, so one of these \(model.seats.count) representatives is yours; [house.gov can tell you which](https://www.house.gov/representatives/find-your-representative).")
                        .font(.callout).foregroundStyle(.secondary)
                } else if model.seats.isEmpty {
                    Text("Without a ZIP code in the Census list only your senators can be named.").font(.callout).foregroundStyle(.secondary)
                } else if model.senators.isEmpty {
                    Text("The District has a delegate in the House and no senators.").font(.callout).foregroundStyle(.secondary)
                }
                ForEach(Array(model.seats.enumerated()), id: \.offset) { _, seat in
                    let role = seat.state == "DC" ? "Delegate, District of Columbia"
                        : "U.S. Representative, \(model.stateName(seat.state))" + (seat.district > 0 ? " district \(seat.district)" : ", at large")
                    if let member = seat.member { person(member, role: role) } else { Text("\(role): this seat is vacant.").font(.callout) }
                }
                ForEach(model.senators) { person($0, role: "U.S. Senator, \(model.stateName($0.s))") }
                Text("Congress writes the budget and the tax code; these are the members who vote for your address. The debt figures are the Treasury's, for the day each member first took office and for today. They show what happened on each watch, not who voted for what.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func person(_ m: UncleScamCongress.Member, role: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let url = m.url.flatMap(URL.init(string:)) { Link(m.n, destination: url).font(.headline) } else { Text(m.n).font(.headline) }
            Text("\(role) · \(m.p)").font(.subheadline).foregroundStyle(.secondary)
            Text("In Congress since \(UncleScamFormat.day(m.since)). Current term ends \(UncleScamFormat.day(m.end)).").font(.footnote).foregroundStyle(.secondary)
            if let d = UncleScam.debtSince(m, now: model.debtNow) {
                let then = d.yearEnd ? "at the end of fiscal \(d.thenDate.prefix(4)), before they arrived" : "that day"
                Text("National debt \(then): \(UncleScamFormat.big(d.then)). Today: \(UncleScamFormat.big(d.now)). \(UncleScamFormat.big(d.added)) added.").font(.callout)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: What landed near you

    @ViewBuilder
    private var local: some View {
        if !model.printedZip.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Divider()
                Text("What landed near you").font(.system(.title3, design: .serif).weight(.bold)).accessibilityAddTraits(.isHeader)
                Text("Federal contracts, grants, loans and direct payments recorded with work in your ZIP code and county.").font(.callout).foregroundStyle(.secondary)
                switch model.awards {
                case .idle, .failed:
                    Button("Look up \(model.printedZip)") { Task { await model.lookUp() } }.buttonStyle(.bordered)
                    Text("This sends your ZIP code, not your salary, to USAspending.gov, the Treasury's public spending site.").font(.footnote).foregroundStyle(.secondary)
                    if model.awards == .failed { Text("USAspending.gov did not answer. Try again in a moment.").font(.footnote).foregroundStyle(.secondary) }
                case .loading:
                    ProgressView("Asking USAspending.gov…")
                case .loaded(let found):
                    awards(found)
                }
            }
        }
    }

    @ViewBuilder
    private func awards(_ found: UncleScamLocalAwards) -> some View {
        if let total = found.countyTotal, total > 0, let county = found.countyName, let bill = model.bill {
            let perHead = (found.countyPerCapita ?? 0) > 0 ? ", \(UncleScamFormat.usd(found.countyPerCapita ?? 0)) for each resident" : ""
            Text("\(UncleScamFormat.big(total)) in federal awards went to \(county) in fiscal \(String(found.fiscalYear))\(perHead). Your federal bill was \(UncleScamFormat.usd(bill.federalTotal)).")
        }
        if found.recipients.isEmpty {
            Text("No awards are recorded with work in \(model.printedZip) for fiscal \(String(found.fiscalYear)).").font(.callout)
        } else {
            Text("Largest recipients with work in \(model.printedZip)").font(.subheadline.weight(.semibold))
            ForEach(Array(found.recipients.enumerated()), id: \.offset) { i, r in
                HStack(alignment: .firstTextBaseline) {
                    Text("\(i + 1). \(r.name)")
                    Spacer(minLength: 8)
                    Text(UncleScamFormat.big(r.amount)).font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        Text("Source: [USAspending.gov](https://www.usaspending.gov/search), awards by place of performance, October \(String(found.fiscalYear - 1)) through September \(String(found.fiscalYear)). Amounts are obligations: money committed, not always paid out yet.")
            .font(.footnote).foregroundStyle(.secondary)
    }

    // MARK: Fine print

    private var finePrint: some View {
        DisclosureGroup("How this is worked out") {
            VStack(alignment: .leading, spacing: 8) {
                Text("An estimate for tax year \(String(model.tax?.federal.year ?? 2026)), not tax advice. It assumes wages from one job are your only income, the standard deduction, no dependents and no credits. Married, joint treats the salary as the household's wages.")
                Text("State tax uses each state's published brackets, standard deduction and personal exemption. Head of household uses the single schedule. City, county and school district income taxes are not included, nor are sales, property or gas taxes.")
                Text("Where it went: your federal income tax is spread across the budget in proportion to what Washington has spent this fiscal year. Social Security and Medicare are left out of that split because your payroll taxes are listed for them on their own lines; in truth Medicare also draws on income taxes.")
                Text("Put on the card: what Washington spent beyond what it collected, scaled to your federal bill.")
                Text("Time served counts every day of the year and an eight-hour workday; a paycheck is one of 26.")
                if let tax = model.tax {
                    let sources = tax.federal.sources + [tax.state.source]
                    Text("Sources: " + sources.map(\.name).joined(separator: "; ") + "; U.S. Census Bureau; U.S. Treasury, Monthly Treasury Statement.")
                }
                Text("A parody. Not affiliated with the IRS, the Treasury or any government.")
            }
            .font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
        }
        .font(.callout)
    }

    static let seal: Image? = {
        guard let data = UncleScamBundled.sealPNG(), let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return Image(decorative: cg, scale: 2)
    }()
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: 0, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return p }
}

private struct Barcode: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(), x = rect.minX, i = 0
        let widths: [CGFloat] = [2, 1, 3, 1, 2, 3, 1, 1]
        while x < rect.maxX {
            let w = widths[i % widths.count]
            if i % 2 == 0 { p.addRect(CGRect(x: x, y: rect.minY, width: w, height: rect.height)) }
            x += w + (i % 3 == 0 ? 2 : 1); i += 1
        }
        return p
    }
}

/// The receipt's torn top and bottom.
private struct TornEdge: Shape {
    func path(in rect: CGRect) -> Path {
        let tooth: CGFloat = 8, count = max(8, Int(rect.width / 14)), step = rect.width / CGFloat(count)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + tooth))
        for i in 0..<count {
            p.addLine(to: CGPoint(x: rect.minX + (CGFloat(i) + 0.5) * step, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX + CGFloat(i + 1) * step, y: rect.minY + tooth))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tooth))
        for i in (0..<count).reversed() {
            p.addLine(to: CGPoint(x: rect.minX + (CGFloat(i) + 0.5) * step, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + CGFloat(i) * step, y: rect.maxY - tooth))
        }
        p.closeSubpath()
        return p
    }
}

private extension View {
    /// A small title on an opaque bar in the app's own ground colour, so the receipt never scrolls up under it.
    @ViewBuilder func uncleScamInlineTitle(ground: Color?) -> some View {
        #if os(iOS)
        if let ground {
            self.navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(ground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        } else {
            self.navigationBarTitleDisplayMode(.inline)
        }
        #else
        self
        #endif
    }

    @ViewBuilder func uncleScamNumberField(decimal: Bool) -> some View {
        #if os(iOS)
        self.keyboardType(decimal ? .decimalPad : .numberPad).autocorrectionDisabled()
        #else
        self.autocorrectionDisabled()
        #endif
    }
}
