# AppSweeper

A small, native SwiftUI app for macOS that uninstalls an application **together with its leftover files**, in the spirit of AppCleaner. Everything goes to the **Trash**, never a permanent delete, and you choose exactly what to remove.

> **Use at your own risk.** AppSweeper deletes files. It is conservative by design (see [Safety](#safety)) and always moves items to the Trash so you can restore them, but it is provided without warranty (see [LICENSE](LICENSE)).

## Features

- Drag an `.app` onto the window, or use **Choose App…**
- Scans `~/Library` and `/Library` for files that belong to the app (by bundle identifier and exact app name)
- Checklist with sizes; deselect anything you want to keep
- Moves selected items to the Trash; asks for an administrator password only for items that need it
- Guides you to Full Disk Access when macOS blocks removal
- Refuses system apps and Apple-owned bundle IDs

## Requirements

- macOS 13 or later
- Xcode 15 or later (full Xcode, not only Command Line Tools, for running tests)

## Install

### Option 1: Homebrew (recommended)

```sh
brew install --cask ergonomicdev/tap/appsweeper
```

The cask removes the quarantine flag for you, because the app is not notarized (see Option 2).

### Option 2: download

1. Download `AppSweeper-<version>.dmg` from the [Releases](../../releases) page.
2. Open it and drag **AppSweeper** into **Applications**.
3. First launch: the app is ad-hoc signed, not notarized, so macOS Gatekeeper will block a plain double-click. **Right-click AppSweeper → Open → Open** once. If macOS still refuses, run `xattr -dr com.apple.quarantine /Applications/AppSweeper.app`.

The build is universal (Apple Silicon and Intel) and needs macOS 13 or later.

### Option 3: build from source

```sh
git clone https://github.com/ergonomicdev/AppSweeper.git && cd AppSweeper
make install     # builds a Release app and copies it to /Applications
```

Requires Xcode 15+. `make dmg` produces `dist/AppSweeper-<version>.dmg` and a `.zip` without installing.

### Permissions

For app data protected by macOS (Containers, Group Containers, Cookies, etc.), grant AppSweeper **Full Disk Access** in System Settings › Privacy & Security. AppSweeper shows this guidance when a removal is blocked. Items in `/Library` ask for your administrator password.

## Quick start (development)

```sh
git clone https://github.com/ergonomicdev/AppSweeper.git && cd AppSweeper
make run      # or: swift run AppSweeper
make test     # or: swift test
```

`make help` lists all shortcuts. The Makefile uses `/Applications/Xcode.app` automatically if your selected developer directory isn't a full Xcode.

## Development

### VS Code

1. Install Xcode and the recommended extensions (VS Code will prompt: *Swift*, *EditorConfig*).
2. Open the folder. Use **Run and Debug → Debug AppSweeper** (builds and launches with LLDB), or the **Run tests** task (`Terminal → Run Test Task`).

Notes:
- The app avoids SwiftUI macros such as `@State`, so it also builds with Command Line Tools alone. Tests need Xcode's XCTest: run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, or just use `make test`.
- Don't point the Swift extension's `swift.path` at Xcode's toolchain: it has no `lldb-dap`, so debugging fails.
- A harmless `ld: warning: search path '/Library/Developer/CommandLineTools/...' not found` appears when building with Command Line Tools only; selecting Xcode (above) removes it.

### Xcode

Open `AppSweeper.xcodeproj` (not the folder), choose the `AppSweeper` scheme → My Mac, and Run. This builds a real `.app` bundle with Info.plist and icon. The project is generated from `project.yml`; after changing it, run `make project` (requires [XcodeGen](https://github.com/yonaskolb/XcodeGen), `brew install xcodegen`). The bundle identifier `dev.appsweeper.AppSweeper` in `project.yml` is a placeholder: change it if you distribute your own build.

### Project layout

| Path | Purpose |
| --- | --- |
| `Sources/AppSweeperCore` | Matching, scanning, protection and trashing logic (no UI) |
| `Sources/AppSweeper` | SwiftUI app |
| `Sources/appsweeper-scan` | Read-only command-line scanner for debugging |
| `Tests/AppSweeperCoreTests` | Unit tests for matching, protection and scanning |
| `Tools/` | Icon generator, release packaging script, dummy test-app script |
| `Assets/` | Generated app icon (`.icns`, iconset, preview) |

### Testing with a dummy app

`Tools/make-test-app.sh` builds a harmless ad-hoc-signed `SweepTestDummy.app` (bundle id `com.example.sweeptestdummy`) and creates matching leftovers in `~/Library` (Application Support, Caches, Preferences, Containers, Group Containers, Logs, Saved Application State, LaunchAgents, WebKit, HTTPStorages, Cookies).

```sh
Tools/make-test-app.sh create [--system]   # app goes to ~/Desktop (or DEST=dir); --system adds /Library items via sudo
make scan APP=~/Desktop/SweepTestDummy.app # prints what AppSweeper would find (read-only)
make run                                   # drop the dummy app in and uninstall it
Tools/make-test-app.sh verify [--system]   # lists leftovers still present (exit 1 if any)
Tools/make-test-app.sh clean [--system]    # manual cleanup
```

The script only touches paths containing the dummy bundle id or name. Group Containers, Cookies and Containers are privacy-protected: without Full Disk Access for your terminal, the first two are skipped with a warning, and a created Container can only be removed by an app with Full Disk Access (e.g. AppSweeper itself).

### Icon

`make icon` (`swift Tools/GenerateIcon.swift`) regenerates `Assets/AppIcon.icns`, the iconset and the runtime Dock icon (`Sources/AppSweeper/Resources/AppIcon.png`).

## What is scanned

`~/Library` and `/Library`: Application Support, Caches, Preferences, Logs, LaunchAgents (plus LaunchDaemons in `/Library`). `~/Library` only: Containers, Group Containers, Saved Application State, WebKit, HTTPStorages, Cookies.

## Safety

- Matching is conservative: entries must equal the bundle ID or start with `<bundle id>.`; exact app-name matches are used only in Application Support, Caches and Logs, and never for short or generic names.
- System apps (`/System`), `com.apple.*` bundle IDs, apps without a bundle ID, and AppSweeper itself are refused.
- Items needing privileges (e.g. `/Library`) trigger an administrator password prompt. If removal fails due to permissions, the app points you to Full Disk Access in System Settings › Privacy & Security.

## Releasing

Bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION`) in `project.yml`, run `make project`, commit, then push a tag such as `v1.0.0`. The Release workflow runs the tests, builds the universal app, and attaches the `.dmg` and `.zip` to a GitHub release. To make downloads open without the Gatekeeper warning you would need an Apple Developer ID signature and notarization, which aren't configured.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
