import SwiftUI
import WidgetKit

struct MalayalamPanchangamDayEntry: TimelineEntry {
    let date: Date
    let snapshot: PanchangamDaySnapshot
}

struct MalayalamPanchangamDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> MalayalamPanchangamDayEntry {
        MalayalamPanchangamDayEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MalayalamPanchangamDayEntry) -> Void) {
        completion(MalayalamPanchangamDayEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MalayalamPanchangamDayEntry>) -> Void) {
        let entry = MalayalamPanchangamDayEntry(date: .now, snapshot: loadSnapshot())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadSnapshot() -> PanchangamDaySnapshot {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.malayalampanchangam.calendar")
        let url = base?
            .appending(path: "MalayalamPanchangamCalendar", directoryHint: .isDirectory)
            .appending(path: "WidgetDaySnapshot.json")

        guard
            let url,
            let data = try? Data(contentsOf: url),
            let snapshot = try? JSONDecoder().decode(PanchangamDaySnapshot.self, from: data)
        else {
            return .placeholder
        }
        return snapshot
    }
}

struct MalayalamPanchangamDayWidgetView: View {
    let entry: MalayalamPanchangamDayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.snapshot.weekday)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(entry.snapshot.gregorianDate)
                        .font(family == .systemSmall ? .headline : .title3.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: "moon.stars")
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(entry.snapshot.malayalamMonth) \(entry.snapshot.malayalamDay)")
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("Kollavarsham \(entry.snapshot.kollavarshamYear)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Label(entry.snapshot.nakshatra, systemImage: "sparkle")
                .font(.caption)
                .lineLimit(1)

            Label(entry.snapshot.rahuKalam, systemImage: "clock.badge.exclamationmark")
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.orange)

            if family != .systemSmall {
                Text(entry.snapshot.locationName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

struct MalayalamPanchangamDayWidget: Widget {
    let kind = "MalayalamPanchangamDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MalayalamPanchangamDayProvider()) { entry in
            MalayalamPanchangamDayWidgetView(entry: entry)
        }
        .configurationDisplayName("Panchangam Day")
        .description("Shows Gregorian and Malayalam dates, nakshatram, and Rahu Kalam.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct MalayalamPanchangamWidgetBundle: WidgetBundle {
    var body: some Widget {
        MalayalamPanchangamDayWidget()
    }
}
