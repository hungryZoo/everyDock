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

Tests, packaging, CI, and public distribution results will be recorded as each check completes. No release gate is marked passed in advance.
