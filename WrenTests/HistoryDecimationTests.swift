import XCTest
@testable import Wren

final class HistoryDecimationTests: XCTestCase {
    private func makePoints(_ count: Int) -> [HistoryPoint] {
        (0..<count).map { index in
            HistoryPoint(
                timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                cpuUsedPercent: Double(index),
                pressureRaw: 0,
                swapUsedBytes: 0,
                diskBytesPerSecond: 0,
                networkBytesPerSecond: 0
            )
        }
    }

    func testShortSeriesIsLeftAlone() {
        let points = makePoints(40)
        XCTAssertEqual(points.decimatedForDrawing(maxPoints: 90).count, points.count)
    }

    func testLongSeriesIsThinned() {
        let points = makePoints(300)
        let decimated = points.decimatedForDrawing(maxPoints: 90)
        XCTAssertLessThan(decimated.count, points.count)
        XCTAssertLessThanOrEqual(decimated.count, 91)
    }

    func testBothEndsSurvive() {
        let points = makePoints(300)
        let decimated = points.decimatedForDrawing(maxPoints: 90)
        XCTAssertEqual(decimated.first, points.first)
        XCTAssertEqual(decimated.last, points.last)
    }

    func testKeepsRealPointsInOrder() {
        let points = makePoints(300)
        let decimated = points.decimatedForDrawing(maxPoints: 90)
        XCTAssertEqual(decimated, decimated.sorted { $0.timestamp < $1.timestamp })
        // Every drawn point is a real sample, not a synthetic average.
        for point in decimated {
            XCTAssertEqual(point.cpuUsedPercent, point.timestamp.timeIntervalSince1970)
        }
    }

    func testTinyMaxPointsStillReturnsSomethingUsable() {
        let points = makePoints(300)
        let decimated = points.decimatedForDrawing(maxPoints: 3)
        XCTAssertGreaterThanOrEqual(decimated.count, 2)
        XCTAssertEqual(decimated.last, points.last)
    }

    func testEmptyAndSinglePointSeries() {
        XCTAssertTrue([HistoryPoint]().decimatedForDrawing(maxPoints: 90).isEmpty)
        XCTAssertEqual(makePoints(1).decimatedForDrawing(maxPoints: 90).count, 1)
    }
}
