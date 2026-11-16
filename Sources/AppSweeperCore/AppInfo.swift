import Foundation

public struct AppInfo: Equatable {
    public let url: URL
    public let name: String
    public let bundleID: String?

    public init(url: URL, name: String, bundleID: String?) {
        self.url = url
        self.name = name
        self.bundleID = bundleID
    }

    /// Reads name and bundle identifier from an .app bundle. Returns nil if it is not an app bundle.
    public static func load(from url: URL) -> AppInfo? {
        guard url.pathExtension.lowercased() == "app" else { return nil }
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        let plist = (NSDictionary(contentsOf: plistURL) as? [String: Any]) ?? [:]
        let fileName = url.deletingPathExtension().lastPathComponent
        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? fileName
        return AppInfo(url: url, name: name, bundleID: plist["CFBundleIdentifier"] as? String)
    }

    /// Names that may be used for exact-name matching (file name and display name).
    public var candidateNames: [String] {
        let fileName = url.deletingPathExtension().lastPathComponent
        var result = [fileName]
        if name != fileName { result.append(name) }
        return result
    }
}

public enum Protection {
    /// Returns a human-readable reason if the app must never be uninstalled.
    public static func reason(for app: AppInfo, ownBundleID: String? = Bundle.main.bundleIdentifier) -> String? {
        let path = app.url.resolvingSymlinksInPath().path
        if path.hasPrefix("/System/") { return "System application" }
        if let id = app.bundleID?.lowercased() {
            if id.hasPrefix("com.apple.") || id == "com.apple" { return "Apple-owned application" }
            if let own = ownBundleID?.lowercased(), own == id { return "This is AppSweeper itself" }
        }
        if app.bundleID == nil || app.bundleID?.isEmpty == true {
            return "Missing bundle identifier"
        }
        return nil
    }
}
