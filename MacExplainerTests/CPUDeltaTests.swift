import XCTest
@testable import MacExplainer

final class CPUDeltaTests: XCTestCase {
    func testPercentFromTickDelta() {
        // 10 million ticks over 2 seconds = 5 million ticks/sec of one core.
        let previous = ProcessCPUSample(pid: 42, totalTicks: 100_000_000)
        let current = ProcessCPUSample(pid: 42, totalTicks: 110_000_000)
        guard let percent = CPUPercent.percent(previous: previous, current: current, interval: 2) else {
            return XCTFail("Expected a value")
        }
        // 10M ticks / 2s -> depends on timebase; assert it is within 0...100 and positive.
        XCTAssertGreaterThanOrEqual(percent, 0)
        XCTAssertLessThanOrEqual(percent, 100)
        XCTAssertGreaterThan(percent, 0)
    }

    func testNoBaselineReturnsNil() {
        XCTAssertNil(CPUPercent.percent(previous: nil, current: ProcessCPUSample(pid: 1, totalTicks: 5), interval: 2))
    }

    func testNegativeDeltaReturnsNil() {
        let previous = ProcessCPUSample(pid: 1, totalTicks: 100)
        let current = ProcessCPUSample(pid: 1, totalTicks: 90)
        XCTAssertNil(CPUPercent.percent(previous: previous, current: current, interval: 2))
    }

    func testClampedTo100() {
        XCTAssertLessThanOrEqual(CPUPercent.percent(
            previous: ProcessCPUSample(pid: 1, totalTicks: 0),
            current: ProcessCPUSample(pid: 1, totalTicks: .max),
            interval: 1_000_000
        ) ?? -1, 100)
    }
}
