import SwiftUI

struct HomeLensView: View {
    let facets: [FacetDescriptor]
    var onSelect: (FacetDescriptor) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 158, maximum: 220), spacing: 16, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header
                ForEach(FacetCategory.allCases) { category in
                    let categoryFacets = facets.filter { $0.category == category }
                    if !categoryFacets.isEmpty {
                        categorySection(category, facets: categoryFacets)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(homeBackground)
    }

    private var homeBackground: some View {
        ZStack {
            PrismetDesign.ground
            Circle()
                .fill(AngularGradient(gradient: Gradient(colors: PrismetDesign.wheel), center: .center))
                .frame(width: 640, height: 640)
                .blur(radius: 140)
                .opacity(0.30)
                .offset(x: -140, y: -240)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().strokeBorder(
                    AngularGradient(gradient: Gradient(colors: PrismetDesign.wheel), center: .center),
                    lineWidth: 4)
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(AngularGradient(gradient: Gradient(colors: PrismetDesign.wheel), center: .center))
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 3) {
                Text("Prismet")
                    .font(PrismetDesign.title(42))
                    .foregroundStyle(PrismetDesign.ink)
                Text("turn the lens.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(PrismetDesign.ink2)
            }
            Spacer()
        }
    }

    private func categorySection(_ category: FacetCategory, facets: [FacetDescriptor]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.rawValue.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(PrismetDesign.ink3)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(facets) { facet in
                    FacetTile(facet: facet) { onSelect(facet) }
                }
            }
        }
    }
}

private struct FacetTile: View {
    let facet: FacetDescriptor
    var onSelect: () -> Void
    @State private var hover = false

    private var ready: Bool { facet.status == .ready }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    if let tile = facet.tileImage, ready {
                        Image(tile)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        AngularGradient(gradient: Gradient(colors: irisColors(facet.accent)), center: .center),
                                        lineWidth: 2)
                            )
                    } else {
                        Circle().fill(facet.accent.opacity(ready ? 0.20 : 0.08))
                        Circle().strokeBorder(
                            AngularGradient(gradient: Gradient(colors: irisColors(facet.accent)), center: .center),
                            lineWidth: ready ? 2 : 1)
                            .opacity(ready ? 1 : 0.35)
                        Image(systemName: facet.systemImage)
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(ready ? facet.accent : PrismetDesign.ink3)
                    }
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 3) {
                    Text(facet.title)
                        .font(PrismetDesign.rounded(17))
                        .foregroundStyle(ready ? PrismetDesign.ink : PrismetDesign.ink2)
                    Text(ready ? facet.category.rawValue : "Coming soon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PrismetDesign.ink3)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(16)
            .background(tileBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(ready ? facet.accent.opacity(hover ? 0.65 : 0.28) : PrismetDesign.hairline,
                                  lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: ready ? facet.accent.opacity(hover ? 0.38 : 0.0) : .clear, radius: 18, y: 8)
            .scaleEffect(hover && ready ? 1.025 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!ready)
        .opacity(ready ? 1 : 0.6)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.16), value: hover)
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(PrismetDesign.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [facet.accent.opacity(ready ? 0.16 : 0.0), .clear],
                                         startPoint: .top, endPoint: .bottom))
            )
    }
}
