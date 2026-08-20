import XCTest
@testable import MacExplainer

final class EnergyDeltaTests: XCTestCase {
    func testMissingPreviousReturnsNil() {
        XCTAssertNil(EnergyDelta.nanojoules(previous: nil, current: 100))
    }

    func testMissingCurrentReturnsNil() {
        XCTAssertNil(EnergyDelta.nanojoules(previous: 50, current: nil))
    }

    func testCounterResetReturnsNil() {
        XCTAssertNil(EnergyDelta.nanojoules(previous: 200, current: 100))
    }

    func testPositiveDeltaIsDifference() {
        let delta = EnergyDelta.nanojoules(previous: 100, current: 160)
        XCTAssertNotNil(delta)
        XCTAssertEqual(Int(delta ?? 0), 60)
    }
}