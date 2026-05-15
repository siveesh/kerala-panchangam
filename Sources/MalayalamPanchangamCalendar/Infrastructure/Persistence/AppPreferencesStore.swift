import Foundation

struct AppPreferences: Codable, Equatable, Sendable {
    var preferredLocation: GeoLocation
    var calculationMode: CalculationMode
    var languagePreference: LanguagePreference
    var validationStrictness: ValidationStrictness
    var ayanamsaSelection: AyanamsaSelection
    var notificationsEnabled: Bool
    var calendarIntegrationEnabled: Bool
    var uses24HourTime: Bool
    var duplicateNakshatraPolicy: DuplicateNakshatraPolicy
    var duplicateNakshatraThreshold: DuplicateNakshatraThreshold
    /// How the annual Śrāddham date is determined. Default: nakshatra-only (Kerala traditional).
    var shraddhamObservanceMode: ShraddhamObservanceMode

    // Custom Decodable so existing saved JSON (without shraddhamObservanceMode) still loads.
    init(
        preferredLocation: GeoLocation,
        calculationMode: CalculationMode,
        languagePreference: LanguagePreference,
        validationStrictness: ValidationStrictness,
        ayanamsaSelection: AyanamsaSelection,
        notificationsEnabled: Bool,
        calendarIntegrationEnabled: Bool,
        uses24HourTime: Bool,
        duplicateNakshatraPolicy: DuplicateNakshatraPolicy,
        duplicateNakshatraThreshold: DuplicateNakshatraThreshold,
        shraddhamObservanceMode: ShraddhamObservanceMode = .nakshatraOnly
    ) {
        self.preferredLocation = preferredLocation
        self.calculationMode = calculationMode
        self.languagePreference = languagePreference
        self.validationStrictness = validationStrictness
        self.ayanamsaSelection = ayanamsaSelection
        self.notificationsEnabled = notificationsEnabled
        self.calendarIntegrationEnabled = calendarIntegrationEnabled
        self.uses24HourTime = uses24HourTime
        self.duplicateNakshatraPolicy = duplicateNakshatraPolicy
        self.duplicateNakshatraThreshold = duplicateNakshatraThreshold
        self.shraddhamObservanceMode = shraddhamObservanceMode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        preferredLocation         = try c.decode(GeoLocation.self,                  forKey: .preferredLocation)
        calculationMode           = try c.decode(CalculationMode.self,               forKey: .calculationMode)
        languagePreference        = try c.decode(LanguagePreference.self,            forKey: .languagePreference)
        validationStrictness      = try c.decode(ValidationStrictness.self,          forKey: .validationStrictness)
        ayanamsaSelection         = try c.decode(AyanamsaSelection.self,             forKey: .ayanamsaSelection)
        notificationsEnabled      = try c.decode(Bool.self,                          forKey: .notificationsEnabled)
        calendarIntegrationEnabled = try c.decode(Bool.self,                         forKey: .calendarIntegrationEnabled)
        uses24HourTime            = try c.decode(Bool.self,                          forKey: .uses24HourTime)
        duplicateNakshatraPolicy  = try c.decode(DuplicateNakshatraPolicy.self,      forKey: .duplicateNakshatraPolicy)
        duplicateNakshatraThreshold = try c.decode(DuplicateNakshatraThreshold.self, forKey: .duplicateNakshatraThreshold)
        // Default to .nakshatraOnly when loading JSON saved before this field existed.
        shraddhamObservanceMode   = try c.decodeIfPresent(ShraddhamObservanceMode.self, forKey: .shraddhamObservanceMode) ?? .nakshatraOnly
    }

    static let defaults = AppPreferences(
        preferredLocation: .thrissur,
        calculationMode: .keralaTraditional,
        languagePreference: .bilingual,
        validationStrictness: .standard,
        ayanamsaSelection: .lahiri,
        notificationsEnabled: false,
        calendarIntegrationEnabled: false,
        uses24HourTime: false,
        duplicateNakshatraPolicy: .preferSecondUnlessShort,
        duplicateNakshatraThreshold: .default,
        shraddhamObservanceMode: .nakshatraOnly
    )
}

protocol AppPreferencesStoring: Sendable {
    func load() async -> AppPreferences
    func save(_ preferences: AppPreferences) async
}

actor UserDefaultsAppPreferencesStore: AppPreferencesStoring {
    private let key = "MalayalamPanchangamCalendar.AppPreferences"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() async -> AppPreferences {
        guard
            let data = defaults.data(forKey: key),
            let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data)
        else {
            return .defaults
        }
        return preferences
    }

    func save(_ preferences: AppPreferences) async {
        guard let data = try? JSONEncoder().encode(preferences) else {
            assertionFailure("AppPreferences encoding failed — preferences not saved")
            return
        }
        defaults.set(data, forKey: key)
    }
}
