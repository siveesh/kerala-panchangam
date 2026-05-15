import Foundation

protocol PanchangamValidator: Sendable {
    func validate(day: PanchangamDay) async -> ValidationResult
}
