import Foundation

enum MalayalamMonth: Int, CaseIterable, Codable, Identifiable, Sendable {
    case chingam = 1, kanni, thulam, vrischikam, dhanu, makaram, kumbham, meenam, medam, edavam, mithunam, karkidakam

    var id: Int { rawValue }

    var englishName: String {
        switch self {
        case .chingam: "Chingam"
        case .kanni: "Kanni"
        case .thulam: "Thulam"
        case .vrischikam: "Vrischikam"
        case .dhanu: "Dhanu"
        case .makaram: "Makaram"
        case .kumbham: "Kumbham"
        case .meenam: "Meenam"
        case .medam: "Medam"
        case .edavam: "Edavam"
        case .mithunam: "Mithunam"
        case .karkidakam: "Karkidakam"
        }
    }

    var malayalamName: String {
        switch self {
        case .chingam: "ചിങ്ങം"
        case .kanni: "കന്നി"
        case .thulam: "തുലാം"
        case .vrischikam: "വൃശ്ചികം"
        case .dhanu: "ധനു"
        case .makaram: "മകരം"
        case .kumbham: "കുംഭം"
        case .meenam: "മീനം"
        case .medam: "മേടം"
        case .edavam: "ഇടവം"
        case .mithunam: "മിഥുനം"
        case .karkidakam: "കർക്കടകം"
        }
    }
}

enum Nakshatra: Int, CaseIterable, Codable, Identifiable, Sendable {
    case aswathi, bharani, karthika, rohini, makayiram, thiruvathira, punartham, pooyam, ayilyam
    case makam, pooram, uthram, atham, chithira, chothi, vishakham, anizham, thrikketta
    case moolam, pooradam, uthradam, thiruvonam, avittam, chathayam, pooruruttathi, uthrattathi, revathi

    static let spanDegrees = 360.0 / 27.0

    var id: Int { rawValue }

    var englishName: String {
        switch self {
        case .aswathi: "Aswathi"
        case .bharani: "Bharani"
        case .karthika: "Karthika"
        case .rohini: "Rohini"
        case .makayiram: "Makayiram"
        case .thiruvathira: "Thiruvathira"
        case .punartham: "Punartham"
        case .pooyam: "Pooyam"
        case .ayilyam: "Ayilyam"
        case .makam: "Makam"
        case .pooram: "Pooram"
        case .uthram: "Uthram"
        case .atham: "Atham"
        case .chithira: "Chithira"
        case .chothi: "Chothi"
        case .vishakham: "Vishakham"
        case .anizham: "Anizham"
        case .thrikketta: "Thrikketta"
        case .moolam: "Moolam"
        case .pooradam: "Pooradam"
        case .uthradam: "Uthradam"
        case .thiruvonam: "Thiruvonam"
        case .avittam: "Avittam"
        case .chathayam: "Chathayam"
        case .pooruruttathi: "Pooruruttathi"
        case .uthrattathi: "Uthrattathi"
        case .revathi: "Revathi"
        }
    }

    var malayalamName: String {
        switch self {
        case .aswathi: "അശ്വതി"
        case .bharani: "ഭരണി"
        case .karthika: "കാർത്തിക"
        case .rohini: "രോഹിണി"
        case .makayiram: "മകയിരം"
        case .thiruvathira: "തിരുവാതിര"
        case .punartham: "പുണർതം"
        case .pooyam: "പൂയം"
        case .ayilyam: "ആയില്യം"
        case .makam: "മകം"
        case .pooram: "പൂരം"
        case .uthram: "ഉത്രം"
        case .atham: "അത്തം"
        case .chithira: "ചിത്തിര"
        case .chothi: "ചോതി"
        case .vishakham: "വിശാഖം"
        case .anizham: "അനിഴം"
        case .thrikketta: "തൃക്കേട്ട"
        case .moolam: "മൂലം"
        case .pooradam: "പൂരാടം"
        case .uthradam: "ഉത്രാടം"
        case .thiruvonam: "തിരുവോണം"
        case .avittam: "അവിട്ടം"
        case .chathayam: "ചതയം"
        case .pooruruttathi: "പൂരുരുട്ടാതി"
        case .uthrattathi: "ഉത്രട്ടാതി"
        case .revathi: "രേവതി"
        }
    }

    static func from(siderealLongitude longitude: Double) -> Nakshatra {
        let normalized = longitude.normalizedDegrees
        let index = min(Int(floor(normalized / spanDegrees)), 26)
        return Nakshatra(rawValue: index) ?? .aswathi
    }

    var next: Nakshatra {
        Nakshatra(rawValue: (rawValue + 1) % Nakshatra.allCases.count) ?? .aswathi
    }
}

enum Tithi: Int, CaseIterable, Codable, Identifiable, Sendable {
    case prathamaShukla = 0, dwitiyaShukla, tritiyaShukla, chaturthiShukla, panchamiShukla
    case shashthiShukla, saptamiShukla, ashtamiShukla, navamiShukla, dashamiShukla
    case ekadashiShukla, dwadashiShukla, trayodashiShukla, chaturdashiShukla, purnima
    case prathamaKrishna, dwitiyaKrishna, tritiyaKrishna, chaturthiKrishna, panchamiKrishna
    case shashthiKrishna, saptamiKrishna, ashtamiKrishna, navamiKrishna, dashamiKrishna
    case ekadashiKrishna, dwadashiKrishna, trayodashiKrishna, chaturdashiKrishna, amavasya

    static let spanDegrees = 12.0

    var id: Int { rawValue }

    var paksha: String {
        rawValue < 15 ? "Shukla" : "Krishna"
    }

    var englishName: String {
        switch self {
        case .prathamaShukla, .prathamaKrishna: "Prathama"
        case .dwitiyaShukla, .dwitiyaKrishna: "Dwitiya"
        case .tritiyaShukla, .tritiyaKrishna: "Tritiya"
        case .chaturthiShukla, .chaturthiKrishna: "Chaturthi"
        case .panchamiShukla, .panchamiKrishna: "Panchami"
        case .shashthiShukla, .shashthiKrishna: "Shashthi"
        case .saptamiShukla, .saptamiKrishna: "Saptami"
        case .ashtamiShukla, .ashtamiKrishna: "Ashtami"
        case .navamiShukla, .navamiKrishna: "Navami"
        case .dashamiShukla, .dashamiKrishna: "Dashami"
        case .ekadashiShukla, .ekadashiKrishna: "Ekadashi"
        case .dwadashiShukla, .dwadashiKrishna: "Dwadashi"
        case .trayodashiShukla, .trayodashiKrishna: "Trayodashi"
        case .chaturdashiShukla, .chaturdashiKrishna: "Chaturdashi"
        case .purnima: "Purnima"
        case .amavasya: "Amavasya"
        }
    }
}
