import SwiftUI

/// Parts laid out as the parts themselves: rim sections, hub flanges, spokes.
/// Each tile is the silhouette of the thing plus the one number it is chosen on.
struct ComponentBenchView: View {
    let container: SpokeContainer

    @State private var parts: [SpokeComponent] = []

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(parts) { part in
                    tile(part)
                }
            }
            .padding(20)
        }
        .rimBackdrop()
        .navigationTitle("Component bench")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    private func tile(_ part: SpokeComponent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ComponentSilhouette(part: part)
                .frame(height: 76)
            Text(part.name)
                .font(RimFace.label(13))
                .foregroundStyle(AnodisedInk.readable)
                .lineLimit(1)
            Text(headline(part))
                .font(RimFace.gauge(12))
                .foregroundStyle(AnodisedInk.driveTeal)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RimRadius.tile, style: .continuous)
                .strokeBorder(AnodisedInk.rimHairline, lineWidth: 1)
        )
        .contextMenu {
            Button("Remove from bench", role: .destructive) {
                Task {
                    try? await container.componentRepository.delete(id: part.id)
                    await reload()
                }
            }
        }
    }

    private func headline(_ part: SpokeComponent) -> String {
        if let erd = part.erdMm { return String(format: "ERD %.0f mm", erd) }
        if let flange = part.flangeMm {
            let offset = part.offsetMm.map { String(format: " · %.0f mm offset", $0) } ?? ""
            return String(format: "Flange %.0f mm", flange) + offset
        }
        if !part.gauge.isEmpty { return "\(part.gauge) mm gauge" }
        return part.kind.capitalized
    }

    private func reload() async {
        parts = (try? await container.componentRepository.fetchAll()) ?? []
    }
}

/// Draws the part rather than listing it: rims as a rim section, hubs as two
/// flanges on an axle, spokes as a J-bend and nipple.
private struct ComponentSilhouette: View {
    let part: SpokeComponent

    var body: some View {
        Canvas { context, size in
            switch part.kind.lowercased() {
            case "rim": drawRim(&context, size: size)
            case "hub": drawHub(&context, size: size)
            default: drawSpoke(&context, size: size)
            }
        }
    }

    private func drawRim(_ context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 1.45)
        let outer = Double(size.height) * 1.3
        for (index, inset) in [0.0, 9.0, 13.0].enumerated() {
            var arc = Path()
            arc.addArc(
                center: center,
                radius: CGFloat(outer - inset),
                startAngle: .degrees(212),
                endAngle: .degrees(328),
                clockwise: false
            )
            context.stroke(
                arc,
                with: .color(index == 1 ? AnodisedInk.driveTeal : AnodisedInk.hubRing),
                style: StrokeStyle(lineWidth: index == 1 ? 2 : 1.4)
            )
        }
        var seats = Path()
        for step in 0...6 {
            let angle = Double.pi + Double.pi * (0.18 + 0.107 * Double(step))
            let seat = CGPoint(
                x: center.x + CGFloat(cos(angle) * (outer - 11)),
                y: center.y + CGFloat(sin(angle) * (outer - 11))
            )
            seats.addEllipse(in: CGRect(x: seat.x - 1.6, y: seat.y - 1.6, width: 3.2, height: 3.2))
        }
        context.fill(seats, with: .color(AnodisedInk.rimGold))
    }

    private func drawHub(_ context: inout GraphicsContext, size: CGSize) {
        let midY = size.height / 2
        var axle = Path()
        axle.move(to: CGPoint(x: 8, y: midY))
        axle.addLine(to: CGPoint(x: size.width - 8, y: midY))
        context.stroke(axle, with: .color(AnodisedInk.hubRing), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        var shell = Path()
        shell.addRoundedRect(
            in: CGRect(x: size.width * 0.28, y: midY - 9, width: size.width * 0.44, height: 18),
            cornerSize: CGSize(width: 3, height: 3)
        )
        context.stroke(shell, with: .color(AnodisedInk.readable.opacity(0.4)), style: StrokeStyle(lineWidth: 1.2))

        for fraction in [0.28, 0.72] {
            var flange = Path()
            let x = size.width * CGFloat(fraction)
            flange.move(to: CGPoint(x: x, y: midY - 26))
            flange.addLine(to: CGPoint(x: x, y: midY + 26))
            context.stroke(
                flange,
                with: .color(fraction < 0.5 ? AnodisedInk.nonDriveTeal : AnodisedInk.driveTeal),
                style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
            )
        }
    }

    private func drawSpoke(_ context: inout GraphicsContext, size: CGSize) {
        let midY = size.height / 2
        var shaft = Path()
        shaft.move(to: CGPoint(x: 14, y: midY + 10))
        shaft.addQuadCurve(to: CGPoint(x: 26, y: midY), control: CGPoint(x: 14, y: midY))
        shaft.addLine(to: CGPoint(x: size.width - 22, y: midY))
        context.stroke(
            shaft,
            with: .color(AnodisedInk.driveTeal),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )

        var nipple = Path()
        nipple.addRoundedRect(
            in: CGRect(x: size.width - 22, y: midY - 4, width: 14, height: 8),
            cornerSize: CGSize(width: 2, height: 2)
        )
        context.fill(nipple, with: .color(AnodisedInk.rimGold))
    }
}
