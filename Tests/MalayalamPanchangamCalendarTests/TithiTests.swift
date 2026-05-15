import XCTest
@testable import MalayalamPanchangamCalendar

final class TithiTests: XCTestCase {
    func testTithiBoundaries() {
        let calculator = TithiCalculator()

        XCTAssertEqual(calculator.tithi(sunLongitude: 0, moonLongitude: 0), .prathamaShukla)
        XCTAssertEqual(calculator.tithi(sunLongitude: 0, moonLongitude: 12), .dwitiyaShukla)
        XCTAssertEqual(calculator.tithi(sunLongitude: 10, moonLongitude: 190), .prathamaKrishna)
        XCTAssertEqual(calculator.tithi(sunLongitude: 350, moonLongitude: 349), .amavasya)
    }
}
