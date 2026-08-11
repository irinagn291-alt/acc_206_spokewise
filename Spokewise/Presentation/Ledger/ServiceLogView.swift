import SwiftUI

/// The service log. A log is a list, so this is one of the three that stays.
struct ServiceLogView: View {
    let container: SpokeContainer

    @State private var events: [SpokeServiceEvent] = []
    @State private var mileage: [SpokeMileageEntry] = []
    @State private var wheelNames: [UUID: String] = [:]

    var body: some View {
        List {
            Section {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(event.title)
                                .font(RimFace.label(15))
                                .foregroundStyle(AnodisedInk.readable)
                            Spacer()
                            Text(event.date.formatted(date: .abbreviated, time: .omitted))
                                .font(RimFace.gauge(11))
                                .foregroundStyle(AnodisedInk.dimmed(0.5))
                        }
                        Text(wheelNames[event.wheelId] ?? "Unlisted wheel")
                            .font(RimFace.label(11))
                            .foregroundStyle(AnodisedInk.driveTeal)
                        if !event.notes.isEmpty {
                            Text(event.notes)
                                .font(RimFace.label(12))
                                .foregroundStyle(AnodisedInk.dimmed(0.6))
                        }
                    }
                    .listRowBackground(AnodisedInk.graphite)
                    .listRowSeparatorTint(AnodisedInk.rimHairline)
                }
            } header: {
                Text("Service").rimCaption()
            }

            Section {
                ForEach(mileage) { entry in
                    HStack {
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            .font(RimFace.label(13))
                            .foregroundStyle(AnodisedInk.readable)
                        Spacer()
                        Text(String(format: "%.0f km", entry.km))
                            .font(RimFace.gauge(13))
                            .foregroundStyle(AnodisedInk.driveTeal)
                    }
                    .listRowBackground(AnodisedInk.graphite)
                    .listRowSeparatorTint(AnodisedInk.rimHairline)
                }
            } header: {
                Text("Mileage").rimCaption()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .rimBackdrop()
        .navigationTitle("Service log")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        events = (try? await container.serviceRepository.fetchAll()) ?? []
        let wheels = (try? await container.wheelRepository.fetchAll()) ?? []
        wheelNames = Dictionary(uniqueKeysWithValues: wheels.map { ($0.id, $0.name) })
        var collected: [SpokeMileageEntry] = []
        for wheel in wheels {
            collected += (try? await container.mileageRepository.fetch(wheelId: wheel.id)) ?? []
        }
        mileage = collected.sorted { $0.date > $1.date }
    }
}
