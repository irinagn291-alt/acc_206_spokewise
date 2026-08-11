import SwiftUI

/// Preferences and the tension-sheet export. Settings are a form.
struct SpokeSettingsView: View {
    let container: SpokeContainer

    @State private var settings = SpokeSettings()
    @State private var sheet = ""
    @State private var confirmation = ""

    private let gauges = ["1.5", "1.8", "2.0", "2.3"]

    var body: some View {
        Form {
            Section {
                Picker("Preferred gauge", selection: $settings.preferredGauge) {
                    ForEach(gauges, id: \.self) { gauge in
                        Text("\(gauge) mm").tag(gauge)
                    }
                }
                Picker("Tension unit", selection: $settings.tensionUnit) {
                    Text("kgf").tag("kgf")
                    Text("N").tag("N")
                }
                Button("Store preferences") { Task { await store() } }
            } header: {
                Text("Workshop").rimCaption()
            } footer: {
                if !confirmation.isEmpty {
                    Text(confirmation)
                        .font(RimFace.label(11))
                        .foregroundStyle(AnodisedInk.driveTeal)
                }
            }

            Section {
                Button("Build tension sheet") { Task { await build() } }
                if !sheet.isEmpty {
                    ShareLink(item: sheet, subject: Text("Tension sheet")) {
                        Label("Share sheet", systemImage: "square.and.arrow.up")
                    }
                    Text(sheet)
                        .font(RimFace.gauge(10))
                        .foregroundStyle(AnodisedInk.dimmed(0.6))
                        .lineLimit(8)
                }
            } header: {
                Text("Export").rimCaption()
            }

            Section {
                Link(destination: URL(string: "https://spoke-lacingdesk.pro/contact-us")!) {
                    Text("Contact Us")
                }
            } header: {
                Text("Support").rimCaption()
            }
        }
        .scrollContentBackground(.hidden)
        .rimBackdrop()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { settings = (try? await container.settingsRepository.load()) ?? SpokeSettings() }
    }

    private func store() async {
        do {
            try await container.settingsRepository.save(settings)
            confirmation = "Stored in the workshop database."
        } catch {
            confirmation = error.localizedDescription
        }
    }

    private func build() async {
        guard let id = (try? await container.wheelRepository.fetchAll())?.first?.id else { return }
        sheet = (try? await container.exportCSV(wheelId: id)) ?? ""
    }
}
