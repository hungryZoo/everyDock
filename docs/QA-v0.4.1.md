# v0.4.1 Verification Record

2026-09-15, build 18. English/Korean UI, new-install defaults, separate permission-request/navigation paths, and display-aware icon rendering; public beta.

## Scope

- New/missing preferences use full-screen display off and preview delay 0.60 seconds. Existing choices survive decoding and round trips.
- Language selection resolves the primary system language and explicit en/ko overrides. Korean catalog tests verify interpolation tokens and preserve external names. English is the fallback.
- Icon tests check high-resolution source selection, Retina pixel dimensions, filtering, and reuse across animated bounds.
- Permission source inspection confirms requestAccessibility/requestScreenCapture do not open privacy URLs. Only explicit settings-link actions open them.
- TC-M66/M67/M68/M69: **NOT RUN**. Live bilingual layout, mixed-display image quality, language switching, and fresh/denied/allowed OS dialog sequences are not established by automated tests. The UI capture service previously failed with failedToCreateImageDestination; no user TCC decisions were reset.
- No new CPU/GPU/frame-time measurements. Do not infer measured performance improvements from implementation alone.

## Release validation

- Local full suite: **55 PASS**, including opt-in Quick Look integration (`EVERYDOCK_RUN_QL_TEST=1 swift test --arch arm64`).
- Release packaging **PASS**: arm64, minimum macOS 26.0, v0.4.1/build 18, final strip/re-sign and strict signature verification.
- ZIP SHA-256: `19d52c67d5f55cd674652775d5481e716edbb4e8fc06688519bdaa2e669076d9`.
- README GitHub Markdown rendering **PASS**. English/Korean badge SVG was verified separately. Full visual layout remains unverified.
- Current local documentation links resolve; CI and distribution evidence is recorded below.

## Public distribution

- Source/tag: `9f579898da981261fba06f9a4558081224cc9cb5` / `v0.4.1`. [GitHub CI](https://github.com/hungryZoo/everyDock/actions/runs/34860567663) tests and packaging **PASS**.
- [Public release](https://github.com/hungryZoo/everyDock/releases/tag/v0.4.1): prerelease, not draft; arm64 ZIP and SHA256SUMS assets confirmed uploaded. An unauthenticated download matched the local ZIP byte-for-byte and the SHA-256 above.
- Tap commit `45fa0ac`: v0.4.1 and matching SHA-256. Ordinary cask audit **PASS**. Style **PASS with explicit Cask/InstallSteps exception**; an unrestricted style check still flags the existing runtime uninstall hook. The hook preserves upgrade-versus-removal behavior. Removed obsolete inline RuboCop directives and expressed fallback cleanup as `rm_r(..., force: true)` without changing its targets or force behavior. This is not a strict/notarization audit pass.
- Actual Homebrew **0.4.0 → 0.4.1 upgrade PASS**. Homebrew auto-updated from 6.0.22 to 7.0.1 during this command. The upgrade fetched the public ZIP, verified it, and installed v0.4.1 successfully. The prior style/audit checks ran on Homebrew 6; actual installation ran on 7.0.1.
- Preferences payload SHA-256 and first-run flag matched before/after upgrade. No private preferences were published. Installed bundle version 0.4.1 and strict signature verification **PASS**; the development copy came from the same public ZIP. Applied the app-scoped quarantine command and launched `/Applications/everyDock.app`.
- Existing uninstall-hook deprecation and ad-hoc signer warnings remain. No privacy approvals were changed automatically. Full manual language/permission/visual checks remain NOT RUN as stated above.
