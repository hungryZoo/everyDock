# everyDock handoff

Updated: **2026-10-27**. **v1.1.1 (build 21) is published** as the regular/latest release, and the Homebrew tap is updated. 1.1.1 fixes the update window Yes deadlock found in 1.1.0; everything else below shipped in 1.1.0. The owner asked for the 1.1.0 release without waiting for the in-app manual checks. 1.1.0 shipped Shift-click new windows, the update check, and the blank-icon fix below. Evidence is in [QA-v1.1.0](docs/QA-v1.1.0.md).

- **Shift-click new window (FR-34, P-11).** `AppModel.openNewWindow` activates a running app without a reopen event, then `WindowActions.newWindow` presses one AX menu item chosen by `NewWindowCommand.rank`: enabled, character N, a window word in the title, Command-N preferred over Shift-Command-N. Plain Command-N was rejected after probing real apps: Calendar would create an event, Cursor a text file, and Codex a chat. Apps without a match only activate, with a beep. Stopped apps launch normally.
- **Update check and window (FR-35, P-12)** following the owner’s `macos-app-update-check` skill (agents-dev-skills). Logic is in `DockCore/UpdateCheck.swift`, UI in `UpdateController.swift`/`UpdateView.swift`. It checks on launch and wake only, with no timer, at most once a day. Later waits for the next launch, such as after a restart; the owner chose this on 2026-10-27 over a 24-hour reminder. Preferences `checkForUpdates`/`skippedUpdateVersion` live in `DockPreferences`. The cache is `~/Library/Caches/app.everydock.mac/update-check.json`, which the existing cask zap/cleanup already cover, so no tap change is needed. Homebrew Yes runs a Terminal script that waits for everyDock’s normal quit, which completes Dock recovery, then runs `brew update` and `brew upgrade --cask hungryZoo/tap/everydock`. Menus and Settings have Check for Updates.
- **Verification (2026-10-27).** 76 tests passed, also with Quick Look; this covers TC-A69–78. TC-R11 PASS: live GitHub API fetch plus a fake-brew script run. An AX probe on 12 running apps behaved as intended, and a live press on Finder opened one window, which was then closed. The dev bundle `.build/dev-app/everyDock.app` was built but **not launched**, because the installed `/Applications/everyDock.app` (local 1.0.0 icon-fix build) was running and only one instance runs at a time. TC-M74–77 and TC-P05 are NOT RUN.
- **Release (2026-10-27).** Tag `v1.1.0` at `6d9092c`, [CI](https://github.com/hungryZoo/everyDock/actions/runs/40374260396) PASS, ZIP SHA-256 `2212b390c1e269941cd96f90e14219333704e16ee8a1d2250be2d1c1a3b8a292`, public download matched, `releases/latest` = v1.1.0. The body was published without its `# title` line. Tap commit `35b658e`; audit exit 0 and fetch passed.
- **Post-release check and 1.1.1 (2026-10-27).** The owner’s Mac was upgraded with the README Homebrew steps (1.0.0 → 1.1.0) and its settings were preserved. TC-M77 failed in 1.1.0: Yes in the update window deadlocks the quit because `NSApp.terminate` is called inside a main-actor Task. The fix (`UpdateController.outsideTask`), 1.1.1 build 21, release notes, and docs were prepared, then verified with a temporary Homebrew-located debug build before release.
- **Release 1.1.1 (2026-10-27).** Owner-approved. Tag `v1.1.1` at `739e74e`, [CI](https://github.com/hungryZoo/everyDock/actions/runs/40452516500) PASS, ZIP SHA-256 `f5ac7174028fb7bb1b21212c4152f2f4a317dcf63ff47528f4c3f5323a2f9a8f`, public download matched, `releases/latest` = v1.1.1. Tap commit `a0ff8a8`; style (with exception), audit, and fetch passed. The owner then upgraded the Mac to 1.1.1 directly; installed version, Homebrew record, preferences, and the update cache were confirmed afterward.
- **Shift-click on device (2026-10-27).** After the owner re-granted Accessibility, TC-M74 is PARTIAL on 1.1.1: Finder and Chrome opened one new window each, Calendar only activated, and stopped Safari launched normally.
- **Next.** Remaining TC-M74 cases (no-window Finder, Spotlight Apps, held Shift-press, denied permission), the remaining TC-M75/76 parts, and TC-P05.

Previous state (2026-09-23): development resumed for a reported blank-icon defect. The correction, now shipped in v1.1.0, adds invalid/transparent raster rejection, a visible fallback, bounded fresh-source retries, and cached-layer restoration. See FR-03 and TC-A65–68/TC-M73. No new release or push has been requested; v1.0.0 remains the published baseline.

The defect was visible in Settings, VMware Fusion, and NAVER Whale tiles while fresh NSWorkspace rendering worked. The missing recovery paths are covered by regression tests; the original OS/layer invalidation trigger remains unknown. All 66 automated tests (including Quick Look), release build, and signature verification passed. The local fix is running from `/Applications/everyDock.app` and was also copied to `dist/everyDock.app`; these now differ from the public 1.0.0 bundle although the bundle version remains 1.0.0. CUA verified proper icons for the affected apps. Long-duration recurrence remains unverified. After the rebuild, macOS reported Accessibility permissionDenied; the user was informed to re-authorize the current app. Do not assume window-control permissions are valid or reset TCC automatically. Full evidence is recorded in TC-A65–68/TC-M73. These changes must not be described as a published 1.0.1.

## Current baseline

| Item | Last verified state |
|---|---|
| Source | [hungryZoo/everyDock](https://github.com/hungryZoo/everyDock), branch `main` |
| Published release | [v1.1.1](https://github.com/hungryZoo/everyDock/releases/tag/v1.1.1), regular/latest release, not a prerelease; build **21** |
| Release source | `739e74e87b7d53e718c352a4cf3652645c549bc1` (tag `v1.1.1`) |
| Published ZIP | `everyDock-1.1.1-arm64.zip`, with `SHA256SUMS` |
| ZIP SHA-256 | `f5ac7174028fb7bb1b21212c4152f2f4a317dcf63ff47528f4c3f5323a2f9a8f` |
| Homebrew | [hungryZoo/homebrew-tap](https://github.com/hungryZoo/homebrew-tap/blob/main/Casks/everydock.rb), `everydock` 1.1.1; tap commit `a0ff8a8` |
| Previous releases | v1.1.0 build 20, `6d9092c`, ZIP `2212b390…`, tap `35b658e`; v1.0.0 build 19, `151b06b`, ZIP `8daa3387…`, tap `87456ca` |
| Platform | Apple Silicon, macOS 26+, Swift 6.2+ / Xcode 26+ |
| License | [Apache-2.0](LICENSE), ownership explanation in [NOTICE](NOTICE); both bundled in the app |
| Signing | Ad-hoc, **not notarized**. No valid signing identity was available during release preparation. |

Release metadata, public asset digest, and the tap were checked on 2026-10-27 right after publication. Future agents must recheck live state rather than assume these facts remain current.

The owner machine was upgraded via Homebrew from 0.4.1 to 1.0.0 on 2026-09-15. `/Applications/everyDock.app` and the ignored local `dist/everyDock.app` were populated from that release. These are dated installation facts, not instructions to replace or launch an app during handoff review. `.build/` and `dist/` are disposable local artifacts, not prerequisites available in a fresh clone.

## What shipped most recently

- **Automatic pause without an external display**, on by default when the option is absent. Restore native Dock and stop everyDock panels, pointer/app timers, previews, folder watching, and window adjustment; resume when an external display is online. Mirrored and single external/clamshell displays count. Manual pause remains separate. Battery savings have not been measured.
- **Bidirectional pin/order synchronization.** Read native pins on launch, activation, resume, manual import, and the existing five-second active check. Native order and membership replace ordinary local app pins while preserving local separator identities/slots and Finder's local slot. Local reorder/pin/unpin writes the native app list while preserving unrelated metadata and non-app entries.
- **Press-and-hold dragging**, 0.30 seconds, replaces the Command requirement. Collapse magnification during the move; dragging into the running section unpins the app.
- **Apache-2.0 licensing.** Commercial use, modification, and redistribution are permitted under the standard license. Ownership of any patents stays with their owners, but Section 3 grants its specified patent permissions. Do not describe this as withholding all patent usage rights or proof of a registered patent.

Native sync originally only wrote outward: the owner reported that changing native Dock order did not appear after restart. That regression was fixed before 1.0.0. Preserve queued IO, revision checks against stale reads, suppression of outgoing writes during import, hold/drag guards, write-failure handling, and draining queued work before normal termination. See [AppModel.swift](Sources/EveryDock/AppModel.swift), [NativeDockPinSync.swift](Sources/EveryDock/NativeDockPinSync.swift), [NativeDockPins.swift](Sources/DockCore/NativeDockPins.swift), and FR-33 in [SRS](docs/SRS.md).

Existing behavior to preserve: English/Korean with system-language default; full-screen overlay off by default; preview delay 0.60 seconds; app-provided commands integrated into right-click menus; folder stacks and window thumbnails; permission checks without background consent requests; native Dock restoration; settings-preserving Homebrew upgrades. See [README](README.md) for the user contract rather than this summary alone.

## Verification and remaining work

The authoritative release evidence is [QA-v1.0.0](docs/QA-v1.0.0.md), with stable test IDs in [TC](docs/TC.md).

- **62 automated tests passed**, including the opt-in real Quick Look integration, during release validation. Do not report these as newly rerun during this handoff-only task.
- [Released-source CI](https://github.com/hungryZoo/everyDock/actions/runs/34959306213) passed tests and packaging. [Post-release documentation CI](https://github.com/hungryZoo/everyDock/actions/runs/34959890409) also passed; its status was checked on 2026-09-16.
- Release architecture/version/signature and bundled LICENSE/NOTICE verification passed. Public ZIP/checksum matched the local artifact. Ordinary Homebrew audit/fetch and exception-scoped style passed.
- Actual Homebrew upgrade preserved the canonical preference payload and first-run flag. The release was launched afterward. A read-only comparison found matching app order and preserved local separator identity. No private settings or hashes of those settings are stored in this handoff.
- **TC-M70 and TC-M71: NOT RUN** — physical display disconnect/reconnect/mirroring and detailed live hold/drag cases.
- **TC-M72: PARTIAL** — startup order comparison passed; live native reordering, physical resume, stale-read races, error recovery, and immediate quit after drop remain manual verification work.
- Live bilingual layout, mixed-display icon quality, fresh/denied/allowed permission dialogs, broader Spaces/sleep/wake compatibility, and performance/energy measurements remain incomplete. Known limits include system-controlled Genie destinations and Accessibility-based rather than global work-area reservation.
- The owner explicitly approved 1.0.0 publication with these limits disclosed. The regular-release label does not imply notarization or a complete device-matrix pass.

Maintenance items, not newly confirmed functional defects:

- Developer ID signing, hardened runtime/notarization/stapling remain future distribution work.
- Homebrew warns about the legacy `uninstall_preflight` hook. It distinguishes upgrade from explicit removal at runtime; do not replace it without verifying preservation/reset behavior.
- CI passed with a Node.js 20 action-runtime deprecation annotation. Review pinned action upgrades when doing CI maintenance.
- Prior automated UI capture attempts failed with `failedToCreateImageDestination`. Recheck tool availability when needed; do not claim UI validation from a failed capture or reset permissions to work around it.

## How to resume

1. Read [AGENTS.md](AGENTS.md), then check the current Git status/log and compare the remote. Preserve unrelated changes; the owner has directly edited README on GitHub, including demo videos.
2. Establish the user's new scope. Use the code map in AGENTS and [docs/README.md](docs/README.md) to locate only the relevant implementation, requirements, and tests.
3. If debugging installed behavior, identify the running bundle/version and check current permissions. Avoid confusing `/Applications` with an old development build. Do not reset settings/TCC as a generic first step.
4. Reproduce the issue, make the required code/spec changes together, and run the relevant checks. Use isolated preference domains and disposable files; never rearrange native pins or delete real user files merely to create a test fixture.
5. Record actual results and unresolved manual cases. Update this handoff when substantive work finishes. Release only when requested, following [docs/RELEASING.md](docs/RELEASING.md).

Useful commands from the repo root (choose according to the task):

```bash
git status --short
git log -5 --oneline
swift test --arch arm64
EVERYDOCK_RUN_QL_TEST=1 swift test --arch arm64
EVERYDOCK_OUTPUT_DIR="$PWD/.build/dev-app" ./scripts/build.sh debug
```

Build and test locally using the Mac's toolchain. GitHub Actions also builds/tests in its macOS runner after pushes to main/PRs and uploads an artifact; release publication and Homebrew tap updates are separate explicit steps. No project-specific agent skills were added: they were discussed as a future option only.
