# Working on everyDock

## Start here

1. Read [HANDOFF.md](HANDOFF.md) for the last working state and outstanding checks.
2. Check `git status --short`, `git log -5 --oneline`, and the diff before editing. Preserve existing work. Fetch and compare the remote before pushing; the owner also edits README on GitHub.
3. Follow the relevant entry points below and the requirements/test IDs in [docs/README.md](docs/README.md). Read only the documents and code needed for the task.
4. Treat handoff facts as dated evidence. Verify the current checkout, installed app, release, and permissions when the task depends on them.

## Project and source map

Apple Silicon only, macOS 26+, Swift 6.2+ / Xcode 26+. AppKit application with SwiftUI settings; no external Swift package dependencies. Bundle ID: `app.everydock.mac`.

Paths below are relative to `Sources/EveryDock/` unless prefixed otherwise.

| Task | Start with |
|---|---|
| Startup, settings, login, language | `EveryDockApp.swift`, `AppModel.swift`, `SettingsView.swift`, `OnboardingView.swift`; `Sources/DockCore/Localization.swift`, `Sources/DockCore/KoreanStrings.swift` |
| Display lifecycle / automatic pause | `DockPanel.swift`, `AppModel.swift`; `Sources/DockCore/DockActivity.swift` |
| Icons, magnification, hold/drag, separators | `DockSurface.swift`, `DockArtwork.swift`; `Sources/DockCore/DockReordering.swift`, `Sources/DockCore/DockLayout.swift` |
| Native Dock pin synchronization | `AppModel.swift`, `NativeDockPinSync.swift`; `Sources/DockCore/NativeDockPins.swift` |
| Native Dock appearance / recovery | `NativeDockManager.swift`, `NativeDockStyle.swift`; `Sources/DockCore/NativeDockSnapshot.swift` |
| App-provided menus / tooltips | `NativeDockMenu.swift`, `DockTooltip.swift`; `Sources/DockCore/DockMenuPlacement.swift` |
| Permissions / previews / window actions | `AppPermissions.swift`, `WindowPreview.swift`, `WindowActions.swift`; `Tests/EveryDockTests/CaptureConsentTests.swift` |
| Shift-click new window | `DockSurface.swift` (`appClicked`), `AppModel.swift` (`openNewWindow`), `WindowActions.swift` (`newWindow`); `Sources/DockCore/NewWindowCommand.swift` |
| Update check / update window | `UpdateController.swift`, `UpdateView.swift`, `EveryDockApp.swift` menus; `Sources/DockCore/UpdateCheck.swift`, `Tests/DockCoreTests/UpdateCheckTests.swift` |
| Window zoom and restoration | `WindowWorkAreaController.swift`, `WindowRestoreClock.swift`; `Sources/DockCore/WindowZoomState.swift` |
| Spotlight Apps / folder stacks | `DockUtilities.swift`, `ApplicationCatalog.swift`; `Tests/EveryDockTests/FolderPresentationTests.swift` |
| Removal and preference migration | `UninstallCleanup.swift`; `Sources/DockCore/PreferenceReset.swift`, `Sources/DockCore/DockLayout.swift` |
| Version, packaging, distribution | `Resources/Info.plist`, `scripts/`, `.github/workflows/ci.yml`, [docs/RELEASING.md](docs/RELEASING.md) |

## Working rules

- Keep code and documentation in the same change. Behavior, architecture, performance, permission, and distribution changes require the relevant PRD/SRS/TC and README updates. If a requirement changes, reconcile implementation and tests. Documentation-only factual/handoff updates do not require artificial code changes.
- Preserve requirement and test IDs. Record only checks actually executed as PASS; retain NOT RUN/PARTIAL and historical release evidence. A version number or implementation is not evidence of device behavior or measured performance.
- Keep current product documentation in English. Update both English source strings and the Korean catalog for app-owned UI text. Preserve storage identifiers and external app/file/window names.
- Use `uv` for any Python environment and dependencies. Python is not required for the normal Swift workflow.
- Do not commit user preferences, recovery journals, TCC databases, signing keys, credentials, captured windows, or private files. Use isolated preference domains and disposable fixtures for tests.
- Avoid repeating synchronous app enumeration or file IO in input/render paths. Use display-synchronized animation and cached artwork; record real measurements for performance claims.
- Distinguish permission denial, app path/signature mismatch, API errors, unsupported windows, and empty window lists. Background work must not request Screen Recording access. Request buttons must not also open System Settings automatically.
- Diagnose permissions against the actual running bundle. Do not reset TCC or the user's settings as routine debugging. Normal quit must precede replacing a running app so native Dock recovery can complete.
- Preserve bidirectional native pin synchronization, local separators, and unrelated native Dock preferences. Native imports must not echo writes or restart the Dock. See FR-33 and its regression tests before changing this path.
- Keep automatic-pause recovery event-driven; do not reintroduce recurring Dock work while inactive. The active native pin check belongs to existing reconciliation.
- Do not silently change ownership/license terms. Apache-2.0's patent grant applies; NOTICE retains ownership without asserting that a patent exists.

## Build and validation

Run from the repository root on the supported Mac toolchain:

```bash
swift test --arch arm64
EVERYDOCK_RUN_QL_TEST=1 swift test --arch arm64
```

The second command includes the real Quick Look integration. Choose relevant checks for the change; avoid repeating a successful full suite without a new reason. Tests involving AppKit/Quick Look require a suitable macOS environment. They do not replace physical multi-display or permission-dialog checks.

Build a development app in a separate output directory:

```bash
EVERYDOCK_OUTPUT_DIR="$PWD/.build/dev-app" ./scripts/build.sh debug
```

The default build output is `dist/everyDock.app`; do not overwrite it while that copy is running. Launch one intended bundle at a time. Installing or rebuilding an ad-hoc signed app can invalidate existing permission registration. Use the final release bundle for release-device validation.

For documentation-only changes, check links, facts against source, and `git diff --check`; do not rebuild or replace the user's app unnecessarily. For release packaging, follow [docs/RELEASING.md](docs/RELEASING.md). The package script stages separately and verifies architecture, signature, and LICENSE/NOTICE copies.

## Distribution and finishing work

- GitHub Actions tests and packages pushes to `main` and PRs; it uploads a workflow artifact. It does **not** create a GitHub Release or update Homebrew automatically.
- Releases and the separate `hungryZoo/homebrew-tap` repository are explicit publication steps. Follow the user's current authorization; a handoff is not a request to publish another release.
- Bump version/build for a new binary release. Never overwrite a published tag or asset. Verify the public ZIP/checksum before updating the cask.
- Preserve the Homebrew removal-versus-upgrade distinction: upgrade keeps settings; uninstall/reinstall resets them. Do not test preservation with `brew reinstall`. Keep unfinished native Dock recovery journals.
- The cask currently needs an explicit `Cask/InstallSteps` style exception for its runtime uninstall hook. Do not report that as an unrestricted style or notarization pass; see the release procedure before altering it.
- At the end of substantive work, update HANDOFF with the current state, executed verification, remaining uncertainties, and next steps. Keep stable rules here and changing state in HANDOFF; avoid copying the entire conversation or duplicating specs.
