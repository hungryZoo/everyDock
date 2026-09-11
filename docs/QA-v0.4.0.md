# v0.4.0 Verification Record

2026-09-11, build 17. English app presentation and current documentation; public beta.

- `EVERYDOCK_RUN_QL_TEST=1 swift test --arch arm64`: **49 PASS**, including real Quick Look integration and existing preference migration/consent regressions.
- App-owned labels, menus, messages, tooltips, accessibility values, utilities, and setup/settings text translated to English. English bundle localization declared; existing preference keys and enum raw values retained. Singular/plural window and display counts handled.
- Current MRD/PRD/SRS/TC, documentation index, release procedure, README, and new release notes are English. Stable requirement/test IDs are retained; historical QA records keep their original language and version-specific results.
- **TC-R09 PASS (static/render scope):** no Korean remains in Sources, Resources, README, or current specifications/release notes. All existing requirement/test IDs remain represented across the specifications, including retired A31/A38. Current local document links resolve. GitHub Markdown HTML was rendered and visually inspected in a local browser; all 22 heading targets were checked using GitHub slug rules, with no missing targets. The Markdown API does not inject the repository page’s automatic heading IDs. Badge images loaded and were arranged on one row. No screenshots or demo links were invented.
- **TC-M66 NOT RUN:** full visual/VoiceOver coverage on Korean and English macOS. Automated model checks do not prove every localized system dialog, external app menu, or layout combination.
- No permission databases, user settings, or private window images are included in the release.

## Packaging

- Release packaging **PASS**: arm64 only, minimum macOS 26, version 0.4.0/build 17, final strip/re-sign and codesign strict verification.
- ZIP SHA-256: `e891f63b7e006ecb5fedd2661af98a649afc6a4ab3078d308984ac6d06e10772`.

## Public release and installation

- Final source/tag: `f468ae4f9d5f79b91346624f8a096a1e7665e264` / `v0.4.0`. [GitHub CI](https://github.com/hungryZoo/everyDock/actions/runs/34574923784) tests and packaging **PASS**.
- The public English release page was opened without authentication. Its arm64 ZIP and SHA256SUMS assets were confirmed through release metadata, and the downloaded ZIP matched the checksum above.
- Homebrew tap `030cbfc`; cask style and ordinary audit **PASS**. Existing uninstall_preflight deprecation warnings remain; this is not a strict/notarization audit pass.
- Actual Homebrew **0.3.10 → 0.4.0 upgrade PASS**. Hashes of the stored preferences payload and setup history were identical before/after upgrading. Only hashes were used for this comparison; no personal settings were published.
- Installed bundle reports 0.4.0 and English development region; codesign strict **PASS**. The development copy was updated from the same ZIP after the old process stopped. The documented app-scoped quarantine command was applied and `/Applications/everyDock.app` was launched.
- Full English visual/VoiceOver validation remains **TC-M66 NOT RUN** for user/device follow-up. Source coverage, rendered README inspection, and model regressions are not substitutes for that manual matrix.
