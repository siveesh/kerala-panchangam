import SwiftUI

struct PanchangamDetailScreen: View {
    let day: PanchangamDay
    let languagePreference: LanguagePreference

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                row("Calculation Mode", day.calculationMode.title)
                row("Nakshatra Transition", day.nakshatraTransition.map { PanchangamFormatters.time($0, timeZone: day.location.timeZone) } ?? "None in window")
                row("Next Nakshatra", day.nextNakshatra?.englishName ?? "Unknown")
                row("Tropical Sun Longitude", degrees(day.astronomicalData.sunLongitude))
                row("Tropical Moon Longitude", degrees(day.astronomicalData.moonLongitude))
                row("Sidereal Sun Longitude", degrees(day.astronomicalData.siderealSunLongitude))
                row("Sidereal Moon Longitude", degrees(day.astronomicalData.siderealMoonLongitude))
                row("Lahiri Ayanamsa", degrees(day.astronomicalData.lahiriAyanamsa))
            }

            Divider()

            Text("Nakshatra Periods")
                .font(.headline)
            ForEach(day.nakshatraPeriods) { period in
                HStack {
                    Text(period.nakshatra.englishName)
                    Spacer()
                    Text("\(PanchangamFormatters.time(period.start, timeZone: day.location.timeZone)) - \(PanchangamFormatters.time(period.end, timeZone: day.location.timeZone))")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func degrees(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(3))))°"
    }
}
