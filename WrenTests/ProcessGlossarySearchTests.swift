import XCTest
@testable import Wren

final class ProcessGlossarySearchTests: XCTestCase {
    private func topEntry(_ query: String) -> ProcessGlossaryEntry? {
        ProcessGlossarySearch.search(query).first?.entry
    }

    // MARK: - The name is close but wrong

    func testFindsEntryThroughATypo() {
        XCTAssertEqual(topEntry("fileprovidered")?.id, "fileproviderd")
    }

    func testFindsEntryThroughATransposition() {
        XCTAssertEqual(topEntry("widnowsserver")?.id, "windowserver")
    }

    func testSpacingAndCaseDoNotMatter() {
        XCTAssertEqual(topEntry("windows server")?.id, "windowserver")
        XCTAssertEqual(topEntry("WINDOWSSERVER")?.id, "windowserver")
        XCTAssertEqual(topEntry("Window Server")?.id, "windowserver")
    }

    func testCompoundNameSplitAcrossWords() {
        XCTAssertEqual(topEntry("biome agent")?.id, "biomeagent")
        XCTAssertEqual(topEntry("mds stores")?.id, "mds_stores")
    }

    // MARK: - The person pastes a bundle identifier

    func testBundleIdentifierMatchesDirectly() {
        XCTAssertEqual(topEntry("com.apple.WebKit.WebContent")?.id, "safari-web-content")
        XCTAssertEqual(topEntry("com.apple.BiomeAgent")?.id, "biomeagent")
    }

    func testBundleIdentifierMatchIgnoresCase() {
        XCTAssertEqual(topEntry("COM.APPLE.WEBKIT.WEBCONTENT")?.id, "safari-web-content")
        XCTAssertEqual(
            ProcessGlossarySearch.bestMatch(forName: "whatever", bundleIdentifier: "COM.ADOBE.CREATIVECLOUD")?.id,
            "adobe-creative-cloud"
        )
    }

    func testBundleIdentifiersKeepTheirAuthoredCaseForDisplay() {
        let entry = ProcessGlossary.all.first { $0.id == "adobe-creative-cloud" }
        XCTAssertEqual(entry?.bundleIdentifiers.first, "com.adobe.CreativeCloud")
    }

    // MARK: - The person describes the symptom instead of the name

    func testSymptomPhrasesMatch() {
        XCTAssertEqual(topEntry("fan loud")?.id, "windowserver")
        XCTAssertEqual(topEntry("permission prompts")?.id, "tccd")
        // "many tabs" is honestly ambiguous — both browsers describe themselves
        // that way — so the useful property is that we surface a browser entry.
        let browsers = ["safari-web-content", "chrome-helper"]
        XCTAssertTrue(browsers.contains(topEntry("many tabs")?.id ?? ""))
    }

    func testLongSymptomPhraseStillFindsSomething() {
        XCTAssertNotNil(topEntry("high cpu after update"))
    }

    // MARK: - We admit when we don't know

    func testGibberishReturnsNothing() {
        XCTAssertTrue(ProcessGlossarySearch.search("zzqxyzzyplorf").isEmpty)
    }

    func testBestMatchReturnsNilRatherThanGuessing() {
        XCTAssertNil(ProcessGlossarySearch.bestMatch(forName: "zzqxyzzyplorf", bundleIdentifier: nil))
        XCTAssertNil(ProcessGlossarySearch.bestMatch(forName: "Something Completely Unknown", bundleIdentifier: nil))
    }

    func testBestMatchUsesTheExactEntryWhenAvailable() {
        XCTAssertEqual(
            ProcessGlossarySearch.bestMatch(forName: "kernel_task", bundleIdentifier: nil)?.id,
            "kernel_task"
        )
    }

    func testBestMatchPrefersBundleIdentifierOverName() {
        // The name alone is ambiguous, the bundle is not.
        let match = ProcessGlossarySearch.bestMatch(
            forName: "Web Content",
            bundleIdentifier: "com.apple.WebKit.WebContent"
        )
        XCTAssertEqual(match?.id, "safari-web-content")
    }

    // MARK: - Browse

    func testEmptyQueryReturnsEveryEntry() {
        XCTAssertEqual(
            ProcessGlossarySearch.search("").count,
            ProcessGlossary.all.count
        )
    }

    func testEntriesAreSortedAlphabeticallyWhenBrowsing() {
        let names = ProcessGlossarySearch.search("").map(\.entry.name)
        XCTAssertEqual(names, names.sorted())
    }

    // MARK: - Edit distance

    func testBoundedDistanceHandlesTypos() {
        XCTAssertEqual(ProcessGlossarySearch.boundedDistance("kitten", "sitten", limit: 2), 1)
        XCTAssertEqual(ProcessGlossarySearch.boundedDistance("kitten", "kiten", limit: 2), 1)
        XCTAssertEqual(ProcessGlossarySearch.boundedDistance("kitten", "kitten", limit: 2), 0)
    }

    func testBoundedDistanceCountsTranspositionAsOneEdit() {
        XCTAssertEqual(ProcessGlossarySearch.boundedDistance("windows", "widnows", limit: 2), 1)
    }

    func testBoundedDistanceReturnsNilPastTheLimit() {
        XCTAssertNil(ProcessGlossarySearch.boundedDistance("kitten", "sitting", limit: 1))
        XCTAssertNil(ProcessGlossarySearch.boundedDistance("a", "zzzzzzzzzz", limit: 2))
    }
}
