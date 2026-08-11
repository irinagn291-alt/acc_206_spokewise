import SwiftUI

/// Reference index. Genuinely tabular, so it stays a list.
struct LacingPatternIndexView: View {
    var body: some View {
        List(SpokeReferenceLibrary.entries) { pattern in
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(pattern.name)
                        .font(RimFace.label(15))
                        .foregroundStyle(AnodisedInk.readable)
                    Spacer()
                    Text("\(pattern.cross)x")
                        .font(RimFace.gauge(13))
                        .foregroundStyle(AnodisedInk.driveTeal)
                }
                Text(pattern.lengthEffect)
                    .font(RimFace.label(12))
                    .foregroundStyle(AnodisedInk.dimmed(0.7))
                Text(pattern.useCase)
                    .font(RimFace.label(11))
                    .foregroundStyle(AnodisedInk.dimmed(0.45))
            }
            .padding(.vertical, 2)
            .listRowBackground(AnodisedInk.graphite)
            .listRowSeparatorTint(AnodisedInk.rimHairline)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .rimBackdrop()
        .navigationTitle("Lacing patterns")
        .navigationBarTitleDisplayMode(.inline)
    }
}
