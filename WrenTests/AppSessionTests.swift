import XCTest
@testable import Wren

@MainActor
final class AppSessionTests: XCTestCase {
    func testReadHoldsStackAndRelease() {
        let session = AppSession(preferences: AppPreferences())
        XCTAssertFalse(session.isReadHeld)

        let row = UUID()
        let card = UUID()
        session.setReadHold(row, true)
        XCTAssertTrue(session.isReadHeld)

        session.setReadHold(card, true)
        session.setReadHold(row, false)
        XCTAssertTrue(session.isReadHeld)

        session.setReadHold(card, false)
        XCTAssertFalse(session.isReadHeld)
    }

    func testReleasingANeverHeldIDLeavesOtherHoldsAlone() {
        let session = AppSession(preferences: AppPreferences())
        session.setReadHold(UUID(), true)
        session.setReadHold(UUID(), false)
        XCTAssertTrue(session.isReadHeld)
    }

    func testPauseFlipsTheFlagWithoutCollecting() {
        let session = AppSession(preferences: AppPreferences())
        session.togglePaused()
        XCTAssertTrue(session.isPaused)
    }
}
