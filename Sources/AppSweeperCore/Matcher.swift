import Foundation

public enum LocationKind: String, CaseIterable {
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case preferences = "Preferences"
    case containers = "Containers"
    case groupContainers = "Group Containers"
    case logs = "Logs"
    case savedState = "Saved Application State"
    case launchAgents = "LaunchAgents"
    case launchDaemons = "LaunchDaemons"
    case webKit = "WebKit"
    case httpStorages = "HTTPStorages"
    case cookies = "Cookies"

    /// Whether entries may also be matched by exact app name (not just bundle id).
    var allowsNameMatch: Bool {
        switch self {
        case .applicationSupport, .caches, .logs: return true
        default: return false
        }
    }
}

public struct SearchLocation: Equatable {
    public let url: URL
    public let kind: LocationKind
    public let isSystemWide: Bool

    public init(url: URL, kind: LocationKind, isSystemWide: Bool) {
        self.url = url
        self.kind = kind
        self.isSystemWide = isSystemWide
    }

    public static func standard(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [SearchLocation] {
        let userLib = home.appendingPathComponent("Library")
        let sysLib = URL(fileURLWithPath: "/Library")
        var result: [SearchLocation] = []
        let userKinds: [LocationKind] = [.applicationSupport, .caches, .preferences, .containers,
                                         .groupContainers, .logs, .savedState, .launchAgents,
                                         .webKit, .httpStorages, .cookies]
        for kind in userKinds {
            result.append(SearchLocation(url: userLib.appendingPathComponent(kind.rawValue), kind: kind, isSystemWide: false))
        }
        let sysKinds: [LocationKind] = [.applicationSupport, .caches, .preferences, .logs,
                                        .launchAgents, .launchDaemons]
        for kind in sysKinds {
            result.append(SearchLocation(url: sysLib.appendingPathComponent(kind.rawValue), kind: kind, isSystemWide: true))
        }
        return result
    }
}

public enum Matcher {
    private static let knownSuffixes = [".plist", ".savedstate", ".binarycookies", ".lockfile", ".log", ".helper"]

    /// Names too generic to match by name alone.
    static let genericNames: Set<String> = [
        "app", "apple", "system", "library", "google", "microsoft", "adobe", "cache", "caches",
        "data", "logs", "preferences", "support", "default", "common", "shared", "temp", "tmp",
        "helper", "launcher", "updater", "installer", "mozilla", "java", "python", "node"
    ]

    static func strip(_ name: String) -> String {
        var s = name.lowercased()
        var changed = true
        while changed {
            changed = false
            for suffix in knownSuffixes where s.hasSuffix(suffix) && s.count > suffix.count {
                s.removeLast(suffix.count)
                changed = true
            }
        }
        return s
    }

    /// Removes a Group Container team prefix (e.g. "ABCDE12345.") or "group." prefix.
    static func stripGroupPrefix(_ s: String) -> String {
        var result = s
        if result.hasPrefix("group.") {
            result.removeFirst(6)
        } else if let dot = result.firstIndex(of: "."),
                  result.distance(from: result.startIndex, to: dot) == 10,
                  result[result.startIndex..<dot].allSatisfy({ $0.isLetter || $0.isNumber }) {
            let rest = result[result.index(after: dot)...]
            if rest.contains(".") { result = String(rest) }
        }
        if result.hasPrefix("group.") { result.removeFirst(6) }
        return result
    }

    static func isUsableBundleID(_ id: String?) -> Bool {
        guard let id = id?.lowercased(), id.count >= 5, id.contains("."), !id.hasPrefix("com.apple.") else { return false }
        return true
    }

    /// Decides whether a top-level entry (file or folder name) in a given location belongs to the app.
    public static func matches(entryName: String, kind: LocationKind, app: AppInfo) -> Bool {
        var stripped = strip(entryName)
        if stripped.hasPrefix("com.apple.") { return false }
        if kind == .groupContainers { stripped = stripGroupPrefix(stripped) }

        if isUsableBundleID(app.bundleID), let bid = app.bundleID?.lowercased() {
            if stripped == bid || stripped.hasPrefix(bid + ".") { return true }
        }

        if kind.allowsNameMatch {
            for candidate in app.candidateNames {
                let n = candidate.lowercased()
                if n.count >= 4, !genericNames.contains(n), stripped == n { return true }
            }
        }
        return false
    }
}
