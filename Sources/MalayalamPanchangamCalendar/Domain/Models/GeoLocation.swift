import Foundation

struct GeoLocation: Codable, Hashable, Identifiable, Sendable {
    var id: String { "\(name)-\(latitude)-\(longitude)" }

    let name: String
    let state: String
    let country: String
    let latitude: Double
    let longitude: Double
    let timezoneIdentifier: String
    let elevationMeters: Double?

    var timeZone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }

    static let thrissur = GeoLocation(
        name: "Thrissur",
        state: "Kerala",
        country: "India",
        latitude: 10.5276,
        longitude: 76.2144,
        timezoneIdentifier: "Asia/Kolkata",
        elevationMeters: 2
    )
}

extension GeoLocation {
    static let keralaDistricts: [GeoLocation] = [
        .init(name: "Thiruvananthapuram", state: "Kerala", country: "India", latitude: 8.5241, longitude: 76.9366, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 10),
        .init(name: "Kollam", state: "Kerala", country: "India", latitude: 8.8932, longitude: 76.6141, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 3),
        .init(name: "Pathanamthitta", state: "Kerala", country: "India", latitude: 9.2648, longitude: 76.7870, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 18),
        .init(name: "Alappuzha", state: "Kerala", country: "India", latitude: 9.4981, longitude: 76.3388, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 1),
        .init(name: "Kottayam", state: "Kerala", country: "India", latitude: 9.5916, longitude: 76.5222, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 3),
        .init(name: "Idukki", state: "Kerala", country: "India", latitude: 9.9189, longitude: 77.1025, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 1_200),
        .init(name: "Ernakulam", state: "Kerala", country: "India", latitude: 9.9816, longitude: 76.2999, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 4),
        .thrissur,
        .init(name: "Palakkad", state: "Kerala", country: "India", latitude: 10.7867, longitude: 76.6548, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 84),
        .init(name: "Malappuram", state: "Kerala", country: "India", latitude: 11.0510, longitude: 76.0711, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 50),
        .init(name: "Kozhikode", state: "Kerala", country: "India", latitude: 11.2588, longitude: 75.7804, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 1),
        .init(name: "Wayanad", state: "Kerala", country: "India", latitude: 11.6854, longitude: 76.1320, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 700),
        .init(name: "Kannur", state: "Kerala", country: "India", latitude: 11.8745, longitude: 75.3704, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 1),
        .init(name: "Kasaragod", state: "Kerala", country: "India", latitude: 12.4996, longitude: 74.9869, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 19)
    ]

    static let majorIndianCities: [GeoLocation] = [
        .init(name: "Chennai", state: "Tamil Nadu", country: "India", latitude: 13.0827, longitude: 80.2707, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 6),
        .init(name: "Bengaluru", state: "Karnataka", country: "India", latitude: 12.9716, longitude: 77.5946, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 920),
        .init(name: "Mumbai", state: "Maharashtra", country: "India", latitude: 19.0760, longitude: 72.8777, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 14),
        .init(name: "Delhi", state: "Delhi", country: "India", latitude: 28.6139, longitude: 77.2090, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 216),
        .init(name: "Hyderabad", state: "Telangana", country: "India", latitude: 17.3850, longitude: 78.4867, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 542),
        .init(name: "Pune", state: "Maharashtra", country: "India", latitude: 18.5204, longitude: 73.8567, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 560),
        .init(name: "Kolkata", state: "West Bengal", country: "India", latitude: 22.5726, longitude: 88.3639, timezoneIdentifier: "Asia/Kolkata", elevationMeters: 9)
    ]

    static let internationalCities: [GeoLocation] = [
        .init(name: "Dubai",     state: "Dubai",      country: "UAE",          latitude: 25.2048, longitude:  55.2708, timezoneIdentifier: "Asia/Dubai",      elevationMeters: 5),
        .init(name: "Abu Dhabi", state: "Abu Dhabi",  country: "UAE",          latitude: 24.4539, longitude:  54.3773, timezoneIdentifier: "Asia/Dubai",      elevationMeters: 27),
        .init(name: "Sharjah",   state: "Sharjah",    country: "UAE",          latitude: 25.3462, longitude:  55.4272, timezoneIdentifier: "Asia/Dubai",      elevationMeters: 16),
        .init(name: "Doha",      state: "Ad Dawhah",  country: "Qatar",        latitude: 25.2854, longitude:  51.5310, timezoneIdentifier: "Asia/Qatar",      elevationMeters: 10),
        .init(name: "Riyadh",    state: "Riyadh",     country: "Saudi Arabia", latitude: 24.7136, longitude:  46.6753, timezoneIdentifier: "Asia/Riyadh",     elevationMeters: 620),
        .init(name: "Muscat",    state: "Muscat",     country: "Oman",         latitude: 23.5880, longitude:  58.3829, timezoneIdentifier: "Asia/Muscat",     elevationMeters: 14),
        .init(name: "London",    state: "England",    country: "UK",           latitude: 51.5074, longitude:  -0.1278, timezoneIdentifier: "Europe/London",   elevationMeters: 11),
        .init(name: "Toronto",   state: "Ontario",    country: "Canada",       latitude: 43.6532, longitude: -79.3832, timezoneIdentifier: "America/Toronto", elevationMeters: 76),
        .init(name: "Singapore", state: "Singapore",  country: "Singapore",    latitude:  1.3521, longitude: 103.8198, timezoneIdentifier: "Asia/Singapore",  elevationMeters: 15)
    ]
}
