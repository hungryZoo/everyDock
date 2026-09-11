# SRS — Software Requirements Specification

| Field | Value |
|---|---|
| Document version | 1.13 / 2026-09-11 |
| Baseline | everyDock v0.4.0 |
| Parent / verification | [PRD](PRD.md) / [TC](TC.md) |

Requirements describe intended behavior. Implementation and observed PASS results are separate; numeric performance targets are not measured achievements.

## 1. System boundary

- Apple Silicon arm64, macOS 26.0+; Intel compilation is rejected.
- Swift 6.2+, Xcode 26+, macOS 26 SDK; no external Swift packages.
- Bundle ID `app.everydock.mac`; accessory app with a menu bar item rather than a normal app Dock tile.
- AppKit panels, controls, `NSGlassEffectView`, and SwiftUI settings/popovers.
- `NSWorkspace`, `NSScreen`, Accessibility, ScreenCaptureKit, Quick Look Thumbnailing, and `SMAppService` integration.
- Native Dock preferences use `com.apple.dock`, whose storage format is not a public compatibility contract.
- No runtime accounts, servers, analytics, or remote image transfer. Distribution downloads are separate.
- No automatic OS permission approval or system-wide Gatekeeper/SIP changes. README documents user-run, app-scoped quarantine removal.

UI mutations use MainActor. AX and filesystem work run separately. Retain observed NSRunningApplication objects and invalidate KVO before releasing them.

## 2. Components

| Component | Responsibility |
|---|---|
| AppDelegate | Lifetime, duplicate-instance prevention, menu bar, Settings/setup windows. |
| AppModel / ApplicationSnapshot | Preferences, event-driven app state, background snapshots, launch requests. |
| DockCoordinator / DockPanel | Display identity, panel geometry, lifecycle, pointer conversion. |
| DockSurface | Cached icons/layers, controls, magnification, drag targets, menus. |
| AppPermissions | Permission hints, actual failures, explicit capture consent, request/cache coordination. |
| WindowActions / WindowWorkArea | AX window identity, minimize/restore/select/close, supported zoom correction. |
| NativeDockManager / NativeDockMenu | Recovery journals/watchdog and native menu snapshot/dispatch. |
| DockUtilities / WindowPreview | Folder and Trash actions, file thumbnails, window previews. |
| DockCore | Persistent models, geometry, motion, matching, ordering, recovery, failure classification. |

## 3. Functional requirements

### FR-01 Display panels — P-01 / P0

Maintain one panel per enabled NSScreen using stable display IDs. Observe display/Space changes and system/display wake; clean up removed panels, previews, and timers. Support negative origins and point coordinates. A five-second geometry check with one-second tolerance supplements notifications. Cache the pixel-aligned requested frame so WindowServer rounding does not cause repeated frame writes.

### FR-02 Visibility and position — P-01 / P0

Support Bottom, Left, Right, per-display selection, and hiding all Docks. Keep Settings reachable with every display disabled. Apply the full-screen option through collection behavior without promising secure-screen visibility. Use visibleFrame placement when native Dock management is off.

### FR-03 Shared metrics and native sizing — P-02 / P0

Read native tilesize within 16–96pt and largesize between the base size and 128pt. Disabled native magnification means scale 1; otherwise use large/base. Fall back to defaults on read failure.

| Metric | Value |
|---|---|
| Icon spacing | 2pt |
| Outer axial padding | 7pt per side |
| Icon baseline / top resting space | 8pt / 4pt |
| Utility boundary | 12pt |
| Resting thickness | Icon size + 12pt |
| Native-follow edge inset | 3pt |
| Custom separator width | 12pt, not magnified |

Length is `(app count + 3) × (icon size + 2) − 2 + 14 + 12 + separator count × 14`, plus 12 when a running-section boundary exists. These are implementation metrics, not official measurements of Apple internals.

Use cell-free NSControl icons with cached CALayers. Rasterize only when artwork or display backing scale changes, at 288pt × backing scale (576px at 2×), covering maximum manual magnification and native-follow sizing. Draw the appropriate NSImage representation into an explicit transparent bitmap, preserve aspect ratio, and use trilinear minification with the layer's display contentsScale. Animated bounds reuse the same texture. Low-resolution source artwork cannot gain missing detail. Reuse dots and separator layers. A release outside cancels a click; dragging back inside and releasing activates once. Space, Return, and accessibility Press must work. Keep input tracking while pressed. Fit and scroll overflowing contents.

### FR-04 Motion and input — P-02 / P0

Use continuous cosine distance falloff for the hovered icon and neighbors. Run an NSView-linked CADisplayLink only while changing, request the display’s maximum rate, and stop when settled. The OS determines actual delivery. Interpolate with `1 − exp(−20 × elapsedSeconds)` so time, rather than refresh count, determines progress. Update icon/background geometry in one transaction without implicit animations. Provide launch bounce and click feedback; respect Reduce Motion. Read tracing configuration once and update mouse-through state only when changed. Transparent animation space passes clicks through.

### FR-05 Launch and activation — P-02 / P0

Launch/activate pins and running apps through NSWorkspace, publish pending feedback immediately, and report launch failures. Do not mark missing or terminated apps active. Serialize pending clicks per app.

### FR-06 Minimize and restore — P-02 / P0

Use standard/dialog/system-dialog AX windows, or windows with controls and no subrole. Deduplicate with CFEqual. Choose a focused window in the valid list, then the main window, then the first non-minimized window. Press AXMinimizeButton, falling back to setting minimized. Restore with minimized=false and raise. App-level restore currently restores the app’s minimized windows; individual selection follows FR-15.

AX preflight is not a veto over actual AX operations. Classify apiDisabled as denied, noValue as no window, unsupported families as unsupported, and cannotComplete as timeout. Never substitute hiding the app. A 0.5-second AX messaging timeout applies per message, not to the whole operation. AX messages run off the UI thread. macOS controls the minimize animation and destination. If no valid window exists, reopen the app; exclude Finder’s desktop/helper windows.

### FR-07 App state — P-02 / P0

Use launch/terminate/activate/hide notifications and KVO, supplemented by a five-second check with one-second tolerance. Coalesce full property reads into a background snapshot. Publish only changed lists; permission/settings changes must not synchronize every Dock. Expire pending launches after 45 seconds. Preserve app order across focus-only changes.

### FR-08 Native Dock management — P-03 / P0

Before changes, record values and key presence and start the watchdog. If the watchdog cannot start, do not change system preferences. Apply `autohide=true`, `autohide-delay=3600`, `autohide-time-modifier=0`, and `mineffect=genie`. Turning management off, hiding all Docks, disabling all displays, or quitting requests restoration. Restart only the native Dock’s process; do not disable its system features.

### FR-09 Durable restoration — P-03 / P0

Use atomic JSON journals and an interprocess file lock. The watchdog observes parent exit with kqueue, with a polling fallback. Restore only keys whose current value still equals everyDock’s applied value, preserving user edits. Remove originally absent keys. Delete the journal after successful restoration; retain failures for the next management session.

### FR-10 Desktop stack — P-04 / P1

Use the Desktop folder’s file popover, not app hiding/show-desktop. Reuse FolderStack with distinct name, icon, empty, and error states. Exclude hidden files, show up to 80 by newest modification date, open files and Finder. Coalesce reads per folder; read directories/icons in the background.

### FR-11 Downloads stack — P-04 / P1

Show up to 80 non-hidden Downloads entries in four columns, newest modification date first. Open with the default app and provide Open in Finder. Distinguish loading, empty, failed, and awaiting access; show waiting guidance after two seconds. Reopening must not multiply outstanding directory requests.

### FR-12 Trash — P-04 / P1

Open the current user’s `~/.Trash` and update cached empty/full icons as contents change. Coalesce directory reads off the UI thread. Emptying explains scope, permanence, and irreversibility and requires confirmation. Cancel is the default keyboard response and deletes nothing. External-drive Trash is excluded. Report read/delete failures.

### FR-13 File drops — P-04 / P1

Accept file URLs. Copy to Desktop/Downloads while preserving source and existing destination files; reject identical source/destination. Use NSWorkspace.recycle for Trash. Report errors and possible partial success; do not claim transactional rollback.

### FR-14 Window previews — P-05 / P1

After the configured delay, derive cards solely from the app’s valid AX windows. Do not append ScreenCaptureKit metadata as extra cards. Match same-PID, layer-zero capture entries one-to-one, using frame differences within 8pt and title as a secondary score. Keep same-title windows distinct. Capture the first eight cards at up to 440×330 pixels; remaining cards still support selection/closing. Capture no audio or cursor.

Refresh approximately every two seconds while open. Keep at most 32 images in memory; discard entries older than 60 seconds when queried. Coalesce content requests, with a one-second metadata cache.

When CGPreflight is false, block automatic content/image capture with permissionRequired, distinct from an actual denial. Only a screen-permission button may explicitly request SCShareableContent. A real userDeclined in SCStreamErrorDomain is denied; do not turn other errors into permission denial. After denial, a positive hint must not enable automatic retries before another explicit request. Check permission again immediately before the image API. Publish status only when changed. Protected/unavailable windows use a title, icon, or cached image; never bypass OS protection.

One card uses one column and 222pt width; two or more use two columns and 424pt. Thumbnails are 190×118pt, column gap 12pt, outside padding 16pt. Empty width is 300pt; scroll height is capped at 340pt. Update popover size from the hosting view’s fitting size after content changes.

### FR-15 Preview lifecycle and selection — P-05 / P1

Allow roughly 260ms to move from icon to popover; keep it open while inside. Cancel old delay/refresh tasks on target change, click, screen removal, or feature disable. Validate the stored PID and AX object with CFEqual against current windows before restoring/raising it. Never identify an action target by title or frame alone. If it disappeared, activate the app. Only inspect popover hit state while actually shown, and clear targets/tasks on close. Show Windows opens immediately independent of hover settings and stays until outside dismissal.

### FR-16 Pins — P-06 / P0

Support initial/manual import from the native Dock, file selection, `.app` drops, pin/unpin, and order changes. Deduplicate paths/bundle IDs. Resolve moved apps by bundle ID; retain removable missing pins.

### FR-17 Preferences, login, and instances — P-06 / P0

Persist changed settings and apply them to displays. A second app with the same bundle ID must exit without adding panels. Manage login through SMAppService.mainApp and show approval-required state. Register from the installed app location.

### FR-18 Permission and error guidance — P-06 / P0

Show Not Checked, Allowed, and Denied by macOS distinctly. Do not infer approval/denial from generic errors or timeouts. Check Permission Status inspects AX access and screen preflight without calling ScreenCaptureKit; Allow Screen Recording explicitly requests capture access. Show App Location reveals the running bundle. Explain the need for each permission and possible re-registration after ad-hoc updates. Keep launch, Settings, and Quit available when capture is denied.

### FR-19 Distribution — P-07 / P1

Publish source, MRD, PRD, SRS, and TC. Match bundle and tag versions; publish an arm64 ZIP and SHA-256 file. Pin the cask URL/checksum and declare arm64/macOS 26+. Provide install, launch, update, removal, and permission instructions. Mark beta releases as prereleases. Never overwrite published tags/assets or automatically zap unfinished recovery journals.

### FR-20 Individual and all-window closing — P-09 / P1

Each preview has a separate 24pt close button with accessibility text, disabled if unsupported. A close click must not select the window. Prevent duplicate close requests and invalidate window/content caches afterward.

Close All Windows is available for running apps, including Finder. Snapshot window objects at the start, close normally with AXCloseButton Press, skip already-closed windows, and stop on errors. Exclude new windows. If a modal/save sheet is present or a window remains after up to 1.2 seconds, stop the remaining closes and bring the app forward. Never automatically answer a save/delete dialog or force-quit.

### FR-21 Menus and name labels — P-02 / P1

Right-click, Control-click, and accessibility ShowMenu share one path. Anchor menus six points inward from the selected icon: above a bottom Dock or inside a side Dock. Clamp negative/display-edge coordinates and let NSMenu finalize placement. Freeze hover, previews, magnification, and list layout while tracking; synchronize afterward. Draw the name background separately and vertically center the label using its intrinsic height.

### FR-22 Spotlight Apps — P-02/P-04 / P1

Treat `com.apple.apps.launcher` and legacy Launchpad identifiers as launchers, not normal window apps. Launch a new system Apps instance via NSWorkspace to open Spotlight’s app browser. Do not show an internal catalog, minimize launcher windows, or retain 45-second pending state for them. Report missing launcher/launch errors with a Spotlight ⌘1 fallback.

### FR-23 Zoomed-window work area — P-02 / P1

Observe the active external app’s AX window creation, moves, and resizes. Debounce about 100ms and serialize reads/writes off the UI thread, ignoring notifications generated by the correction itself.

For bottom Docks, a window whose top/bottom are within 12pt of visibleFrame is a height-correction candidate. For side Docks, use left/right edges and adjust width/position. Reserve actual panel position plus resting thickness, without an extra 4pt gap or magnification/tooltip space. Choose the display with greatest overlap and convert to AX top-origin coordinates. Reserve nothing for hidden displays or paused Docks.

Only correct resizable standard windows; exclude minimized, dialogs, ordinary-sized, fullscreen, and unknown-fullscreen windows. Clean up observers/work on app/layout changes and exit. Do not change global NSScreen.visibleFrame. AX support and app minimum sizes limit results.

Remember observed normal frames by AX identity. A corrected window zoomed again restores its remembered frame. Native restore and manual movement update normal history; app switches preserve it, while closed windows, terminated apps, and display layout changes clear it. Never invent an unknown earlier frame.

Interpolate restore position/size over about 180ms using the display link’s newest tick, serial AX work, at most 60Hz, and a one-item backlog. Reduce Motion restores immediately. Cancel on app switch, task cancellation, or external resize. If ticks stop, send a final tick after 400ms and clean up. This is not AppKit’s internal zoom animation.

### FR-24 App-provided Dock menus — P-02 / P1

For a running app, identify its native Dock item by URL, request AXShowMenu, snapshot the menu, then close it. Render app-provided and everyDock commands together beside the selected everyDock icon, including on another monitor. Non-running apps show ordinary commands without AX lookup.

Preserve source titles, enabled/checked state, and submenus. Re-read submenus on navigation, providing Back. Before dispatch, reopen the real menu and validate every path index, title, AX identifier, submenu flag, and enabled state; reject changed commands. Never reuse stale closed-menu AX objects. Bound depth, count, and time off the UI thread and prevent overlapping sessions. Report denial, timeout, unsupported, changed, and API errors in place, without opening Settings. The native menu may briefly appear during reading/dispatch.

### FR-25 File thumbnails — P-04 / P1

Use Quick Look Thumbnailing asynchronously for Desktop/Downloads: up to three requests, 48pt at 2×, aspect ratio preserved, icon fallback. Track popover UUID ownership, task generations, and active requests. Ignore old disappear/appear events and canceled/timed-out results. After eight seconds, cancel a stalled thumbnail and release its slot. Coalesce directory reads per folder.

Keep the old grid while refreshing and apply valid URL/modification-date cached images before publishing the new list. Clicking the same folder toggles its popover; switching folders ends the old session. Cache only the current list, up to 80 items. everyDock does not store/transmit thumbnails; OS Quick Look caches are system-managed. Sort by modification date descending, then natural filename order, and label the sort basis.

### FR-26 Pinned separators — P-06 / P1

Persist pins and custom separators in one ordered list. Old path/bundleIdentifier entries remain apps unless separatorID exists. Store separators using UUIDs and normalized internal paths; do not resolve them as files/apps. Put unpinned running apps between pins and utilities, with automatic section boundaries that are not stored as pins.

Support insertion in gaps or before/after a pin, plus Settings insertion/reorder/removal. Custom separators belong only to the pinned section. Adapt separator hit areas and reusable layers to all three edges, fitting and scrolling with fixed separator widths.

### FR-27 Command-drag ordering — P-06 / P1

Distinguish Command mouse-down from movement beyond 4pt before NSDraggingSession. Preserve ordinary click/Control-click. Validate both private pasteboard type `app.everydock.pinned-item` and a genuine dragging source from the same AppModel; reject external imitation. Keep fileURL drops separate.

Compute insertion slots from displayed item centers, including magnified pins outside the background. Bottom order is horizontal; side order is vertical. Beyond the midpoint separating pinned/running regions, permit unpinning an app with an orange indicator. Reject folders, outside drops, and separator unpinning. Adjust indices after removal; adjacent slots are no-ops, and preserve existing IDs and unaffected order. Pin running apps without bundle duplicates.

Collapse magnification on Command-grab and pause list synchronization, bounce, previews, and intermediate preference writes. Validate app existence at drop time, save only actual changes, then synchronize all panels. Cancel with the normal drag return, without launching/unpinning. Scroll before a drag; no drag auto-scroll or synchronous global scans in the input path.

### FR-28 Startup setup — P-06 / P0

Show OnboardingView when `everyDock.hasLaunched` is false. Set it true only through Get Started or Set Up Later; closing alone is not completion. Preserve existing history and do not reset it when reopening the guide.

Every launch/reopen/general check reads AX and CGPreflight status without ScreenCaptureKit. Missing/denied/error status shows one guide regardless of setup history; a check lasting three seconds can show its progress there. A user-dismissed guide is not reopened by that same check. Activation refreshes hints and login status.

First setup selects login by default; later reopening reflects current registration. Get Started changes registration only if needed and stays open on errors/pending approval. Set Up Later keeps registration. Show only Window Control, Window Previews, and login setup, with detailed location/recovery help in Settings/README. Default height 620pt, minimum 520pt. Never modify the permission database.

### FR-29 Menu bar visibility — P-06 / P1

Default `hideMenuBarIcon` to false, including migration from missing keys. Observe it through Combine and apply NSStatusItem.isVisible. Keep panels/app menus. Explain: “To open Settings, find everyDock in Apps and launch it. Settings opens even if everyDock is already running.”

StartupPresentation prioritizes required setup, then Settings for a manual launch with hidden menu icon, otherwise background launch. Detect login startup from the Apple open event’s keyAEPropData/lgit or explicit login-item parameter. Reopening reuses one Settings/guide window, raising an existing guide. Validate real login and Apps workflows separately.

### FR-30 Homebrew reset removal — P-07 / P1

The cask preflight invokes `--reset-for-uninstall` only for uninstall/reinstall. Upgrade and unknown commands preserve settings. Homebrew uses the installed cask snapshot; older installations need upgrading to adopt new removal rules.

The helper terminates other instances with the same bundle ID and waits up to ten seconds; restores native Dock journals under the existing lock; unregisters SMAppService; clears the entire app UserDefaults domain with removePersistentDomain/synchronize; and removes caches/saved window state. Failure stops removal. Retain the lock inode for racing watchdogs; it contains no options.

Without a bundle, require no running app before defaults deletion/path cleanup. Zap targets only app preferences, caches, and saved state, not unfinished journals. OS privacy decisions remain separate. Test temporary domains/cask fixtures separately from actual login/recovery behavior.

### FR-31 English presentation — P-10 / P1

Use English for all everyDock-owned visible and accessibility text, including errors, menus, setup, settings, utilities, drag hints, and preview actions. Declare `CFBundleDevelopmentRegion=en` and English supported localization. Use singular/plural display/window counts. Retain external app/menu/file/window names and OS-owned dialogs/diagnostics. Preserve stored enum raw values, identifiers, paths, settings keys, and separator UUIDs.

Publish the current README, MRD, PRD, SRS, TC, and release instructions in English. Preserve historical QA evidence rather than rewriting old PASS claims as current results. Keep v0.4.0 a public beta. Validate text coverage, current-document links/anchors, settings migration, and actual layout separately.

## 4. Nonfunctional requirements

| ID | Requirement / acceptance target |
|---|---|
| NFR-01 | arm64 only, LSMinimumSystemVersion=26.0, successful SDK build; mixed-scale multi-display validation. |
| NFR-02 | Target: Apple Silicon, 20 apps, two displays; idle CPU average ≤2% over five minutes, combined RSS ≤200MiB, magnification frame P95 ≤16.7ms, 95% of app state changes ≤1 second. These remain measurement targets. |
| NFR-03 | Target: native Dock restored within five seconds of detected process exit; user edits preserved; no duplicate panels after recovery. |
| NFR-04 | No network/analytics/image-file output. No unapproved automatic capture or retry after denial. |
| NFR-05 | Preserve source/existing destination files, delete nothing on cancellation, back up before Dock edits, preserve user changes during restoration. |
| NFR-06 | English accessibility labels/state, keyboard support, Reduce Motion, light/dark, scale, and VoiceOver validation. |
| NFR-07 | CI/package integrity, tag/bundle agreement, public download checksum, Homebrew fetch/install verification. |
| NFR-08 | Code/docs together, stable requirement IDs, linked tests, dated evidence, explicit limitations. |

CPU uses Activity Monitor’s convention of 100% per logical core. RSS includes app and watchdog. Display-link callback/render duration is not proof of visible frame rate or GPU/WindowServer timing.

## 5. Data and transitions

Preferences are JSON Data under `app.everydock.mac` / `everyDock.preferences.v1`. Pins store path, optional bundle ID, and optional separator UUID. Normalize missing/invalid values: manual icon size 32–72, inset 0–40, magnification 1–4, preview delay 0.2–2; non-finite numbers use defaults. App/window/thumbnail state is in memory. Recovery snapshots retain original/applied bool, number, string, or absent values until restoration succeeds. Do not publish user data, permission databases, private paths, journals, or window images.

| State machine | Failure / cancellation |
|---|---|
| App: stopped → pending → running → active | Report failure and expire stale pending state. |
| Window: active → minimize → restore | Classify AX failures; never substitute app hiding. |
| Dock: unmanaged → backup → watchdog → apply → restore | Keep originals on pre-apply failure; retain failed journals. |
| Preview: closed → delay → query → show → refresh | Cancel stale tasks; distinguish empty/permission/error. |
| Folder: unread → loading → content/empty/error | Waiting guidance, Finder access, one read per folder. |
| Empty Trash: idle → confirmation → deletion → done/error | Cancellation performs no deletion. |

## 6. Limits and references

Legacy DockLayout frame tests do not prove runtime DockCoordinator placement. Device validation remains necessary for Spaces, secure/fullscreen contexts, restoration failures, app AX compatibility, large folders, and minimized/protected images.

Primary API references: [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace), [NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview), [NSView display link](https://developer.apple.com/documentation/appkit/nsview/displaylink(target:selector:)), [SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager), [NSMenu placement](https://developer.apple.com/documentation/appkit/nsmenu/popup(positioning:at:in:)), [AX close button](https://developer.apple.com/documentation/applicationservices/kaxclosebuttonsubrole), [visibleFrame](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe), [AXShowMenu](https://developer.apple.com/documentation/applicationservices/kaxshowmenuaction), [Quick Look](https://developer.apple.com/documentation/quicklookthumbnailing/qlthumbnailgenerator), [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice), [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook).
