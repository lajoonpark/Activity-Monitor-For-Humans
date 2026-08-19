import XCTest
@testable import MacExplainer

final class HealthScorerTests: XCTestCase {
    private var scorer: HealthScorer.Type { HealthScorer.self }

    private func makeSnapshot(
        cpuUsed: Double = 10,
        pressure: MemoryPressureLevel = .normal,
        swapUsed: UInt64 = 0,
        diskIn: UInt64 = 0,
        thermal: ProcessInfo.ThermalState = .nominal
    ) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(),
            uptime: 100,
            cpu: CPUCounters(userPercent: cpuUsed, systemPercent: 0, idlePercent: 100 - cpuUsed, totalUsedPercent: cpuUsed),
            memory: MemoryCounters(
                physicalBytes: 16 << 30,
                freeBytes: 2 << 30,
                activeBytes: 8 << 30,
                inactiveBytes: 4 << 30,
                wiredBytes: 1 << 30,
                compressedBytes: 1 << 30,
                internalBytes: 0,
                externalBytes: 0,
                purgeableBytes: 0,
                swapUsedBytes: swapUsed,
                swapTotalBytes: 4 << 30,
                swapins: 0,
                swapouts: 0,
                pressure: pressure
            ),
            disk: IORate(bytesPerSecondIn: diskIn, bytesPerSecondOut: 0),
            network: IORate(bytesPerSecondIn: 0, bytesPerSecondOut: 0),
            thermal: thermal,
            battery: nil,
            lowPowerMode: false
        )
    }

    private func makeHistory(
        count: Int,
        interval: TimeInterval = 2,
        cpuUsed: Double = 10,
        pressure: Int = 0,
        swapUsed: UInt64 = 0,
        disk: UInt64 = 0
    ) -> [HistoryPoint] {
        let base = Date()
        return (0..<count).map { index in
            HistoryPoint(
                timestamp: base.addingTimeInterval(TimeInterval(index) * interval),
                cpuUsedPercent: cpuUsed,
                pressureRaw: pressure,
                swapUsedBytes: swapUsed,
                diskBytesPerSecond: disk,
                networkBytesPerSecond: 0
            )
        }
    }

    func testHighRAMWithNormalPressureIsNormal() {
        // 90% of physical RAM active/wired/compressed, but pressure normal.
        let snapshot = makeSnapshot(
            cpuUsed: 10,
            pressure: .normal,
            diskIn: 0,
            thermal: .nominal
        )
        var memory = snapshot.memory
        memory.physicalBytes = 16 << 30
        memory.activeBytes = 12 << 30
        memory.wiredBytes = 2 << 30
        memory.compressedBytes = 1 << 30
        let highRAM = SystemSnapshot(
            timestamp: snapshot.timestamp,
            uptime: snapshot.uptime,
            cpu: snapshot.cpu,
            memory: memory,
            disk: snapshot.disk,
            network: snapshot.network,
            thermal: snapshot.thermal,
            battery: nil,
            lowPowerMode: false
        )
        let score = HealthScorer.evaluate(snapshot: highRAM, processes: [], history: makeHistory(count: 20, cpuUsed: 10, pressure: 0))
        XCTAssertEqual(score.level, .normal)
        XCTAssertFalse(score.signals.memoryPressureElevated)
    }

    func testSwapPresentWithNormalPressureIsNormal() {
        let snapshot = makeSnapshot(pressure: .normal, swapUsed: 1 << 30)
        let score = HealthScorer.evaluate(snapshot: snapshot, processes: [], history: makeHistory(count: 20, pressure: 0, swapUsed: 1 << 30))
        XCTAssertEqual(score.level, .normal)
    }

    func testWarningPressureIsModerate() {
        let history = makeHistory(count: 12, interval: 2, pressure: 1)
        let snapshot = makeSnapshot(pressure: .warning)
        let score = HealthScorer.evaluate(snapshot: snapshot, processes: [], history: history)
        XCTAssertEqual(score.level, .moderateLoad)
        XCTAssertTrue(score.signals.memoryPressureElevated)
    }

    func testCriticalPressureIsPotentialProblem() {
        let snapshot = makeSnapshot(pressure: .critical)
        let score = HealthScorer.evaluate(snapshot: snapshot, processes: [], history: makeHistory(count: 20, pressure: 4))
        XCTAssertEqual(score.level, .potentialProblem)
    }

    func testUrgentPressureIsHigh() {
        let snapshot = makeSnapshot(pressure: .urgent)
        let score = HealthScorer.evaluate(snapshot: snapshot, processes: [], history: makeHistory(count: 2, pressure: 2))
        XCTAssertEqual(score.level, .highLoad)
    }

    func testSustainedHighCPUIsHigh() {
        let history = makeHistory(count: 20, interval: 2, cpuUsed: 88, pressure: 0)
        let snapshot = makeSnapshot(cpuUsed: 88, pressure: .normal)
        let score = HealthScorer.evaluate(snapshot: snapshot, processes: [], history: history)
        XCTAssertEqual(score.level, .highLoad)
        XCTAssertTrue(score.signals.cpuSustainedHigh)
    }

    func testSingleCPUSpikeIsNotHigh() {
        let history = makeHistory(count: 20, interval: 2, cpuUsed: 10)
        let snapshot = makeSnapshot(cpuUsed: 96, pressure: .normal)
        let score = HealthScorer.evaluate(snapshot: snapshot, processes: [], history: history)
        XCTAssertNotEqual(score.level, .highLoad)
        XCTAssertNotEqual(score.level, .potentialProblem)
    }

    func testCriticalThermalIsPotentialProblem() {
        let snapshot = makeSnapshot(pressure: .normal, thermal: .critical)
        let score = HealthScorer.evaluate(snapshot: snapshot, processes: [], history: makeHistory(count: 20))
        XCTAssertEqual(score.level, .potentialProblem)
    }
}
