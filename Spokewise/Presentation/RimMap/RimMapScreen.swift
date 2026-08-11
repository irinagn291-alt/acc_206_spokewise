import SwiftUI

/// The root. One artefact, three lens chips over it, the readout pinned under
/// it, and a quiet two-tier destination chrome for Bench / Wheel / Workshop.
struct RimMapScreen: View {
    @ObservedObject var model: RimMapModel
    @Binding var path: NavigationPath

    private static let primaryRoutes: [SpokeRoute] = [.bench, .calibration, .builds]
    private static let secondaryRoutes: [SpokeRoute] = [
        .components, .compare, .stats, .reference, .maintenance
    ]

    var body: some View {
        VStack(spacing: 0) {
            chipRow
                .padding(.horizontal, 24)
                .padding(.top, 8)
            map
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
                .padding(.horizontal, 8)
            readoutRow
                .padding(.horizontal, 24)
                .padding(.top, 6)
            bottomChrome
                .padding(.top, 12)
                .padding(.bottom, 14)
        }
        .rimBackdrop()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { wheelTitle }
            ToolbarItem(placement: .topBarTrailing) { settingsGear }
        }
        .sheet(item: $model.dialTarget) { target in
            SpokeDialSheet(
                target: target,
                lens: model.lens,
                calibration: model.artefact?.calibration ?? []
            ) { value in
                Task { await model.commit(value) }
            }
        }
        .alert("Workshop store", isPresented: Binding(
            get: { model.failure != nil },
            set: { if !$0 { model.dismissFailure() } }
        )) {
            Button("OK", role: .cancel) { model.dismissFailure() }
        } message: {
            Text(model.failure ?? "")
        }
    }

    private var chipRow: some View {
        HStack(spacing: 8) {
            ForEach(RimLens.allCases) { lens in
                chip(lens)
            }
            Spacer(minLength: 8)
            Text(model.deviationScale)
                .rimCaption()
        }
    }

    private func chip(_ lens: RimLens) -> some View {
        let active = model.lens == lens
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { model.lens = lens }
        } label: {
            Text(lens.title)
                .font(RimFace.chip(14, active: active))
                .tracking(0.4)
                .foregroundStyle(active ? AnodisedInk.chipInk : AnodisedInk.readable)
                .padding(.horizontal, 16)
                .frame(minHeight: 40)
                .background(
                    Capsule(style: .circular)
                        .fill(active ? AnodisedInk.driveTeal : AnodisedInk.graphite)
                )
                .overlay(
                    Capsule(style: .circular)
                        .strokeBorder(active ? AnodisedInk.driveTeal : AnodisedInk.hubRing, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    private var map: some View {
        RimMapCanvas(
            samples: model.samples,
            cross: model.artefact?.wheel.cross ?? 3,
            lens: model.lens,
            selected: model.dialTarget?.id
        )
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            GeometryReader { proxy in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { tap in
                            model.beginDial(
                                at: RimPoint(x: Double(tap.location.x), y: Double(tap.location.y)),
                                in: proxy.size
                            )
                        }
                    )
            }
        }
    }

    private var readoutRow: some View {
        let figures = RimReadoutMath.format(model.readout)
        return HStack(alignment: .top, spacing: 12) {
            readoutCell("Mean", figures.mean)
            Spacer(minLength: 0)
            readoutCell("Spread", figures.spread)
            Spacer(minLength: 0)
            readoutCell("Dish", figures.dish)
        }
    }

    private func readoutCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).rimCaption()
            Text(value)
                .font(RimFace.gauge(21))
                .tracking(-0.42)
                .foregroundStyle(AnodisedInk.driveTeal)
        }
    }

    /// Horizontal tool chips — 44 pt tall, scrollable, actually tappable.
    private var bottomChrome: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(workshopRoutes) { route in
                    workshopChip(route)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var workshopRoutes: [SpokeRoute] {
        var routes = Self.primaryRoutes
        if let id = model.selectedWheelId {
            routes.insert(.truing(id), at: 1)
        }
        routes.append(contentsOf: Self.secondaryRoutes)
        return routes
    }

    private func workshopChip(_ route: SpokeRoute) -> some View {
        Button {
            path.append(route)
        } label: {
            Text(route.chipLabel)
                .font(RimFace.chip(13, active: false))
                .tracking(0.3)
                .foregroundStyle(AnodisedInk.driveTeal)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(
                    Capsule(style: .circular)
                        .fill(AnodisedInk.graphite)
                )
                .overlay(
                    Capsule(style: .circular)
                        .strokeBorder(AnodisedInk.driveTeal.opacity(0.75), lineWidth: 1.2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(route.label)
    }

    private var wheelTitle: some View {
        Menu {
            ForEach(model.wheels) { wheel in
                Button {
                    Task { await model.select(wheel.id) }
                } label: {
                    Label(
                        RimReadoutMath.rimTitle(name: wheel.name, spokeCount: wheel.spokeCount),
                        systemImage: wheel.id == model.selectedWheelId ? "checkmark" : "circle.dashed"
                    )
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(model.title)
                    .font(RimFace.heading(17))
                    .foregroundStyle(AnodisedInk.readable)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AnodisedInk.dimmed(0.6))
            }
        }
    }

    private var settingsGear: some View {
        Button {
            path.append(SpokeRoute.settings)
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AnodisedInk.driveTeal)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Settings")
    }
}
