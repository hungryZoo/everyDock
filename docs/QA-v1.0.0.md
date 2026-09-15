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
- GitHub CI/public release/tap/upgrade: pending publication checks.
