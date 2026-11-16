# Contributing

Thanks for helping! AppSweeper deletes user files, so changes to matching or removal logic need extra care.

## Setup

See the [README](README.md#development). In short: install Xcode, then `make test`.

## Guidelines

- **Be conservative.** A false negative (leftover file) is acceptable; a false positive (deleting something unrelated) is not. Any change to `Matcher`, `Protection` or `Trasher` needs unit tests in `Tests/AppSweeperCoreTests`, including cases that must *not* match.
- Never add permanent deletion. Items must go to the Trash.
- Never touch system apps or `com.apple.*` items.
- Keep the UI free of SwiftUI macros like `@State` if practical, so the project builds with Command Line Tools.
- Don't edit `AppSweeper.xcodeproj` by hand: edit `project.yml` and run `make project`.
- Keep tests free of real user data: use temporary directories or the dummy app (`Tools/make-test-app.sh`).

## Pull requests

1. Fork and create a branch.
2. Run `make test` (CI also runs `swift build`, `swift test` and an `xcodebuild` build).
3. Describe what changed and how you tested it, especially anything that affects what gets removed.

By contributing you agree your work is released under the [MIT License](LICENSE).
