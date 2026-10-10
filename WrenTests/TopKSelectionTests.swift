import XCTest
@testable import Wren

/// `topK` replaced two full `sorted(by:).prefix(k)` calls in the sampling path,
/// so it has to keep picking the same elements the sort did.
final class TopKSelectionTests: XCTestCase {
    func testSelectsTheSameElementsAsSortingAndPrefixing() {
        let input = [7, 2, 99, 41, 8, 63, 12, 5, 90, 33, 71, 4, 18, 26, 55]
        for k in 0...input.count {
            let picked = ProcessMetricsCollector.topK(input, k, by: >)
            XCTAssertEqual(picked.sorted(), Array(input.sorted(by: >).prefix(k)).sorted())
        }
    }

    func testResultsComeBackBestFirst() {
        let picked = ProcessMetricsCollector.topK([3, 41, 12, 9, 77, 2], 3, by: >)
        XCTAssertEqual(picked, [77, 41, 12])
    }

    func testReturnsExactlyKWhenEveryElementTies() {
        XCTAssertEqual(ProcessMetricsCollector.topK([5, 5, 5, 5, 5], 3, by: >).count, 3)
    }

    func testShortInputReturnsEverything() {
        XCTAssertEqual(ProcessMetricsCollector.topK([1, 2], 10, by: >), [2, 1])
    }

    func testEmptyInputAndZeroKReturnNothing() {
        XCTAssertTrue(ProcessMetricsCollector.topK([Int](), 5, by: >).isEmpty)
        XCTAssertTrue(ProcessMetricsCollector.topK([1, 2], 0, by: >).isEmpty)
    }

    func testComparatorDirectionIsRespected() {
        XCTAssertEqual(ProcessMetricsCollector.topK([3, 1, 2], 2, by: <), [1, 2])
    }

    func testRandomizedInputsMatchTheSortExactly() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let count = Int.random(in: 0...80, using: &generator)
            let k = Int.random(in: 0...12, using: &generator)
            let input = (0..<count).map { _ in Int.random(in: 0...1_000, using: &generator) }

            let picked = ProcessMetricsCollector.topK(input, k, by: >)
            let expected = Array(input.sorted(by: >).prefix(k))

            XCTAssertEqual(picked.count, expected.count)
            XCTAssertEqual(picked.sorted(), expected.sorted())
            XCTAssertEqual(picked, picked.sorted(by: >))
        }
    }
}
