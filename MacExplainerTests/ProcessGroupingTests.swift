import XCTest
@testable import MacExplainer

final class ProcessGroupingTests: XCTestCase {
    func testChildUnderParentFormsOneGroup() {
        let groups = ProcessGrouping.buildGroups(from: [
            app(pid: 100, name: "Opera", bundle: "org.opera.Opera", cpu: 4, memory: 1 << 30, isParent: true),
            helper(pid: 101, name: "Opera Helper", parent: 100, cpu: 6, memory: 1 << 29),
        ])
        XCTAssertEqual(groups.count, 1)
        let group = groups.first!
        XCTAssertEqual(group.name, "Opera")
        XCTAssertEqual(group.pid ?? -1, 100)
        XCTAssertEqual(Int(group.processCount), 2)
        XCTAssertEqual(group.cpuPercent, 10)
        XCTAssertEqual(group.residentBytes, (1 << 30) + (1 << 29))
    }

    func testParentAbsentFromSliceBecomesItsOwnGroup() {
        let groups = ProcessGrouping.buildGroups(from: [
            helper(pid: 777, name: "Opera Helper", parent: 999, cpu: 5, memory: 1 << 29),
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first!.name, "Opera Helper")
        XCTAssertEqual(Int(groups.first!.processCount), 1)
    }

    func testSharedBundleGroupsWithoutParentLink() {
        let groups = ProcessGrouping.buildGroups(from: [
            helper(pid: 201, name: "Foo", bundle: "com.foo", cpu: 3, memory: 1 << 28, isApplication: true),
            helper(pid: 202, name: "Foo Helper", bundle: "com.foo", cpu: 7, memory: 1 << 27),
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first!.name, "Foo")
        XCTAssertEqual(Int(groups.first!.processCount), 2)
    }

    func testLoneAppBecomesGroupOfSizeOne() {
        let groups = ProcessGrouping.buildGroups(from: [
            app(pid: 301, name: "Calculator", bundle: "com.apple.Calculator", cpu: 1, memory: 1 << 27, isParent: true),
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first!.name, "Calculator")
        XCTAssertEqual(Int(groups.first!.processCount), 1)
        XCTAssertEqual(groups.first!.cpuPercent, 1)
    }

    func testGroupEnergySumsMembersAndStaysNilWhenNoneReport() {
        let groups = ProcessGrouping.buildGroups(from: [
            app(pid: 100, name: "Opera", bundle: "org.opera.Opera", cpu: 4, memory: 1 << 30, isParent: true, energy: 50),
            helper(pid: 101, name: "Opera Helper", parent: 100, cpu: 6, memory: 1 << 29, energy: 150),
        ])
        XCTAssertEqual(Int(groups.first!.energyNanojoulesDelta ?? 0), 200)

        let noEnergy = ProcessGrouping.buildGroups(from: [
            app(pid: 100, name: "Opera", bundle: "org.opera.Opera", cpu: 4, memory: 1 << 30, isParent: true),
        ])
        XCTAssertNil(noEnergy.first!.energyNanojoulesDelta)
    }

    private func app(pid: Int32, name: String, bundle: String?, cpu: Double, memory: UInt64, isParent: Bool, energy: UInt64? = nil) -> ProcessSnapshot {
        ProcessSnapshot(
            id: pid,
            name: name,
            bundleIdentifier: bundle,
            cpuPercent: cpu,
            residentBytes: memory,
            energyNanojoulesDelta: energy,
            isApplication: isParent
        )
    }

    private func helper(pid: Int32, name: String, bundle: String? = nil, parent: Int32 = 0, cpu: Double, memory: UInt64, isApplication: Bool = false, energy: UInt64? = nil) -> ProcessSnapshot {
        ProcessSnapshot(
            id: pid,
            name: name,
            bundleIdentifier: bundle,
            parentPid: parent == 0 ? nil : parent,
            cpuPercent: cpu,
            residentBytes: memory,
            energyNanojoulesDelta: energy,
            isApplication: isApplication
        )
    }
}