import XCTest
@testable import AppSweeperCore

final class MatcherTests: XCTestCase {
    let app = AppInfo(url: URL(fileURLWithPath: "/Applications/Foo Bar.app"), name: "Foo Bar", bundleID: "com.acme.foobar")

    func m(_ n: String, _ k: LocationKind) -> Bool { Matcher.matches(entryName: n, kind: k, app: app) }

    func testBundleIDMatches() {
        XCTAssertTrue(m("com.acme.foobar", .containers))
        XCTAssertTrue(m("com.acme.foobar.plist", .preferences))
        XCTAssertTrue(m("com.acme.foobar.helper.plist", .launchAgents))
        XCTAssertTrue(m("com.acme.foobar.savedState", .savedState))
        XCTAssertTrue(m("COM.ACME.FOOBAR", .caches))
        XCTAssertTrue(m("com.acme.foobar.binarycookies", .cookies))
    }

    func testDoesNotMatchSimilarIDs() {
        XCTAssertFalse(m("com.acme.foobarbaz", .containers))
        XCTAssertFalse(m("com.acme.foo", .containers))
        XCTAssertFalse(m("com.other.foobar", .preferences))
    }

    func testNameMatchOnlyInAllowedLocationsAndExact() {
        XCTAssertTrue(m("Foo Bar", .applicationSupport))
        XCTAssertTrue(m("foo bar", .caches))
        XCTAssertFalse(m("Foo Bar", .preferences))
        XCTAssertFalse(m("Foo Bar Extras", .applicationSupport))
        XCTAssertFalse(m("Foo", .applicationSupport))
    }

    func testGroupContainerPrefixes() {
        XCTAssertTrue(m("ABCDE12345.com.acme.foobar", .groupContainers))
        XCTAssertTrue(m("group.com.acme.foobar", .groupContainers))
        XCTAssertFalse(m("ABCDE12345.com.acme.other", .groupContainers))
    }

    func testAppleEntriesNeverMatch() {
        let apple = AppInfo(url: URL(fileURLWithPath: "/Applications/Safari.app"), name: "Safari", bundleID: "com.apple.Safari")
        XCTAssertFalse(Matcher.matches(entryName: "com.apple.Safari", kind: .containers, app: apple))
        XCTAssertFalse(Matcher.matches(entryName: "com.apple.Safari.plist", kind: .preferences, app: apple))
    }

    func testGenericOrShortNamesDoNotMatch() {
        let generic = AppInfo(url: URL(fileURLWithPath: "/Applications/Java.app"), name: "Java", bundleID: nil)
        XCTAssertFalse(Matcher.matches(entryName: "Java", kind: .applicationSupport, app: generic))
        let short = AppInfo(url: URL(fileURLWithPath: "/Applications/Go.app"), name: "Go", bundleID: "go")
        XCTAssertFalse(Matcher.matches(entryName: "Go", kind: .applicationSupport, app: short))
        XCTAssertFalse(Matcher.matches(entryName: "go.plist", kind: .preferences, app: short))
    }

    func testProtection() {
        let sys = AppInfo(url: URL(fileURLWithPath: "/System/Applications/Notes.app"), name: "Notes", bundleID: "com.apple.Notes")
        XCTAssertNotNil(Protection.reason(for: sys, ownBundleID: nil))
        let apple = AppInfo(url: URL(fileURLWithPath: "/Applications/Xcode.app"), name: "Xcode", bundleID: "com.apple.dt.Xcode")
        XCTAssertNotNil(Protection.reason(for: apple, ownBundleID: nil))
        XCTAssertNil(Protection.reason(for: app, ownBundleID: nil))
    }

    func testScannerFindsOnlyMatchesInTempLibrary() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let prefs = root.appendingPathComponent("Preferences")
        try fm.createDirectory(at: prefs, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: prefs.appendingPathComponent("com.acme.foobar.plist"))
        try Data("x".utf8).write(to: prefs.appendingPathComponent("com.acme.other.plist"))
        let loc = SearchLocation(url: prefs, kind: .preferences, isSystemWide: false)
        let found = Scanner.scan(app: app, locations: [loc])
        XCTAssertEqual(found.filter { !$0.isAppBundle }.map { $0.url.lastPathComponent }, ["com.acme.foobar.plist"])
    }
}
