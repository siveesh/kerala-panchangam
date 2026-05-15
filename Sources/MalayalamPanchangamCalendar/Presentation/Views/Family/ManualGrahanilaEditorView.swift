import SwiftUI

// MARK: - ManualGrahanilaEditorView

/// South Indian square Grahanila chart that operates on `[RasiPlacement]` (no live
/// planetary longitudes required). Supports both read-only display and interactive
/// manual entry.
///
/// Tapping "+" in any rāśi cell shows a dropdown Menu listing only the planets that
/// have **not** yet been placed anywhere, preventing duplicates. Retrograde entry is
/// available as a sub-menu option from the same dropdown.
struct ManualGrahanilaEditorView: View {

    @Binding var grahanila: PersonGrahanila
    var isReadOnly: Bool = false

    /// Title shown in the centre cell (e.g. "Jātaka Grahanila").
    var centerLabel: String = "ഗ്രഹനില"

    var body: some View {
        VStack(spacing: 12) {
            chartGrid
                .aspectRatio(1, contentMode: .fit)

            if !isReadOnly {
                modeRow
                lagnaRow
                editingHint
            } else if let lagna = grahanila.lagna {
                Text("Lagna: \(lagna.englishName) (\(lagna.malayalamName))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Grid

    private var chartGrid: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cw = w / 4
            let ch = h / 4
            let b: CGFloat = 1

            ZStack(alignment: .topLeading) {
                Color(nsColor: .separatorColor).opacity(0.4)

                // Corner cells
                rasiCell(.meenam,     isCorner: true,  col: 0, row: 0, cw: cw, ch: ch, b: b)
                rasiCell(.mithunam,   isCorner: true,  col: 3, row: 0, cw: cw, ch: ch, b: b)
                rasiCell(.dhanu,      isCorner: true,  col: 0, row: 3, cw: cw, ch: ch, b: b)
                rasiCell(.kanni,      isCorner: true,  col: 3, row: 3, cw: cw, ch: ch, b: b)

                // Top row
                rasiCell(.medam,      isCorner: false, col: 1, row: 0, cw: cw, ch: ch, b: b)
                rasiCell(.edavam,     isCorner: false, col: 2, row: 0, cw: cw, ch: ch, b: b)

                // Left column
                rasiCell(.kumbham,    isCorner: false, col: 0, row: 1, cw: cw, ch: ch, b: b)
                rasiCell(.makaram,    isCorner: false, col: 0, row: 2, cw: cw, ch: ch, b: b)

                // Right column
                rasiCell(.karkidakam, isCorner: false, col: 3, row: 1, cw: cw, ch: ch, b: b)
                rasiCell(.chingam,    isCorner: false, col: 3, row: 2, cw: cw, ch: ch, b: b)

                // Bottom row
                rasiCell(.vrischikam, isCorner: false, col: 1, row: 3, cw: cw, ch: ch, b: b)
                rasiCell(.thulam,     isCorner: false, col: 2, row: 3, cw: cw, ch: ch, b: b)

                // Centre 2×2
                centerCell
                    .frame(width: 2 * cw - b, height: 2 * ch - b)
                    .offset(x: cw + b / 2, y: ch + b / 2)
            }
        }
    }

    // MARK: - Rasi Cell Builder

    @ViewBuilder
    private func rasiCell(
        _ rasi: Rasi,
        isCorner: Bool,
        col: CGFloat, row: CGFloat,
        cw: CGFloat, ch: CGFloat, b: CGFloat
    ) -> some View {
        let placements = grahanila.activePlacements.filter { $0.rasi == rasi }
        let isLagna    = grahanila.lagna == rasi
        let available  = availablePlanets()

        ZStack(alignment: .topLeading) {
            // Background
            Color(nsColor: .controlBackgroundColor).opacity(0.6)

            VStack(alignment: .leading, spacing: 2) {
                // Rasi name header + lagna marker
                HStack(spacing: 2) {
                    Text(rasi.malayalamName)
                        .font(isCorner ? .caption.weight(.semibold) : .caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if isLagna {
                        // "ല" = U+0D32 MALAYALAM LETTER LA — the traditional lagna symbol
                        Text("ല")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                }

                // Planet tokens
                ForEach(placements) { placement in
                    planetToken(placement)
                }

                // "+" dropdown — only shown in edit mode; disappears when all planets placed
                if !isReadOnly && !available.isEmpty {
                    planetAddMenu(rasi: rasi, available: available)
                        .padding(.top, 1)
                }

                Spacer(minLength: 0)
            }
            .padding(4)
        }
        .frame(width: cw - b, height: ch - b)
        .offset(x: col * cw + b / 2, y: row * ch + b / 2)
    }

    // MARK: - Planet Add Dropdown

    /// Dropdown Menu that lists only the planets not yet placed anywhere.
    /// Sub-items let the user choose Direct vs Retrograde.
    @ViewBuilder
    private func planetAddMenu(rasi: Rasi, available: [Planet]) -> some View {
        Menu {
            // Direct placements
            Section("Direct") {
                ForEach(available, id: \.self) { planet in
                    Button {
                        addPlanet(planet, to: rasi, isRetrograde: false)
                    } label: {
                        Text("\(planet.shortSymbol)  \(planet.englishName) · \(planet.malayalamName)")
                    }
                }
            }
            // Retrograde placements
            Section("Retrograde (R)") {
                ForEach(available, id: \.self) { planet in
                    Button {
                        addPlanet(planet, to: rasi, isRetrograde: true)
                    } label: {
                        Text("\(planet.shortSymbol)(R)  \(planet.englishName) · \(planet.malayalamName)")
                    }
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Planet Token

    @ViewBuilder
    private func planetToken(_ placement: RasiPlacement) -> some View {
        let token = HStack(spacing: 1) {
            Text(placement.planet.shortSymbol)
                .font(.callout.weight(.semibold))
                .foregroundStyle(planetColor(placement.planet))
            if placement.isRetrograde {
                Text("(R)")
                    .font(.system(size: 7))
                    .foregroundStyle(.orange)
            }
        }

        if isReadOnly {
            token
        } else {
            token
                .contextMenu {
                    Button(role: .destructive) {
                        removePlacement(placement)
                    } label: {
                        Label("Remove \(placement.planet.englishName)", systemImage: "trash")
                    }
                    Button {
                        toggleRetrograde(placement)
                    } label: {
                        Label(
                            placement.isRetrograde ? "Mark Direct" : "Mark Retrograde (R)",
                            systemImage: placement.isRetrograde ? "arrow.forward" : "arrow.counterclockwise"
                        )
                    }
                }
        }
    }

    // MARK: - Centre Cell

    private var centerCell: some View {
        VStack(spacing: 4) {
            Text(centerLabel)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text("ॐ")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            if !grahanila.isEmpty {
                Text(grahanila.mode.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    // MARK: - Mode Row

    private var modeRow: some View {
        HStack {
            Text("Mode:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Mode", selection: $grahanila.mode) {
                ForEach([GrahanilaMode.manual, .manualOverride], id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
        }
    }

    // MARK: - Lagna Row

    private var lagnaRow: some View {
        HStack {
            Text("Lagna (ല):")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Lagna", selection: $grahanila.lagna) {
                Text("None").tag(Optional<Rasi>.none)
                ForEach(Rasi.allCases) { rasi in
                    Text("\(rasi.englishName) · \(rasi.malayalamName)").tag(Optional(rasi))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)
        }
    }

    // MARK: - Editing Hint

    private var editingHint: some View {
        Text("Tap + to add a planet — only unplaced planets are shown. Right-click a planet token to remove it or toggle retrograde (R).")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    // MARK: - Planet Availability

    /// Returns planets not yet placed anywhere in the current active placements.
    /// This is the single source of truth used by both the dropdown and the + button visibility.
    private func availablePlanets() -> [Planet] {
        let placed = Set(grahanila.activePlacements.map(\.planet))
        // When in manual mode, also consider manualPlacements (in case mode is still .notSet)
        let placedManual = Set(grahanila.manualPlacements.map(\.planet))
        let allPlaced = placed.union(placedManual)
        return Planet.allCases.filter { !allPlaced.contains($0) }
    }

    // MARK: - Mutation Helpers

    private func addPlanet(_ planet: Planet, to rasi: Rasi, isRetrograde: Bool) {
        let placement = RasiPlacement(planet: planet, rasi: rasi, isRetrograde: isRetrograde)
        switch grahanila.mode {
        case .notSet, .manual:
            grahanila.mode = .manual
            grahanila.manualPlacements.append(placement)
        case .calculated:
            // Preserve existing calculated placements and switch to override
            grahanila.mode = .manualOverride
            grahanila.manualPlacements = grahanila.calculatedPlacements + [placement]
        case .manualOverride:
            grahanila.manualPlacements.append(placement)
        }
    }

    private func removePlacement(_ placement: RasiPlacement) {
        switch grahanila.mode {
        case .calculated:
            // Switch to override so the removal is preserved
            grahanila.mode = .manualOverride
            grahanila.manualPlacements = grahanila.calculatedPlacements.filter { $0.id != placement.id }
        case .manual, .manualOverride:
            grahanila.manualPlacements.removeAll { $0.id == placement.id }
        case .notSet:
            break
        }
    }

    private func toggleRetrograde(_ placement: RasiPlacement) {
        func toggleIn(_ list: inout [RasiPlacement]) {
            if let idx = list.firstIndex(where: { $0.id == placement.id }) {
                list[idx] = RasiPlacement(
                    id: list[idx].id,
                    planet: list[idx].planet,
                    rasi: list[idx].rasi,
                    isRetrograde: !list[idx].isRetrograde
                )
            }
        }
        toggleIn(&grahanila.manualPlacements)
        if grahanila.mode == .calculated {
            toggleIn(&grahanila.calculatedPlacements)
        }
    }

    // MARK: - Color helper

    private func planetColor(_ planet: Planet) -> Color {
        switch planet {
        case .sun:     Color(red: 1.0, green: 0.6, blue: 0.0)
        case .moon:    Color(red: 0.4, green: 0.6, blue: 1.0)
        case .mars:    Color(red: 0.9, green: 0.2, blue: 0.2)
        case .mercury: Color(red: 0.2, green: 0.7, blue: 0.3)
        case .jupiter: Color(red: 0.9, green: 0.7, blue: 0.1)
        case .venus:   Color(red: 0.9, green: 0.3, blue: 0.7)
        case .saturn:  Color(red: 0.5, green: 0.5, blue: 0.7)
        case .rahu:    Color(red: 0.3, green: 0.2, blue: 0.5)
        case .ketu:    Color(red: 0.6, green: 0.4, blue: 0.2)
        }
    }
}
