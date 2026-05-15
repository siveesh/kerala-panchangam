import Foundation

enum PanchangamFormatters {
    // Formatters are expensive to create. Cache one per (timezone × style) combination.
    // All access serialised through cacheLock so DateFormatter is only used from one thread
    // at a time per cached instance.
    private static let cacheLock = NSLock()
    private nonisolated(unsafe) static var timeFormatters: [String: DateFormatter] = [:]
    private nonisolated(unsafe) static var weekdayFormatters: [String: DateFormatter] = [:]

    // Returns "yyyy-MM-dd" without a DateFormatter (Calendar.dateComponents is faster).
    static func dateKey(for date: Date, timeZone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func time(_ date: Date, timeZone: TimeZone) -> String {
        cacheLock.withLock {
            let key = timeZone.identifier
            let formatter: DateFormatter
            if let cached = timeFormatters[key] {
                formatter = cached
            } else {
                let f = DateFormatter()
                f.calendar = Calendar(identifier: .gregorian)
                f.timeZone = timeZone
                f.timeStyle = .short
                f.dateStyle = .none
                timeFormatters[key] = f
                formatter = f
            }
            // timeZone must match the key — no mutation inside lock is needed.
            return formatter.string(from: date)
        }
    }

    static func weekday(_ date: Date, timeZone: TimeZone) -> String {
        cacheLock.withLock {
            let key = timeZone.identifier
            let formatter: DateFormatter
            if let cached = weekdayFormatters[key] {
                formatter = cached
            } else {
                let f = DateFormatter()
                f.calendar = Calendar(identifier: .gregorian)
                f.timeZone = timeZone
                f.dateFormat = "EEEE"
                weekdayFormatters[key] = f
                formatter = f
            }
            return formatter.string(from: date)
        }
    }
}
