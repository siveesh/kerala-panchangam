import SwiftUI

// MARK: - GrahanilaChartView

struct GrahanilaChartView: View {
    let day: PanchangamDay
    let languagePreference: LanguagePreference
    let ayanamsaSelection: AyanamsaSelection

    @State private var viewModel = GrahanilaViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlBar
            if viewModel.isCalculating {
                ProgressView("Calculating planetary positions…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(20)
            } else if let chart = viewModel.chart {
                chartGrid(chart: chart)
                    .aspectRatio(1, contentMode: .fit)
                disclaimer
            } else {
                ContentUnavailableView(
                    "No Chart",
                    systemImage: "moon.stars",
                    description: Text("Tap Recalculate to generate Grahanila.")
                )
            }
        }
        .task { await calculate() }
        .onChange(of: day.id) { _, _ in Task { await calculate() } }
        .sheet(item: $viewModel.selectedPlanet) { pos in
            PlanetDetailSheet(position: pos, viewModel: viewModel)
        }
    }

    private func calculate() async {
        viewModel.languagePreference = languagePreference
        viewModel.ayanamsaSelection = ayanamsaSelection
        await viewModel.calculate(for: day)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack {
            Picker("Time", selection: $viewModel.timeOption) {
                ForEach(GrahanilaTimeOption.allCases) { opt in
                    Label(opt.title, systemImage: opt.systemImage).tag(opt)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 340)
            .onChange(of: viewModel.timeOption) { _, _ in
                Task { await viewModel.recalculate() }
            }

            if viewModel.timeOption == .custom {
                DatePicker(
                    "",
                    selection: $viewModel.customTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .onChange(of: viewModel.customTime) { _, _ in
                    Task { await viewModel.recalculate() }
                }
            }

            Spacer()

            if let chart = viewModel.chart {
                Text(chart.calculationTime, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Disclaimer

    private var disclaimer: some View {
        Text(
            "Grahanila is calculated using astronomical planetary positions and traditional sidereal rāśi mapping. Interpretations may vary by regional Panchangam tradition."
        )
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.top, 4)
    }

    // MARK: - Chart Grid

    private func chartGrid(chart: GrahanilaChart) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cw = w / 4
            let ch = h / 4
            let border: CGFloat = 1

            ZStack(alignment: .topLeading) {
                Color(nsColor: .separatorColor).opacity(0.4)

                // Corner cells
                rasiCell(chart.house(for: .meenam), isCorner: true)
                    .frame(width: cw - border, height: ch - border)
                    .offset(x: 0 * cw + border / 2, y: 0 * ch + border / 2)

                rasiCell(chart.house(for: .mithunam), isCorner: true)
                    .frame(width: cw - border, height: ch - border)
                    .offset(x: 3 * cw + border / 2, y: 0 * ch + border / 2)

                rasiCell(chart.house(for: .dhanu), isCorner: true)
                    .frame(width: cw - border, height: ch - border)
                    .offset(x: 0 * cw + border / 2, y: 3 * ch + border / 2)

                rasiCell(chart.house(for: .kanni), isCorner: true)
                    .frame(width: cw - border, height: ch - border)
                    .offset(x: 3 * cw + border / 2, y: 3 * ch + border / 2)

                // Top row (non-corners)
                rasiCell(chart.house(for: .medam), isCorner: false)
                    .frame(width: cw - border, height: ch - border)
                    .offset(x: 1 * cw + border / 2, y: 0 * ch + border / 2)

                rasiCell(chart.house(for: .edavam), isCorner: false)
                    .frame(width: cw - border, height: ch - border)
                    .offset(x: 2 * cw + border / 2, y: 0 * ch + border / 2)

                // Left column (non-corners)
                rasiCell(chart.house(for: .kumbham), isCorner: false)
                    .frame(width: cw - border, height: ch - border)
                    .offset(x: 0 * cw + border / 2, y: 1 * ch + border / 2)

                rasiCell(chart.house(for: .makaram), isCorner: false)
                    .frame(width: cw - border, height: ch - border)
                    .offset(x: 0 * cw + border / 2, y: 2 * ch + border / 2)

                // Right column (non-corners)
                rasiCell(chart.house(for: .karkidakam), isCorner: false)
                    .frame(width: cw - border, height: ch - border)
                    .offset(x: 3 * cw + border / 2, y: 1 * ch + border / 2)

                rasiCell(chart.house(for: .chingam), isCorner: false)
                    .frame(width: cw - border, height: ch - border)
                    .offset(x: 3 * cw + border / 2, y: 2 * ch + border / 2)

                // Bottom row (non-corners)
                rasiCell(chart.house(for: .vrischikam), isCorner: false)
                    .frame(width: cw - border, height: ch - border)
                    .offset(x: 1 * cw + border / 2, y: 3 * ch + border / 2)

                rasiCell(chart.house(for: .thulam), isCorner: false)
                    .frame(width: cw - border, height: ch - border)
                    .offset(x: 2 * cw + border / 2, y: 3 * ch + border / 2)

                // Center 2×2
                centerCell(chart: chart, day: day)
                    .frame(width: 2 * cw - border, height: 2 * ch - border)
                    .offset(x: 1 * cw + border / 2, y: 1 * ch + border / 2)
            }
        }
    }

    // MARK: - Rasi Cell

    @ViewBuilder
    private func rasiCell(_ house: RasiHouse, isCorner: Bool) -> some View {
        Button {
            viewModel.selectedRasi = house.rasi
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                let rasiName: String = {
                    switch languagePreference {
                    case .english:   house.rasi.englishName
                    case .malayalam: house.rasi.malayalamName
                    case .bilingual: house.rasi.malayalamName
                    }
                }()

                Text(rasiName)
                    .font(isCorner ? .caption.weight(.semibold) : .caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                ForEach(house.planets) { pos in
                    Button {
                        viewModel.selectedPlanet = pos
                    } label: {
                        HStack(spacing: 2) {
                            Text(pos.planet.shortSymbol)
                                .font(.callout.weight(.semibold))
                            if pos.isRetrograde {
                                Text("℞")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .foregroundStyle(planetColor(pos.planet))
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(cellBackgroundColor(house: house))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Center Cell

    @ViewBuilder
    private func centerCell(chart: GrahanilaChart, day: PanchangamDay) -> some View {
        VStack(spacing: 4) {
            Text("ഗ്രഹനില")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text("ॐ")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text(day.isoDateKey)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(day.location.name)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    // MARK: - Helpers

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

    private func cellBackgroundColor(house: RasiHouse) -> Color {
        if house.rasi == viewModel.selectedRasi {
            return Color.accentColor.opacity(0.12)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.6)
    }
}

// MARK: - PlanetDetailSheet

private struct PlanetDetailSheet: View {
    let position: PlanetPosition
    let viewModel: GrahanilaViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: position.planet.systemImage)
                    .font(.title)
                    .foregroundStyle(planetColor(position.planet))
                VStack(alignment: .leading) {
                    Text(position.planet.englishName)
                        .font(.title2.weight(.semibold))
                    Text(position.planet.malayalamName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }

            Divider()

            // Metrics
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                detailRow("Rāśi",            viewModel.positionSummary(for: position))
                detailRow("Degree in Rāśi",  String(format: "%.2f°", position.degreeInRasi))
                detailRow("Tropical Long.",  String(format: "%.4f°", position.tropicalLongitude))
                detailRow("Sidereal Long.",  String(format: "%.4f°", position.siderealLongitude))
                detailRow("Nakshatra",       position.nakshatra.englishName + " (\(position.nakshatra.malayalamName))")
                detailRow("Pāda",            "\(position.pada)")
                detailRow("Retrograde",      position.isRetrograde ? "Yes ℞" : "No")
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 340, minHeight: 300)
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
    }

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
