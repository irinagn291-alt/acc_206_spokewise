import SwiftUI

/// A dimension the builder scrubs. Caption, monospaced value, then the track.
struct BenchDimension: View {
    let caption: String
    let unit: String
    let range: ClosedRange<Double>
    let step: Double
    let decimals: Int
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(caption).rimCaption()
                Spacer()
                Text("\(formatted) \(unit)")
                    .font(RimFace.gauge(14))
                    .foregroundStyle(AnodisedInk.driveTeal)
            }
            Slider(value: $value, in: range, step: step)
                .tint(AnodisedInk.nonDriveTeal)
        }
    }

    private var formatted: String {
        String(format: "%.\(decimals)f", value)
    }
}

/// A whole-number count the builder taps up and down.
struct BenchCount: View {
    let caption: String
    let range: ClosedRange<Int>
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(caption).rimCaption()
            Spacer()
            step("minus", by: -1)
            Text("\(value)")
                .font(RimFace.gauge(15))
                .foregroundStyle(AnodisedInk.driveTeal)
                .frame(minWidth: 28)
            step("plus", by: 1)
        }
    }

    private func step(_ symbol: String, by delta: Int) -> some View {
        Button {
            value = min(range.upperBound, max(range.lowerBound, value + delta))
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AnodisedInk.readable)
                .frame(width: 34, height: 26)
                .overlay(Capsule(style: .circular).strokeBorder(AnodisedInk.hubRing, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// A row of pill chips used wherever a screen has to choose between a handful
/// of readings without leaving the screen.
struct BenchChipRow<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.value) { option in
                let active = option.value == selection
                Text(option.title)
                    .font(RimFace.chip(11, active: active))
                    .tracking(0.44)
                    .foregroundStyle(active ? AnodisedInk.chipInk : AnodisedInk.readable)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Capsule(style: .circular).fill(active ? AnodisedInk.driveTeal : Color.clear))
                    .overlay(
                        Capsule(style: .circular)
                            .strokeBorder(active ? AnodisedInk.driveTeal : AnodisedInk.hubRing, lineWidth: 1)
                    )
                    .contentShape(Capsule(style: .circular))
                    .onTapGesture { selection = option.value }
            }
            Spacer(minLength: 0)
        }
    }
}

/// The one filled action a graphics screen is allowed.
struct BenchCommit: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(RimFace.chip(13, active: true))
                .tracking(0.5)
                .foregroundStyle(AnodisedInk.chipInk)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Capsule(style: .circular).fill(AnodisedInk.driveTeal))
        }
        .buttonStyle(.plain)
    }
}
