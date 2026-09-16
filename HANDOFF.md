# everyDock handoff

Updated: **2026-09-16**. The owner is pausing development after the v1.0.0 release. No feature implementation or further release is queued. This handoff is a starting point for a future session, not authorization to resume publishing automatically.

## Current baseline

| Item | Last verified state |
|---|---|
| Source | [hungryZoo/everyDock](https://github.com/hungryZoo/everyDock), branch `main` |
| Published release | [v1.0.0](https://github.com/hungryZoo/everyDock/releases/tag/v1.0.0), regular/latest release, not a prerelease; build **19** |
| Release source | `151b06b6fc5070a5f70bbd5c7addc9a4f6459c26` (tag `v1.0.0`) |
| Main before this handoff-only update | `9c69dc426afa2f4e429daca89d763be96c56b4fa` (release verification record) |
| Published ZIP | `everyDock-1.0.0-arm64.zip`, with `SHA256SUMS` |
| ZIP SHA-256 | `8daa33871c4c9ae96b35cbda516d6ac1c1c25428815036aeaeee89a7ca88e3b2` |
| Homebrew | [hungryZoo/homebrew-tap](https://github.com/hungryZoo/homebrew-tap/blob/main/Casks/everydock.rb), `everydock` 1.0.0; tap commit `87456ca` |
| Platform | Apple Silicon, macOS 26+, Swift 6.2+ / Xcode 26+ |
| License | [Apache-2.0](LICENSE), ownership explanation in [NOTICE](NOTICE); both bundled in the app |
| Signing | Ad-hoc, **not notarized**. No valid signing identity was available during release preparation. |

The working tree and local tap were clean before this documentation task. The remote matched local `main` after fetch. GitHub release metadata and asset digest were rechecked on 2026-09-16. Future agents must recheck live state rather than assume these facts remain current.

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
