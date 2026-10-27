# v1.1.0 Verification Record

2026-10-27, build 20. Shift-click new windows (FR-34), the daily update check and update window (FR-35), and blank-icon recovery (FR-03). Regular release requested by the owner without waiting for the in-app manual checks; ad-hoc signed and unnotarized.

## Scope and evidence

- TC-A65–68 (icon recovery, 2026-09-23) and TC-A69–78 (version parsing, check interval, pending/skip, cache, API parsing, release notes, install method, Homebrew script, new-window menu rule, preferences): **PASS**.
- TC-R11 Homebrew script harness: **PASS**. It fetched the live `releases/latest`, waited for a test PID, called a fake brew with `update` then `upgrade --cask hungryZoo/tap/everydock`, cleared quarantine, and deleted itself.
- New-window rule probe: AX scan of 12 running apps on Korean macOS 26 chose the window command for Finder, Chrome, NAVER Whale, iTerm2, Audacity, and Cursor, and nothing for Mail, Calendar, Codex, Hancom Office, Preview, Telegram, and KakaoTalk. A live press opened one Finder window, which was then closed.
- TC-M73: PARTIAL (installed visual check on 2026-09-23). TC-M74–77 and TC-P05: **NOT RUN**. In-app Shift-click, the update window and its buttons, menu and Settings checks, network observation, and the Homebrew update from the update window are unverified. TC-M77 needs a release newer than 1.1.0.
- Releases before 1.1.0 have no update check; the release notes give the one-time manual upgrade command.

## Release checks

- Local automated suite: **76 PASS**, also with `EVERYDOCK_RUN_QL_TEST=1`, on macOS 26 / arm64.
- Released source/tag: `6d9092cd3e4cdd6993125ae14b300b6447476cf2` / `v1.1.0`. [GitHub CI](https://github.com/hungryZoo/everyDock/actions/runs/40374260396) tests and packaging: **PASS**.
- Packaging / TC-R01: **PASS**. Built from a clean tree at the release commit. Extracted ZIP contains v1.1.0/build 20, arm64, minimum macOS 26.0, and a valid final ad-hoc signature.
- License distribution / TC-R10: **PASS**. Bundled LICENSE and NOTICE match the source byte for byte.
- ZIP SHA-256: `2212b390c1e269941cd96f90e14219333704e16ee8a1d2250be2d1c1a3b8a292`.
- [Public release](https://github.com/hungryZoo/everyDock/releases/tag/v1.1.0): **PASS**, regular/latest, not draft or prerelease. An unauthenticated download matched the local ZIP byte for byte and passed `shasum -a 256 -c SHA256SUMS`. `releases/latest` returns `v1.1.0`, and its body starts with the summary sentence, as the update window needs.
- Homebrew tap commit `35b658e`: **PASS**, version 1.1.0 and matching SHA-256. `brew audit --cask` exited 0, `brew fetch` succeeded, and the downloaded hash matched. Style passed with the explicit Cask/InstallSteps exception; the existing `uninstall_preflight` deprecation warning remains.
- README links/anchors and `git diff --check`: **PASS**. The owner’s installed app was not upgraded or relaunched as part of this release; no TCC resets were performed.

## Post-release device check (2026-10-27)

- Official Homebrew upgrade 1.0.0 → 1.1.0: **PASS**. Settings and first-run state were preserved, and the launch check cached 1.1.0.
- TC-M75: **PARTIAL**. The window appeared after setup closed, at floating level; Later and Skip worked across relaunches. TC-M76: **PARTIAL**. The status menu and Settings Check Now showed the up-to-date alert.
- TC-M77: **FAIL in 1.1.0**. Yes opened Terminal, but everyDock deadlocked while quitting, so the update waited. The fix (1.1.1) was verified with a temporary Homebrew-located debug build: normal quit within 1 second, Dock restored, script completed and reopened the app. Details are in [TC](TC.md) section 6.
- TC-M74 Shift-click: waiting for Accessibility to be re-granted after the ad-hoc upgrade.

## v1.1.1 patch release (2026-10-27)

Build 21. Fixes the TC-M77 deadlock: `NSApp.terminate` and alert `runModal` now run from a run-loop block outside any main-actor Task. No other behavior changes.

- Local automated suite: **76 PASS**, also with `EVERYDOCK_RUN_QL_TEST=1`.
- Released source/tag: `739e74e87b7d53e718c352a4cf3652645c549bc1` / `v1.1.1`. [GitHub CI](https://github.com/hungryZoo/everyDock/actions/runs/40452516500) tests and packaging: **PASS**.
- Packaging / TC-R01 and TC-R10: **PASS**. Extracted ZIP contains v1.1.1/build 21, arm64, minimum macOS 26.0, a valid strict signature, and LICENSE/NOTICE identical to the source.
- ZIP SHA-256: `f5ac7174028fb7bb1b21212c4152f2f4a317dcf63ff47528f4c3f5323a2f9a8f`.
- [Public release](https://github.com/hungryZoo/everyDock/releases/tag/v1.1.1): **PASS**, regular/latest, not draft or prerelease. An unauthenticated download matched the local ZIP byte for byte and passed `shasum -a 256 -c SHA256SUMS`. `releases/latest` returns `v1.1.1`, and its body starts with the summary sentence.
- Homebrew tap commit `a0ff8a8`: **PASS**, version 1.1.1 and matching SHA-256. Style with the Cask/InstallSteps exception and `brew audit --cask` exited 0; `brew fetch` succeeded and the downloaded hash matched. The existing `uninstall_preflight` deprecation warning remains.
- The fix itself was verified before release with a Homebrew-located debug build (see above). The owner’s installed 1.1.0 was not upgraded as part of this release. A real in-app version replacement starting from 1.1.1 needs a later release.
- Owner upgrade to 1.1.1 (2026-10-27): **PASS**. The owner upgraded the Mac directly. Afterward `/Applications/everyDock.app` is 1.1.1/build 21 (ad-hoc, no quarantine attribute), Homebrew records `everydock 1.1.1`, and the app and its Dock watchdog were running. The decoded preference payload matched the pre-test export exactly (`checkForUpdates` true, no skipped version), the first-run flag was kept, and the launch check cached `latestVersion` 1.1.1. Accessibility and Shift-click were not checked.
