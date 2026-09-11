# MRD — Market Requirements Document

| Field | Value |
|---|---|
| Product | everyDock |
| Document version | 1.13 / 2026-09-11 |
| Release | v0.4.0 public beta; preparation for 1.0 |
| Decision owner | Repository owner / product owner |

## 1. Problem and evidence

People working across monitors want to switch apps and find files on the display already under their pointer. The product owner requested a persistent Dock on every monitor, then identified problems with magnification, launch responsiveness, window selection, native Dock coexistence, and file access during daily use.

This is qualitative feedback from the product owner, not a representative market study. The hypothesis is that familiar interactions and reliable restoration matter as much as displaying multiple bars. No market size, revenue, conversion, or adoption figures have been established.

## 2. Audience

| Audience | Need |
|---|---|
| Apple Silicon users on macOS 26+ with external displays | Launch and switch apps without moving to another screen. |
| People with several windows per app | Identify, select, and close the intended window. |
| Laptop users who frequently connect displays | Recover their layout after connection changes and sleep. |
| GitHub and Homebrew users | Reproduce installation, updates, and bug reports. |

Intel Macs and macOS 25 or earlier are outside the supported target. Job titles do not determine priority; actual multi-monitor use does.

## 3. Alternatives and positioning

The earlier review of official product descriptions was conducted on 2026-09-07. It was not a comparative usability test, and does not establish that competitors lack a feature.

| Alternative | Historical observation | Implication |
|---|---|---|
| [macOS Dock](https://support.apple.com/en-euro/guide/mac-help/-mh35859/mac) | Provides app, folder, Trash, magnification, placement, and minimize behaviors. | Use familiar interactions as the reference, without promising an exact clone. |
| [HiDock](https://hidock.app/) | Described changing the native Dock configuration for display setups rather than simultaneous multiple Docks. | Configuration automation and multiple persistent bars solve different needs. |
| [Sidebar](https://sidebarapp.net/) | Described multiple displays, window previews, folders, Trash, and configurable interactions. | Feature count alone is insufficient; defaults and reliability need validation. |

Positioning hypothesis: a local Dock utility focused on Apple Silicon and macOS 26, offering immediate access on each display, inspectable source, and Homebrew distribution. Licensing and monetization remain separate decisions.

## 4. Market requirements

P0 blocks core use, P1 improves repeated use, and P2 is exploratory.

| ID | Priority | Requirement | Success signal |
|---|---|---|---|
| MR-01 | P0 | Access apps simultaneously on every enabled display. | Complete app-switching tasks on the current screen. |
| MR-02 | P0 | Immediate, consistent magnification, clicks, and running state. | Fewer reproducible wrong clicks, stalls, and stale lists. |
| MR-03 | P0 | Coexist with or manage the macOS Dock and restore it safely. | Original settings survive normal exit and recovery. |
| MR-04 | P1 | Reach Desktop, Downloads, Apps, and Trash. | Complete everyday file tasks with fewer navigation steps. |
| MR-05 | P1 | Identify and select windows through previews. | Select the intended window among several candidates. |
| MR-06 | P0 | Control displays, appearance, organization, permissions, and login. | Disabling or hiding a feature leaves a reachable recovery path. |
| MR-07 | P1 | Reproducible Homebrew installation and updates. | Public downloads, checksums, and instructions produce a working install. |
| MR-08 | P0 | Keep window images and personal files local. | Explicit consent, no remote transmission, original files preserved. |
| MR-09 | P1 | Provide an English interface and readable English project documentation. | App-owned labels and guidance are consistently English; existing user data remains intact. |

MR-09 is the v0.4.0 request, linked to P-10, FR-31, TC-M66, and TC-R09. It does not imply that macOS dialogs or content owned by other apps is translated.

## 5. Validation hypotheses

These are future targets, not measured results. If 5–10 beta participants are recruited, assess two weeks of consented questionnaires and reproduction notes without adding analytics to the app.

| Hypothesis | Method | Initial target |
|---|---|---|
| Persistent access helps | Ten switching tasks on each of two screens. | At least 80% complete tasks on the current display. |
| Familiar behavior matters | Five-point interaction survey. | Median at least 4; no serious wrong activation. |
| Recovery builds trust | Exit, process termination, and settings edits in a test account. | No P0 restoration defects. |
| Previews aid selection | Select a named target among three windows. | At least 90% success. |
| Installation is understandable | Give a new user only the README. | First launch within ten minutes, excluding OS approval time. |

## 6. Risks and release decisions

Private Dock preference formats, Accessibility implementation differences, protected windows, ad-hoc signing, and display/Spaces combinations limit compatibility. Document these limits, keep recovery records, preserve user edits, and validate a device matrix. Do not invent competitor pricing or business projections.

The beta can ship with explicit untested cases after build, test, and distribution integrity checks. Stable release requires P0 acceptance, permission-enabled window and file operations, recovery, performance, signing, and notarization evidence. Licensing, Developer ID access, participant recruitment, and demand for per-display customization remain owner decisions.

## 7. Feedback incorporated into the baseline

- Accurate AX window counts, Finder reopening, icon-anchored menus, centered tooltips, individual close buttons, and save-safe Close All Windows.
- Desktop as a file stack, Spotlight Apps integration, supported window zoom correction and observed-size restoration, asynchronous thumbnails sorted by modification date.
- App-provided commands integrated into one right-click menu, including on displays without the native Dock.
- Pinned/running/folder sections, custom separators, and Command-drag with collapsed magnification and unpinning.
- Setup guidance, optional login launch, recoverable menu bar hiding, uninstall/reinstall reset, and upgrade preservation.
- Screen Recording requests initiated by a permission button rather than startup or unapproved background capture.
- English app-owned text and current documentation for v0.4.0. These changes do not establish market-wide validation or readiness for 1.0.
