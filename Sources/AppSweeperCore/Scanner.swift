import Foundation

public struct FoundItem: Identifiable, Equatable {
    public var id: URL { url }
    public let url: URL
    public let kind: String
    public let size: Int64
    public let requiresAdmin: Bool
    public let isAppBundle: Bool
}

public enum Scanner {
    /// Finds the app bundle and related files. Does not modify anything.
    public static func scan(app: AppInfo,
                            locations: [SearchLocation] = SearchLocation.standard(),
                            fileManager: FileManager = .default) -> [FoundItem] {
        var items: [FoundItem] = [
            FoundItem(url: app.url, kind: "Application", size: size(of: app.url, fileManager: fileManager),
                      requiresAdmin: !fileManager.isDeletableFile(atPath: app.url.path), isAppBundle: true)
        ]
        for location in locations {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: location.url, includingPropertiesForKeys: nil, options: []) else { continue }
            for entry in entries where Matcher.matches(entryName: entry.lastPathComponent, kind: location.kind, app: app) {
                items.append(FoundItem(
                    url: entry,
                    kind: location.isSystemWide ? "/Library · \(location.kind.rawValue)" : location.kind.rawValue,
                    size: size(of: entry, fileManager: fileManager),
                    requiresAdmin: location.isSystemWide || !fileManager.isDeletableFile(atPath: entry.path),
                    isAppBundle: false))
            }
        }
        return items
    }

    public static func size(of url: URL, fileManager: FileManager = .default) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            return Int64((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
        }
        var total: Int64 = 0
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        if let e = fileManager.enumerator(at: url, includingPropertiesForKeys: keys) {
            for case let f as URL in e {
                let v = try? f.resourceValues(forKeys: Set(keys))
                if v?.isRegularFile == true { total += Int64(v?.totalFileAllocatedSize ?? 0) }
            }
        }
        return total
    }
}

public struct TrashResult {
    public var trashed: [URL] = []
    public var failed: [(URL, String)] = []
    /// True if any failure looks like a permission problem (suggest Full Disk Access).
    public var permissionDenied = false
}

public enum Trasher {
    /// Moves items to the Trash. Items needing privileges are moved via an admin prompt (AppleScript).
    public static func trash(_ items: [FoundItem], app: AppInfo,
                             fileManager: FileManager = .default) -> TrashResult {
        var result = TrashResult()
        // Re-check protection immediately before deleting.
        if Protection.reason(for: app) != nil {
            result.failed = items.map { ($0.url, "Protected application") }
            return result
        }
        var needAdmin: [URL] = []
        for item in items {
            if item.url.path.hasPrefix("/System/") || item.url.lastPathComponent.lowercased().hasPrefix("com.apple.") {
                result.failed.append((item.url, "Protected item"))
                continue
            }
            if item.requiresAdmin { needAdmin.append(item.url); continue }
            do {
                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                result.trashed.append(item.url)
            } catch {
                let ns = error as NSError
                let denied = (ns.domain == NSCocoaErrorDomain
                              && (ns.code == NSFileWriteNoPermissionError || ns.code == NSFileReadNoPermissionError))
                    || (ns.domain == NSPOSIXErrorDomain && (ns.code == Int(EPERM) || ns.code == Int(EACCES)))
                if denied {
                    result.permissionDenied = true
                    needAdmin.append(item.url)
                } else {
                    result.failed.append((item.url, error.localizedDescription))
                }
            }
        }
        if !needAdmin.isEmpty { trashWithAdmin(needAdmin, into: &result) }
        return result
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Moves files into the current user's ~/.Trash with administrator privileges.
    static func trashWithAdmin(_ urls: [URL], into result: inout TrashResult) {
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path
        let stamp = Int(Date().timeIntervalSince1970)
        let user = NSUserName()
        var cmds: [String] = []
        for (i, url) in urls.enumerated() {
            let dest = "\(trash)/\(url.lastPathComponent) \(stamp)-\(i)"
            cmds.append("/bin/mv \(shellQuote(url.path)) \(shellQuote(dest)) && /usr/sbin/chown -R \(shellQuote(user)) \(shellQuote(dest))")
        }
        let script = "do shell script \"\(escape(cmds.joined(separator: "; ")))\" with administrator privileges"
        var error: NSDictionary?
        _ = NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error = error {
            let msg = (error[NSAppleScript.errorMessage] as? String) ?? "Administrator action failed"
            for u in urls { result.failed.append((u, msg)) }
        } else {
            result.trashed.append(contentsOf: urls)
        }
    }

    static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
