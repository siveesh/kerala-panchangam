import SwiftUI

// MARK: - HoroscopeExportView

/// Sheet that shows a read-only Grahanila chart preview and lets the user
/// export a PDF horoscope via ShareLink or save to disk.
struct HoroscopeExportView: View {

    let profile: PersonProfile
    let ayanamsa: AyanamsaSelection

    @Environment(\.dismiss) private var dismiss

    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var errorMessage: String?

    private let exporter = HoroscopeExporter()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header — always use fullName, never nickname, in the export UI.
            HStack {
                VStack(alignment: .leading) {
                    Text("\(profile.fullName) — ജാതകം (Jātakam)")
                        .font(.title2.weight(.semibold))
                    if let rel = profile.relationshipTag.nilIfEmpty {
                        Text(rel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Done") { dismiss() }
            }

            Divider()

            // Birth info strip
            if let birth = profile.birthDetails {
                birthInfoStrip(birth)
            }

            // Chart preview
            Text("ജനനകാല ഗ്രഹനില — Birth Chart Preview")
                .font(.headline)
            ManualGrahanilaEditorView(
                grahanila: .constant(profile.birthGrahanila),
                isReadOnly: true,
                centerLabel: profile.fullName   // always show full name in chart, not nickname
            )
            .frame(maxWidth: 400)
            .frame(maxHeight: 400)

            if profile.birthGrahanila.isEmpty {
                Text("No chart data — calculate or enter the Grahanila in the profile form before exporting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Export controls
            HStack {
                if isExporting {
                    ProgressView("Saving PDF…")
                } else if let url = exportURL {
                    Button {
                        openInFinder(url)
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await generatePDF() }
                    } label: {
                        Label("Save Another Copy…", systemImage: "doc.richtext")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        Task { await generatePDF() }
                    } label: {
                        Label("Save PDF…", systemImage: "doc.richtext")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(profile.birthGrahanila.isEmpty && profile.birthDetails == nil)
                }

                Spacer()

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            // Disclaimer
            Text("This horoscope is for reference only. Verify planetary positions with a qualified Jyotishi.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 540)
    }

    // MARK: - Birth Info Strip

    @ViewBuilder
    private func birthInfoStrip(_ birth: BirthDetails) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 4) {
            GridRow {
                bilingualLabel("Date of Birth", "ജനനതീയതി")
                Text(birth.dateOfBirth, style: .date)
                    .font(.caption)
            }
            if let nak = birth.birthNakshatra {
                GridRow {
                    bilingualLabel("Nakshatra", "നക്ഷത്രം")
                    Text("\(nak.englishName) · \(nak.malayalamName)")
                        .font(.caption)
                }
            }
            if let tithi = birth.birthTithi, let paksha = birth.birthPaksha {
                GridRow {
                    bilingualLabel("Tithi", "തിഥി")
                    Text("\(paksha.shortName) \(tithi.englishName)")
                        .font(.caption)
                }
            }
            if let month = birth.birthMalayalamMonth, let day = birth.birthMalayalamDay, let year = birth.birthKollavarshamYear {
                GridRow {
                    bilingualLabel("Malayalam Date", "മലയാളം തീയതി")
                    Text("\(month.englishName) \(day), \(year) K.E.  ·  \(month.malayalamName) \(day), \(year) കൊ.വ.")
                        .font(.caption)
                }
            }
            if let loc = birth.birthLocation {
                GridRow {
                    bilingualLabel("Birth Place", "ജനനസ്ഥലം")
                    Text(loc.name).font(.caption)
                }
            }
            if let lagna = birth.lagna {
                GridRow {
                    bilingualLabel("Lagna", "ലഗ്നം")
                    Text("\(lagna.englishName) · \(lagna.malayalamName)")
                        .font(.caption)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Two-line label: English on top, Malayalam below in a smaller secondary style.
    @ViewBuilder
    private func bilingualLabel(_ english: String, _ malayalam: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(english)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(malayalam)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

    private func generatePDF() async {
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }
        do {
            // exportPDF shows NSSavePanel; returns nil if user cancels
            if let url = try await exporter.exportPDF(for: profile, ayanamsa: ayanamsa) {
                exportURL = url
            }
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func openInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
}

// MARK: - String helper

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
