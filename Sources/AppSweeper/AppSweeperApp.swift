import SwiftUI
import AppKit
import AppSweeperCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct AppSweeperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Needed when launched via `swift run` (no app bundle).
        NSApplication.shared.setActivationPolicy(.regular)
        #if SWIFT_PACKAGE
        // Plain SwiftPM executable has no app bundle icon; the Xcode app target uses AppIcon.icns instead.
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
        #endif
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("AppSweeper") {
            ContentView().frame(minWidth: 620, minHeight: 520)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About AppSweeper") { AboutPanel.show() }
            }
        }
    }
}

enum AboutPanel {
    static func show() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        let credits = NSMutableAttributedString(
            string: """
            Uninstall apps completely. AppSweeper finds an app's leftover files in ~/Library and /Library, \
            lets you review them, and moves only what you select to the Trash.

            It never touches system apps or Apple-owned items. Open source under the MIT License.
            """,
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor])
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "AppSweeper",
            .applicationVersion: version,
            .version: build,
            .credits: credits,
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "Copyright © 2026 ergonomicdev"
        ])
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@MainActor
final class ViewModel: ObservableObject {
    @Published var app: AppInfo?
    @Published var items: [FoundItem] = []
    @Published var selected: Set<URL> = []
    @Published var scanning = false
    @Published var message: String?
    @Published var showFullDiskHelp = false
    // Kept here instead of @State so the app compiles without the SwiftUI macro plugin (Command Line Tools).
    @Published var picking = false
    @Published var targeted = false

    var selectedSize: Int64 { items.filter { selected.contains($0.url) }.map(\.size).reduce(0, +) }

    func load(_ url: URL) {
        message = nil
        guard let info = AppInfo.load(from: url) else {
            message = "That is not an application (.app) bundle."
            return
        }
        if let reason = Protection.reason(for: info) {
            app = nil; items = []; selected = []
            message = "\(info.name) can't be uninstalled: \(reason)."
            return
        }
        app = info
        scanning = true
        Task {
            let found = await Task.detached { Scanner.scan(app: info) }.value
            items = found
            selected = Set(found.map(\.url))
            scanning = false
        }
    }

    func uninstall() {
        guard let app else { return }
        let chosen = items.filter { selected.contains($0.url) }
        Task {
            let result = await Task.detached { Trasher.trash(chosen, app: app) }.value
            let done = Set(result.trashed)
            items.removeAll { done.contains($0.url) }
            selected.subtract(done)
            if result.failed.isEmpty {
                message = "Moved \(result.trashed.count) item(s) to the Trash."
            } else {
                message = "Moved \(result.trashed.count) item(s); \(result.failed.count) failed: "
                    + result.failed.prefix(3).map { "\($0.0.lastPathComponent) (\($0.1))" }.joined(separator: ", ")
            }
            if result.permissionDenied { showFullDiskHelp = true }
        }
    }
}

struct ContentView: View {
    @StateObject private var vm = ViewModel()

    var body: some View {
        VStack(spacing: 12) {
            if let app = vm.app {
                header(app)
                if vm.scanning {
                    ProgressView("Scanning…").frame(maxHeight: .infinity)
                } else {
                    list
                    footer
                }
            } else {
                dropZone
            }
            if let m = vm.message { Text(m).font(.callout).foregroundStyle(.secondary) }
        }
        .padding()
        .onDrop(of: [.fileURL], isTargeted: $vm.targeted) { providers in
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in vm.load(url) } }
            }
            return true
        }
        .fileImporter(isPresented: $vm.picking, allowedContentTypes: [.applicationBundle]) { r in
            if case .success(let url) = r { vm.load(url) }
        }
        .alert("Permission needed", isPresented: $vm.showFullDiskHelp) {
            Button("Open Full Disk Access Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("macOS blocked removing some items. Grant AppSweeper Full Disk Access in System Settings › Privacy & Security, then quit and reopen AppSweeper. If it's already enabled, remove AppSweeper from the list (−) and add it again: macOS ties the permission to the exact build, so it stops applying after an update.")
        }
    }

    var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash.circle").font(.system(size: 56))
            Text("Drop an app here to uninstall it").font(.title3)
            Button("Choose App…") { vm.picking = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
            .foregroundStyle(vm.targeted ? Color.accentColor : Color.secondary))
    }

    func header(_ app: AppInfo) -> some View {
        HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path)).resizable().frame(width: 40, height: 40)
            VStack(alignment: .leading) {
                Text(app.name).font(.headline)
                Text(app.bundleID ?? "").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Choose Another…") { vm.picking = true }
        }
    }

    var list: some View {
        List(vm.items) { item in
            Toggle(isOn: Binding(
                get: { vm.selected.contains(item.url) },
                set: { on in if on { vm.selected.insert(item.url) } else { vm.selected.remove(item.url) } })) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.url.lastPathComponent)
                        Text("\(item.kind) — \(item.url.deletingLastPathComponent().path)")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    if item.requiresAdmin { Image(systemName: "lock").help("Requires administrator password") }
                    Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)).monospacedDigit()
                }
            }
        }
    }

    var footer: some View {
        HStack {
            Text("\(vm.selected.count) of \(vm.items.count) selected · \(ByteCountFormatter.string(fromByteCount: vm.selectedSize, countStyle: .file))")
            Spacer()
            Button("Move to Trash", role: .destructive) { vm.uninstall() }
                .disabled(vm.selected.isEmpty)
        }
    }
}
