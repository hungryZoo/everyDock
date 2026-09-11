# PRD — Product Requirements Document

| Field | Value |
|---|---|
| Document version | 1.13 / 2026-09-11 |
| Product baseline | everyDock v0.4.0 public beta |
| Parent | [MRD](MRD.md) |
| Implementation and tests | [SRS](SRS.md), [TC](TC.md) |

## 1. Product outcome

Provide a persistent, familiar app bar on each enabled display, with reliable app switching, window selection, everyday file access, and a reversible relationship with the macOS Dock. v0.4.0 makes everyDock’s interface and current documentation English while preserving saved preferences and existing interactions.

The supported target is Apple Silicon with macOS 26+. The app is local, without accounts, analytics, remote window-image storage, or runtime network services. Public beta status remains in place before the proposed 1.0 release.

## 2. Scope

Included: multiple displays, Bottom/Left/Right placement, native size following, magnification and launch feedback, app activation and supported minimize/restore, previews, close actions, app Dock menus, file stacks, Trash, pins, separators, Command-drag, setup and permissions, login launch, native Dock restoration, and Homebrew distribution.

Excluded: Intel, earlier macOS, a pixel-exact Dock clone, independent system Genie destinations for every monitor, notification badges, minimized-window tiles, Mission Control, drag auto-scroll, and per-display app lists. OS-protected content and unsupported AX windows are not bypassed.

## 3. Product requirements

Implementation is not equivalent to verification. Current execution scope is recorded in [QA-v0.4.0](QA-v0.4.0.md); historical results remain version-specific.

| ID | Priority | Requirement and acceptance |
|---|---|---|
| P-01 | P0 | One Dock per enabled display. Reconnect and repeated launch must not duplicate panels. Settings remains reachable when all displays are disabled. |
| P-02 | P0 | Follow native sizing, magnify continuously, reflect launch state promptly, and activate supported windows. Explain unsupported actions. Anchor menus and labels to icons. Correct supported zoomed windows and restore an observed earlier size. |
| P-03 | P0 | Native Dock management is optional. Back up before applying settings; restore on exit/recovery without overwriting user edits. |
| P-04 | P1 | Desktop and Downloads show file stacks. Apps opens Spotlight’s app browser. Trash supports reversible moves and confirmed emptying. Copies preserve source and existing destination files. |
| P-05 | P1 | Show previews after a default 0.55-second hover delay, retain them while entering the popover, and select the exact window. Explain absent capture access without requesting it in the background. |
| P-06 | P0 | Save pins, order, separators, displays, position, visibility, and preferences. Expose setup, permissions, login launch, and a path back to Settings when the menu icon is hidden. |
| P-07 | P1 | Public source, requirements, arm64 release ZIP, SHA-256, and macOS 26+ cask. Installation, update, and removal instructions must match the package. |
| P-08 | P0 | Keep images in memory, send no personal content, preserve original files, and confirm irreversible deletion. |
| P-09 | P1 | One card per actual AX window, distinct same-title windows, individual × buttons, and Close All Windows including Finder. Stop at save confirmation. |
| P-10 | P1 | English app-owned menus, settings, setup, utility names, tooltips, accessibility labels, and messages. English README/current requirements; stable storage IDs and unchanged user/third-party text. |

## 4. Default experience

| Option | New configuration |
|---|---|
| Position | Bottom; Left and Right available. |
| Size and magnification | Follow the macOS Dock; manual controls available. |
| Running apps / full-screen display | On, within system restrictions. |
| Enabled displays | All connected displays; new displays included automatically. |
| Click active app to minimize | On. |
| Previews | On; 0.55 seconds, adjustable 0.2–2 seconds. |
| Native Dock management | On; preserve an existing user choice. |
| Launch at login | Selected in first-time setup, registered only after Get Started. |
| Menu bar icon | Visible by default. |
| Interface | English. External content and system dialogs keep their source language. |

Running apps have an indicator; active state is distinguished. A launch request gets immediate feedback. Focus changes alone must not reorder apps. Overflow is handled by fitting and scrolling.

## 5. Interaction acceptance

### Windows and menus — P-02/P-05/P-09

Use real Accessibility window identities for cards and actions. Do not merge extra ScreenCaptureKit entries into the list. Same-title windows remain distinct. One preview uses one column; multiple previews use two columns and resize after closing a card.

Minimization presses the actual yellow button when supported, with a minimized-attribute fallback. Do not hide the app as a substitute for a failed minimize. Finder with no normal windows is reopened. Close All Windows snapshots the original list, excludes newly opened windows, and stops on a save sheet or failed close.

Right-click, Control-click, and accessibility menu requests use the same icon-anchored menu. App-provided commands appear alongside everyDock commands without a separate entry step. Validate command identity again before dispatch. Unsupported menus keep ordinary commands available in place.

Supported screen-sized windows leave room for the resting Dock without an extra four-point gap. Preserve an observed normal frame across app switches and restore it on a subsequent zoom request. Never invent the prior size of an already-zoomed window. The short restore transition respects Reduce Motion; actual smoothness needs device testing.

### Organization — P-06

Order pinned items, unpinned running apps, then folders. Persist custom separator UUIDs alongside pins. Insert separators from gaps, app context menus, or Settings; reorder and remove them in both places. Separators do not launch, magnify, or preview.

Command-grab collapses magnification. A drag exceeding four points can move a pin to a blue insertion line, pin a running app, or unpin an app in the orange running-section target. Preserve other item order and IDs. Escape, outside/folder drops, or separator unpin attempts cancel. Command-click alone does not launch. Dragging performs no intermediate preference writes.

### Files — P-04/P-08

Desktop is a file stack, not a show-desktop gesture. Both stacks use modification date descending, natural filename ties, and at most 80 visible items. Keep valid thumbnails and the previous grid while refreshing. An old popover must not cancel a new session. Limit thumbnail concurrency to three; release a stalled slot after eight seconds. Unsupported content keeps its icon.

Trash emptying explains its current-user scope and irreversibility; Cancel is the default. External-drive Trash is excluded. File operations may partially succeed; do not describe them as an all-or-nothing transaction.

### Setup, permissions, and removal — P-06/P-07

Show one setup window on first launch or when permission guidance is needed, including after setup was previously completed. Startup/reopen/general checks read screen permission status without calling the capture API. Missing permission blocks background capture; only an explicit screen-permission button may request it. A real denial stops background retries even with a stale positive hint.

The setup window contains Window Control, Window Previews, and Launch at Login. Detailed recovery/location help remains in Settings. Get Started applies the login choice and waits for necessary OS approval; Set Up Later keeps registration unchanged. Closing the window alone does not complete first setup.

Hide Menu Bar Icon must explain that launching everyDock from Apps reopens Settings. Permission guidance takes priority when needed; a permitted login launch remains quiet.

Homebrew uninstall and reinstall reset preferences and setup history, unregister login, and clean caches after native Dock recovery. Upgrade preserves preferences. macOS privacy decisions are separate. Installed cask snapshots determine removal behavior; older installations need an upgrade to receive new rules. Failed cleanup stops removal.

### English presentation — P-10

Translate everyDock-owned visible text and accessibility descriptions. Display counts use singular/plural English. Declare English bundle localization. Preserve app names, filenames, window titles, third-party commands, system-owned dialogs, and OS diagnostic text. Do not rename persisted enum values, preference keys, bundle identifiers, separator IDs, or user files.

README uses the owner’s [agents-dev-skills](https://github.com/hungryZoo/agents-dev-skills) header/navigation and Homebrew guidance. Do not fabricate screenshots, videos, license grants, test results, or 1.0 readiness claims.

## 6. Failures and quality

Distinguish denied permission, missing registration, API failure, timeout, unsupported windows, and empty lists. Keep ordinary app launch, Settings, and Quit available without capture permission. Recover moved apps by bundle ID or retain removable missing pins. Preserve failed restoration journals. Long AX, application enumeration, file, and thumbnail work must not block animation.

Performance targets are defined in SRS NFR-02 and are not claims of measured performance. Validate mixed scale, 60/120Hz, Reduce Motion/Transparency, light/dark mode, keyboard interaction, and VoiceOver separately.

## 7. Release gates

A beta requires automated tests, arm64 packaging/signature integrity, public checksum agreement, relevant observations, and disclosure of untested areas. A stable release additionally requires the P0 manual matrix, permission-enabled window/file operations, recovery and file safety, display/sleep/Spaces coverage, measured performance, Developer ID signing, and notarization. The owner decides licensing. A version bump alone does not satisfy these gates.
