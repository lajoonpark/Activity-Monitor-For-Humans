import XCTest
@testable import MacExplainer

final class FormattersTests: XCTestCase {
    func testNilDeltaShowsDash() {
        XCTAssertEqual(Formatters.watts(nil, interval: 2), "—")
    }

    func testZeroDeltaShowsZeroWatts() {
        XCTAssertEqual(Formatters.watts(0, interval: 2), "0 W")
    }

    func testConvertsNanojoulesToWatts() {
        // 2e9 nJ = 2 J over a 2 s interval -> 1 W.
        XCTAssertEqual(Formatters.watts(2_000_000_000, interval: 2), "about 1.0 W")
    }

    func testSmallIntervalRaisesWatts() {
        // 1e8 nJ = 0.1 J over 0.5 s -> 0.2 W.
        XCTAssertEqual(Formatters.watts(100_000_000, interval: 0.5), "about 0.2 W")
    }
}