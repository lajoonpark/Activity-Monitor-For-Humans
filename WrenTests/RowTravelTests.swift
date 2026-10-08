import XCTest
@testable import Wren

final class RowTravelTests: XCTestCase {
    func testMovesWithinFourSpotsGlide() {
        XCTAssertEqual(RowTravel.classify(fromRank: 0, toRank: 4), .glide)
        XCTAssertEqual(RowTravel.classify(fromRank: 4, toRank: 0), .glide)
        XCTAssertEqual(RowTravel.classify(fromRank: 7, toRank: 7), .glide)
        XCTAssertEqual(RowTravel.classify(fromRank: 12, toRank: 9), .glide)
    }

    func testMovesBeyondFourSpotsFade() {
        XCTAssertEqual(RowTravel.classify(fromRank: 0, toRank: 5), .fade)
        XCTAssertEqual(RowTravel.classify(fromRank: 5, toRank: 0), .fade)
        XCTAssertEqual(RowTravel.classify(fromRank: 20, toRank: 2), .fade)
    }
}
