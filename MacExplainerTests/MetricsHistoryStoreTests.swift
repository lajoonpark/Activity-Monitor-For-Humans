import XCTest
@testable import MacExplainer

final class MetricsHistoryStoreTests: XCTestCase {
    private func point(at date: Date, cpu: Double = 10, swapUsed: UInt64 = 0) -> HistoryPoint {
        HistoryPoint(
            timestamp: date,
            cpuUsedPercent: cpu,
            pressureRaw: 0,
            swapUsedBytes: swapUsed,
            diskBytesPerSecond: 0,
            networkBytesPerSecond: 0
        )
    }

    func testFiveMinuteWindowKeepsEverySampleInOrder() {
        let store = MetricsHistoryStore()
        let interval: TimeInterval = 2
        for index in 0..<10 {
            store.append(point(at: Date().addingTimeInterval(-TimeInterval(9 - index) * interval), cpu: Double(index)))
        }
        let points = store.points(for: .fiveMinutes)
        XCTAssertEqual(points.count, 10)
        XCTAssertEqual(points.map(\.cpuUsedPercent), (0..<10).map { Double($0) })
    }

    func testThirtyMinuteWindowDownsamples() {
        let store = MetricsHistoryStore()
        let interval: TimeInterval = 2
        let base = Date().addingTimeInterval(-40 * interval)
        for index in 0..<40 {
            store.append(point(at: base.addingTimeInterval(TimeInterval(index) * interval), cpu: 10))
        }
        let points = store.points(for: .thirtyMinutes)
        XCTAssertLessThan(points.count, 40)
        XCTAssertGreaterThan(points.count, 0)
        for sample in points {
            XCTAssertEqual(sample.cpuUsedPercent, 10, accuracy: 0.001)
        }
    }

    func testPrunesOldPoints() {
        let store = MetricsHistoryStore()
        let now = Date()
        store.append(point(at: now.addingTimeInterval(-10_000), cpu: 5))
        store.append(point(at: now.addingTimeInterval(-9_999), cpu: 6))
        store.append(point(at: now.addingTimeInterval(-2), cpu: 50))
        store.append(point(at: now.addingTimeInterval(-1), cpu: 60))
        let points = store.points(for: .fiveMinutes)
        XCTAssertEqual(points.map(\.cpuUsedPercent), [50, 60])
    }

    func testResetClearsStore() {
        let store = MetricsHistoryStore()
        store.append(point(at: Date()))
        store.reset()
        XCTAssertTrue(store.points(for: .twoHours).isEmpty)
    }
}
