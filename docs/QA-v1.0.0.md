# v1.0.0 Verification Record

2026-09-15, build 19. Bidirectional native Dock pins, automatic pause without an external display, press-and-hold dragging, and Apache-2.0 licensing. Regular release authorized by the owner; ad-hoc signed and unnotarized.

## Scope and evidence

- TC-A58–64 cover display-presence policy/default migration, hold states, native tile preservation, reverse import with separator/Finder preservation, and isolated preference reads/writes including a new reader after external changes.
- Pre-release corrected local app: read-only comparison found 16 pins whose order differed before replacement and matched after launch. The native order hash and one local separator identity were unchanged. No real native pins were rearranged for that check.
- TC-M70/M71: NOT RUN. Physical display handoff, live hold/drag behavior, and energy reduction are unverified.
- TC-M72: PARTIAL (startup order comparison only). Live reverse dragging, physical resume, stale-read races, error recovery, and immediate quit-after-drop still require manual coverage.
- Existing language, icon, and fresh permission-dialog manual cases remain unverified; historical beta evidence is not a new 1.0 device-matrix pass. No user TCC decisions are reset for this release.
- Apache-2.0 preserves ownership while granting its defined copyright and patent permissions. NOTICE is informational and does not modify the standard license or claim a filed/granted patent.

## Release checks

Tests, packaging, CI, public download integrity, and Homebrew upgrade results are recorded below as they complete. Outstanding checks are not PASS. See [TC](TC.md) for the full test catalog.

- Local automated suite: **62 PASS**, including opt-in Quick Look integration, on macOS 26 / arm64.
- Packaging / TC-R01: **PASS**. Extracted ZIP contains v1.0.0/build 19, arm64, minimum macOS 26.0, with a valid final ad-hoc signature after stripping and re-signing.
- License distribution / TC-R10: **PASS**. Source LICENSE is the standard Apache-2.0 text; bundled LICENSE and NOTICE compare byte-for-byte with source. Copyright metadata is present in Info.plist.
- ZIP SHA-256: `8daa33871c4c9ae96b35cbda516d6ac1c1c25428815036aeaeee89a7ca88e3b2`.
- README GitHub Markdown rendering, current local Markdown links, and `git diff --check`: **PASS**. This is not a visual device-layout check.
- Released source/tag: `151b06b6fc5070a5f70bbd5c7addc9a4f6459c26` / `v1.0.0`. [GitHub CI](https://github.com/hungryZoo/everyDock/actions/runs/34959306213) tests and packaging: **PASS**. The workflow emitted a Node.js 20 action-runtime deprecation annotation; the jobs completed successfully.
- [Public release](https://github.com/hungryZoo/everyDock/releases/tag/v1.0.0): **PASS**, regular/latest, not draft or prerelease. ZIP and SHA256SUMS are attached. An unauthenticated download (retried with a download query after the initial request stalled) matched the local ZIP byte-for-byte; the public checksum file matched as well.
- Homebrew tap commit `87456ca`: **PASS**, version 1.0.0 and matching SHA-256. Ordinary cask audit and public fetch passed. Style passed with the explicit Cask/InstallSteps exception for the existing runtime uninstall hook; this is not an unrestricted style or notarization audit pass.
- Actual Homebrew 7.0.1 **0.4.1 → 1.0.0 upgrade PASS** after normal quit. The canonical preferences hash and first-run flag matched before/after upgrade. The installed bundle reports 1.0.0/build 19, passes strict signature verification, and contains the exact LICENSE/NOTICE files. No private settings were committed.
- Applied the documented app-scoped quarantine command, copied the same installed release bundle to `dist/everyDock.app`, and launched `/Applications/everyDock.app`. Existing uninstall-hook deprecation and unsigned-accessibility warnings remain disclosed. No TCC resets or manual permission changes were performed.
