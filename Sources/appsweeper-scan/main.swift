import Foundation
import AppSweeperCore

// Usage: appsweeper-scan /path/to/App.app  — prints what AppSweeper would find (no changes made).
guard CommandLine.arguments.count == 2, let app = AppInfo.load(from: URL(fileURLWithPath: CommandLine.arguments[1])) else {
    FileHandle.standardError.write(Data("usage: appsweeper-scan /path/to/App.app\n".utf8))
    exit(2)
}
if let reason = Protection.reason(for: app, ownBundleID: nil) {
    print("PROTECTED: \(reason)")
    exit(3)
}
for item in Scanner.scan(app: app) {
    print("\(item.kind)\t\(item.size)\t\(item.url.path)")
}
