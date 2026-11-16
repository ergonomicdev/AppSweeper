import XCTest
@testable import AppSweeperCore

final class TrasherTests: XCTestCase {
    func testPermissionErrorClassification() {
        XCTAssertTrue(Trasher.isPermissionError(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)))
        XCTAssertTrue(Trasher.isPermissionError(NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))))
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError,
                              userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))])
        XCTAssertTrue(Trasher.isPermissionError(wrapped))
        XCTAssertFalse(Trasher.isPermissionError(NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)))
    }

    func testExistsTreatsDanglingSymlinkAsPresent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let link = dir.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "/nonexistent/\(UUID())")
        XCTAssertTrue(Trasher.exists(link, fileManager: .default))
        XCTAssertFalse(Trasher.exists(dir.appendingPathComponent("missing"), fileManager: .default))
    }
}
