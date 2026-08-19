import XCTest
@testable import MacExplainer

final class ExplanationGeneratorTests: XCTestCase {
    private func makeSnapshot(
        pressure: MemoryPressureLevel = .normal,
        swapUsed: UInt64 = 0,
        activeBytes: UInt64 = 6 << 30,
        physical: UInt64 = 16 << 30
    ) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(),
            uptime: 100,
            cpu: CPUCounters(userPercent: 5, systemPercent: 2, idlePercent: 93, totalUsedPercent: 7),
            memory: MemoryCounters(
                physicalBytes: physical,
                freeBytes: 2 << 30,
                activeBytes: activeBytes,
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
            disk: IORate(bytesPerSecondIn: 0, bytesPerSecondOut: 0),
            network: IORate(bytesPerSecondIn: 0, bytesPerSecondOut: 0),
            thermal: .nominal,
            battery: nil,
            lowPowerMode: false
        )
    }

    private func emptySignals() -> HealthSignals {
        HealthSignals(cpuSustainedHigh: false, memoryPressureElevated: false, swapGrowing: false, thermalElevated: false, diskBusy: false, dominantProcess: nil)
    }

    func testNormalMemoryCopyDoesNotScaremonger() {
        let snapshot = makeSnapshot(pressure: .normal, activeBytes: 10 << 30, physical: 16 << 30)
        let reasons = ExplanationGenerator.generate(level: .normal, signals: emptySignals(), snapshot: snapshot)
        XCTAssertTrue(reasons.contains { $0.id == "memory.normal.full" })
        XCTAssertFalse(reasons.contains { $0.id == "pressure.critical" })
    }

    func testNeverSaysOutOfRAMUnlessPressureHigh() {
        let snapshot = makeSnapshot(pressure: .normal)
        let reasons = ExplanationGenerator.generate(level: .normal, signals: emptySignals(), snapshot: snapshot)
        XCTAssertFalse(reasons.contains { $0.headline.contains("out of RAM") })
        XCTAssertTrue(ExplanationGenerator.summary(for: .normal).contains("normally"))
    }

    func testSwapWithNormalPressureExplainedAsNormal() {
        let snapshot = makeSnapshot(pressure: .normal, swapUsed: 500 << 20)
        let reasons = ExplanationGenerator.generate(level: .normal, signals: emptySignals(), snapshot: snapshot)
        XCTAssertTrue(reasons.contains { $0.id == "swap.normal" })
    }

    func testUrgentPressureExplained() {
        let snapshot = makeSnapshot(pressure: .urgent)
        let reasons = ExplanationGenerator.generate(level: .highLoad, signals: emptySignals(), snapshot: snapshot)
        XCTAssertTrue(reasons.contains { $0.id == "pressure.urgent" })
    }

    func testNamesTopAppWhenOutlier() {
        var signals = emptySignals()
        signals.cpuSustainedHigh = true
        signals.dominantProcess = ProcessSnapshot(
            id: 12,
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            cpuPercent: 90,
            residentBytes: 1 << 30,
            footprintBytes: nil,
            energyNanojoulesDelta: nil,
            isApplication: true
        )
        let snapshot = makeSnapshot(pressure: .normal)
        let reasons = ExplanationGenerator.generate(level: .highLoad, signals: signals, snapshot: snapshot)
        XCTAssertTrue(reasons.contains { $0.id == "cpu.high.app" && $0.headline.contains("Safari") })
    }
}
