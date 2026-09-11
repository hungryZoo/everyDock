# TC — Test Cases

| Field | Value |
|---|---|
| Document version | 1.13 / 2026-09-11 |
| Target | everyDock v0.4.0, Apple Silicon, macOS 26+ |
| Requirements | [SRS](SRS.md), [traceability](README.md) |
| Current results | [QA-v0.4.0](QA-v0.4.0.md) |

## 1. Execution rules

PASS applies only to the recorded environment and procedure. PARTIAL, BLOCKED, and NOT RUN are not full passes. Keep OS/chip/display/app/commit/permission details and reproducible failures. Remove private window titles, account paths, and document contents from public evidence. Use dummy files in a separate test account for destructive tests; never empty the user's real Trash as a test.

| Environment | Setup |
|---|---|
| E1 | Apple Silicon, macOS 26+, two displays, release app, 5–20 apps. |
| E2 | Three displays, negative X/Y origins, mixed Retina scales, all Dock edges. |
| E3 | AX and capture permission allowed/denied/revoked/re-registered after update. |
| E4 | Separate test user with dummy Desktop/Downloads/Trash files. |
| E5 | Fresh checkout, Xcode 26+, Homebrew, no existing everyDock installation. |
| E6 | Korean and English macOS; old preferences, English app text, multilingual external content. |

## 2. Automated regressions

Run `swift test --arch arm64`; set `EVERYDOCK_RUN_QL_TEST=1` for the real Quick Look integration. Test IDs are stable and do not equal the current executable test count. TC-A31 and TC-A38 are retired. Legacy DockLayout tests validate pure geometry, not live DockCoordinator placement. Historical PASS statements are not carried forward automatically.

| ID | Test / source | Expected result | Requirements |
|---|---|---|---|
| TC-A01 | `positionsOnDisplaysWithNegativeOrigins` / DockLayoutTests | Negative display origins and all three edges stay within the calculated area. | NFR-01, FR-01 |
| TC-A02 | `overflowingDockFitsScreen` / DockLayoutTests | Overflowing layouts fit an 800×600 screen with margins. | NFR-01, FR-03 |
| TC-A03 | `bottomUsesUsableAreaAboveNativeDock` / DockLayoutTests | Bottom placement respects the native Dock’s visibleFrame. | FR-02 |
| TC-A04 | `preferencesRoundTripAndNormalize` / DockLayoutTests | Normalize bounds and duplicate bundles; preferences round-trip. | FR-16, FR-17 |
| TC-A05 | `magnificationIsContinuousAndAffectsNeighbors` / DockBehaviorTests | Magnification is continuous, symmetric, and affects neighbors. | FR-04 |
| TC-A06 | `oldPreferencesMigrateWithoutLosingPins` / DockBehaviorTests | Old preferences retain pins and edge values while new fields get defaults. | FR-17 |
| TC-A07 | `recoveryRestoresAbsentValuesButPreservesUserEdits` / DockBehaviorTests | Restore original/absent values and preserve user edits. | FR-09, NFR-05 |
| TC-A08 | `utilityTilesAreIncludedInDockWidth` / DockMetricsTests | Include utility tiles in length and thickness. | FR-03 |
| TC-A09 | `nativeMagnificationIsNotClampedToTwoTimes` / DockMetricsTests | Preserve native magnification above 2×. | FR-03 |
| TC-A10 | `genieSettingParticipatesInSafeRecovery` / DockMetricsTests | Include the Genie preference in safe recovery. | FR-08, FR-09 |
| TC-A11 | `permissionDenialIsNotAWindowCapabilityError` / RegressionTests | Distinguish AX denial, timeout, no-window, unsupported, and invalid-object errors. | FR-06, FR-18 |
| TC-A12 | `onlyScreenCaptureUserDeclinedMeansPermissionDenied` / RegressionTests | Only the correct ScreenCaptureKit userDeclined error is permission denial. | FR-14, FR-18 |
| TC-A13 | `animationProgressDependsOnTimeNotRefreshRate` / RegressionTests | Equal elapsed time produces equal progress at 60/120Hz and irregular intervals. | FR-04, NFR-02 |
| TC-A14 | `panelAlignmentIsStableAcrossFractionalAndNegativeCoordinates` / RegressionTests | Pixel alignment is stable for fractional/negative coordinates and display scales. | FR-01, FR-03 |
| TC-A15 | `iconControlCancelsReleaseOutsideAndTracksDragBackInside` / DockControlTests | Release outside cancels; dragging back inside activates once and ends tracking. | FR-04 |
| TC-A16 | `iconControlSupportsAccessibilityPressWithoutMouseTracking` / DockControlTests | Accessibility Press activates once without mouse tracking. | FR-04, NFR-06 |
| TC-A17 | `iconControlSupportsSpaceAndReturn` / DockControlTests | Space and Return activate once each. | FR-04, NFR-06 |
| TC-A18 | `captureMetadataNeverAddsGhostWindows` / WindowMatchingTests | Extra capture metadata never creates ghost AX window cards. | FR-14 |
| TC-A19 | `sameTitleWindowsKeepSeparateOneToOneImages` / WindowMatchingTests | Same-title windows receive distinct one-to-one images. | FR-14 |
| TC-A20 | `missingMinimizedAndMovedWindowsDoNotBorrowAnotherImage` / WindowMatchingTests | Missing, moved, or minimized windows do not borrow another window’s image. | FR-14 |
| TC-A21 | `menuPlacementUsesIconEdgeAndClampsNegativeScreens` / WindowMatchingTests | Menus use the icon’s edge and remain within negative-origin screens. | FR-21 |
| TC-A22 | `tooltipCentersTextVerticallyAtDifferentHeights` / DockControlTests | English and multilingual external titles remain vertically centered. | FR-21 |
| TC-A23 | `closeAllStopsAtSaveConfirmation` / WindowCloseTests | Close All stops when a save confirmation is pending. | FR-20 |
| TC-A24 | `closeAllSkipsAlreadyClosedButStopsAtErrors` / WindowCloseTests | Skip already-closed windows and stop at an error. | FR-20 |
| TC-A25 | `closeAllCompletesOnlyItsInitialSnapshot` / WindowCloseTests | Close only the initial window snapshot, once per item. | FR-20 |
| TC-A26 | `previewFitsOneTwoAndManyWindows` / WorkAreaTests | Zero/one/two/nine preview cards produce correct columns, width, and height. | FR-14 |
| TC-A27 | `bottomZoomReservesOnlyRestingDockAndIsIdempotent` / WorkAreaTests | Bottom zoom reserves only the resting Dock and is idempotent. | FR-23 |
| TC-A28 | `workAreaPreservesNormalMinimizedAndFullScreenWindows` / WorkAreaTests | Normal, minimized, and fullscreen windows remain unchanged. | FR-23 |
| TC-A29 | `sideDockReservesCorrectEdgeOnNegativeDisplays` / WorkAreaTests | Side Docks reserve the correct edge on negative-origin displays. | FR-23 |
| TC-A30 | `appsLauncherIsNotTreatedAsRegularWindowApplication` / ApplicationCatalogTests | System Apps launchers are classified separately from ordinary apps. | FR-22 |
| TC-A31 | RETIRED (2026-09-10) | Retired when the internal Apps catalog was removed; do not reuse this ID. | FR-22 |
| TC-A32 | `correctedZoomRestoresOriginalForThreeCycles` / WindowZoomStateTests | Corrected zoom returns to the original position/size for three cycles. | FR-23 |
| TC-A33 | `nativeRestoreAndManualResizeUpdateTheSavedFrame` / WindowZoomStateTests | Native restore and manual resizing update the remembered normal frame. | FR-23 |
| TC-A34 | `observerReattachmentPreservesRestoreAndUnknownHistoryIsNotInvented` / WindowZoomStateTests | Observer reattachment preserves history; unknown history is not invented. | FR-23 |
| TC-A35 | `sideZoomRestoresPositionAndSizeWithoutMovingToDisconnectedDisplay` / WindowZoomStateTests | Side zoom restores position/size without returning to a disconnected display. | FR-23 |
| TC-A36 | `newestModifiedFilesSortFirstWithStableNameTies` / WindowZoomStateTests | Sort newest modified files first with natural filename ties. | FR-10, FR-11, FR-25 |
| TC-A37 | `restoreAnimationHasExactEndpointsAndMonotonicGeometry` / WindowZoomStateTests | Restore animation has exact endpoints and monotonic geometry. | FR-23 |
| TC-A38 | Retired same-display restriction; do not reuse this ID | Retired in v0.3.4; the same-display restriction is no longer required. | FR-24 |
| TC-A39 | `nativeMenuSelectionRejectsChangedCommands` / NativeMenuIdentityTests | Reject changed native commands by index, title, identifier, and submenu state. | FR-24 |
| TC-A40 | `separatorsMigratePersistAndMoveAlongsidePins` | Migrate, persist, reorder, and deduplicate separators alongside pins. | FR-26 |
| TC-A41 | `separatorGeometryUsesFixedWidthAndTwoSectionBoundaries` | Fixed-width separators and both section boundaries affect geometry correctly. | FR-26 |
| TC-A42 | `latePopoverCloseCannotCancelReopenedFolder` | Late closure of an earlier folder cannot cancel a reopened session. | FR-25 |
| TC-A43 | `quickLookThumbnailSurvivesTenReopens`  | Generate a real Quick Look PNG thumbnail and preserve it over ten reopenings. | FR-25 |
| TC-A44 | `commandDragInsertionPreservesOrderAndAdjacentSlots` | Reorder pins/separators, retaining IDs; adjacent insertion slots are no-ops. | FR-27 |
| TC-A45 | `commandDragPinsRunningAppWithoutDuplicates` | Pin a running app without duplicate bundle IDs, including empty/boundary cases. | FR-27 |
| TC-A46 | `initialSetupAndHiddenMenuLaunchesHaveReachableWindows` | First setup and hidden-menu/manual/login launches retain reachable windows. | FR-28, FR-29 |
| TC-A47 | `menuIconVisibilityMigratesAndPersistsWithoutChangingPins` | Migrate and persist menu visibility without changing pins. | FR-29 |
| TC-A48 | uninstallClearsEntirePreferenceDomainAndFirstRunHistory | Remove the full temporary preference domain, including first-run/window state. | FR-30 |
| TC-A49 | missingPermissionsAlwaysReopenGuidanceEvenAfterOnboarding | Missing permission prioritizes guidance after onboarding for all launch modes. | FR-28 |
| TC-A50 | backgroundCaptureNeverRequestsMissingPermission | Missing-permission background requests call no capture API; only an explicit request proceeds. | FR-14 |
| TC-A51 | denialAndRevocationStopBackgroundCaptureEvenWithStaleHints | Revocation and actual denial block automatic capture even with stale positive hints. | FR-14 |

## 3. Manual regressions

Use the matching environments above and the SRS detail for the linked behavior. Current execution status is in QA-v0.4.0; prior version observations remain in their dated QA records. Test only disposable windows/files when a procedure closes or deletes content.

| ID | Procedure and expected result |
|---|---|
| TC-M01 | Connect two displays and launch; expect one Dock on each enabled screen without duplicates. |
| TC-M02 | Place displays at negative X/Y origins; panels and input stay on the intended screen. |
| TC-M03 | Disconnect/reconnect and sleep/wake; recover panels without duplicates or stale popovers. |
| TC-M04 | Toggle separate Spaces and switch Spaces; record behavior on each display. |
| TC-M05 | Test fullscreen/Stage Manager and all-displays-disabled recovery through Settings. |
| TC-M06 | Compare native/manual sizing, utilities, overflow, and all three edges. |
| TC-M07 | Sweep, stop, leave, and click across icons; magnification stays stable and empty space passes clicks through. |
| TC-M08 | Launch/quit apps externally and through the Dock; feedback is prompt and focus does not reorder apps. |
| TC-M09 | With AX access, repeat active-app minimize ten times; use actual window minimization, not hiding. |
| TC-M10 | Restore multiple minimized windows, then select a single preview; verify target identity. |
| TC-M11 | Deny AX access; minimize explains the issue while launch, Settings, and Quit remain usable. |
| TC-M12 | Record native Dock values and absent keys; toggle management and verify restoration. |
| TC-M13 | Terminate only the main process with SIGTERM/SIGKILL; verify watchdog restoration within the target time. |
| TC-M14 | Edit native Dock values during management; preserve those user edits on exit. |
| TC-M15 | Restart with valid and damaged recovery journals; recover valid state without overwriting unrelated values. |
| TC-M16 | Open/reopen Desktop with allowed/denied access; show files without hiding other apps. |
| TC-M17 | Open Downloads with denied/pending access; show waiting guidance and coalesce reads. |
| TC-M18 | Use an empty folder and 90 dummy files; verify newest 80, date changes, and default-app opening. |
| TC-M19 | Move dummy files to Trash externally; verify open behavior and empty/full icon refresh. |
| TC-M20 | Open Empty Trash confirmation and cancel, including Return; delete nothing. |
| TC-M21 | In a separate test account containing only dummy Trash, test recycle/restore and confirmed emptying; exclude external-drive Trash. |
| TC-M22 | Drop dummy files on folders; preserve source/existing destination hashes for conflicts, same paths, read-only targets, and partial failures. |
| TC-M23 | Hover with capture unavailable and move into/out of the popover; keep it reachable without automatic permission prompts. |
| TC-M24 | Use 1/8/9 windows and changing content; refresh only matching images, with at most eight captures and protected-content fallback. |
| TC-M25 | Use missing images, same-title/untitled/minimized windows; show truthful title/icon/state fallbacks. |
| TC-M26 | Select a specific card on another display; a disappeared target falls back to app activation rather than another window. |
| TC-M27 | Rapidly alternate targets, disable previews, detach a display, and expire caches; reject stale work. |
| TC-M28 | Import/add/drop/move/unpin apps and move their files; deduplicate and resolve by bundle ID. |
| TC-M29 | Relaunch with old, missing-key, out-of-range, and damaged preferences; preserve valid choices and normalize safely. |
| TC-M30 | In a test account, enable/disable login and log out/in; match registration and approval state. |
| TC-M31 | Start a second bundle instance; do not duplicate panels/watchdogs. |
| TC-M32 | Grant, deny, revoke, relaunch, and upgrade permissions; show accurate status without endless requests. |
| TC-M33 | Test light/dark, Reduce Motion/Transparency, scaling, keyboard, and VoiceOver without clipping or lost controls. |
| TC-M34 | Use right-click, Control-click, and ShowMenu at every edge; freeze layout during tracking and resume afterward. |
| TC-M35 | Use one window, three same-title windows, renamed/minimized/closed windows; one card per actual AX window. |
| TC-M36 | Close all normal Finder windows, then click Finder; reopen without trying to minimize the desktop. |
| TC-M37 | Hover English and multilingual app names at 1×/2×; center text without clipping. |
| TC-M38 | Close one card and all three fixture windows, then Finder; keep the app running and update counts. |
| TC-M39 | Use a modified fixture document and cancel its save prompt; preserve remaining/new windows without bypassing confirmation. |
| TC-M40 | Open previews via menu, dismiss outside, hover again, and close cards; reject stale presentation and selection/close confusion. |
| TC-M41 | Change fixture count 3→2→1→0 and reopen; fit width/height without an empty extra column. |
| TC-M42 | Rapidly open Desktop/Downloads with allowed/denied/empty states; use correct content and one directory request. |
| TC-M43 | Click Apps, search, close, and reopen; show Spotlight’s app browser without minimizing the launcher. |
| TC-M44 | Repeat title-bar zoom/restore three times across edges/displays; meet resting Dock boundary and restore observed size smoothly. |
| TC-M45 | Test fullscreen, minimized, manual resize, hidden display, app exit, and AX denial; exclude unsupported states and clean observers. |
| TC-M46 | Open app-provided menus, including an app missing from the native Dock; show commands or an in-place explanation. |
| TC-M47 | Use image/PDF/unsupported files and modified/rapidly reopened folders; preserve aspect ratio, limits, cancellation, and newest-first order. |
| TC-M48 | Open a fixture app menu on each monitor and invoke a command; show locally and deliver to the correct app. |
| TC-M49 | Test disabled entries, submenus, Back, Escape, and outside dismissal; reject disabled commands and restore input. |
| TC-M50 | Change/quit the source app after menu read, deny AX, or time out; reject stale commands and keep regular commands usable. |
| TC-M51 | Right-click a running fixture/app once; show native and everyDock commands together without another entry step. |
| TC-M52 | Exercise integrated submenus/basic actions, non-running apps, lookup failure, Control-click, and ShowMenu consistently. |
| TC-M53 | Insert separators in gaps/before/after apps, remove/reorder in Settings, and restart; preserve order and UUIDs. |
| TC-M54 | Test pinned/running/folder ordering on side/narrow/multiple displays as apps launch/quit; separators never magnify or preview. |
| TC-M55 | Reopen/switch folders ten times with changed and slow/failed thumbnails; retain images and enforce three requests/eight-second release. |
| TC-M56 | Command-grab collapses magnification; reorder pins/separators and verify every screen, Settings, and persistence. |
| TC-M57 | Test Command-click, movement below 4pt, Escape, invalid drops, and normal/Control clicks; cancellation does not launch or unpin. |
| TC-M58 | Pin/unpin across monitors and edges, reject separator unpin and vanished targets, handle overflow, and recover input after cancellation. |
| TC-M59 | First launch/close/relaunch/Set Up Later/upgrade shows one guide when required and preserves existing options on upgrade. |
| TC-M60 | Permission actions lead to the proper settings and distinguish errors; detailed status/location help is now in Settings (see M65). |
| TC-M61 | Apply login on/off, pending approval, registration failure, later setup, and reopened guide; match current choices without automatic approval. |
| TC-M62 | Hide/show the menu icon; reopen from Apps manually and through login; Settings remains reachable and permitted login is quiet. |
| TC-M63 | Check startup/reopen with allowed/denied/error/slow permissions; show one guide, no capture request, and respect dismissal for the same check. |
| TC-M64 | Uninstall/reinstall the released app; stop instances, restore native Dock, unregister login, and reset options/history separately from OS consent. |
| TC-M65 | Fresh launch/reopen/hover does not request missing screen access; only the permission button requests, denial stops retries, and setup has no redundant bottom section. |
| TC-M66 | On Korean and English macOS, inspect everyDock-owned setup/settings/menu/utility/preview/AX text for English and fitting; preserve external names and old preferences. |

M01–05 map to FR-01/02; M06–11 to FR-03–07/18; M12–15 to FR-08/09; M16–22 to FR-10–13; M23–27 to FR-14/15; M28–33 to FR-16–18 and NFR-06; M34–40 to FR-20/21/14/15; M41–47 to FR-10/11/14/22–25; M48–52 to FR-21/24; M53–55 to FR-25/26; M56–58 to FR-27; M59–63 to FR-28/29; M64 to FR-30; M65 to FR-14/28; M66 to FR-31 and NFR-06.

M44 does not require reconstructing a size never observed before startup. It additionally tests Reduce Motion, app-switch cancellation, and absence of a spare 4pt gap. M60's original setup-bottom controls were superseded by M65. Original show-desktop and same-monitor-only native-menu behavior is historical, not a current acceptance condition.

## 4. Performance and privacy

These targets require real measurements. Display-link callback/render timing alone does not prove delivered visual FPS, WindowServer, or GPU performance.

| ID | Procedure and acceptance | Requirements |
|---|---|---|
| TC-P01 | 20 apps, two displays, one-minute warmup, five-minute idle: average CPU ≤2%, combined app/watchdog RSS ≤200MiB. | NFR-02 |
| TC-P02 | Instruments: 30-second pointer sweep and 30 preview cycles; frame P95 ≤16.7ms and no continuing idle memory growth. | NFR-02 |
| TC-P03 | 20 external launch/quit cycles and five display reconnects; app state 95% ≤1s, display recovery target 2s, AX latency does not stall animation. | FR-01/07, NFR-02 |
| TC-P04 | Observe process networking/file writes during previews; no remote transfer/image writes or unapproved background permission requests. | NFR-04 |

## 5. Distribution and documentation

| ID | Procedure and expected result | Requirements |
|---|---|---|
| TC-R01 | Tests, package script, lipo/codesign/plist: arm64, minimum macOS26, matching bundle/ZIP version, valid signature. | FR-19, NFR-01/07 |
| TC-R02 | Read public repo/docs/release without authentication; compare tag/source; exclude private data and secrets. | FR-19, NFR-08 |
| TC-R03 | Download public ZIP again; published checksum, cask SHA, and archive hash match; extracted signature verifies. | FR-19, NFR-07 |
| TC-R04 | Cask style/audit/info/fetch: correct syntax, platform constraints, and download integrity. Strict/notarization audit is a separate result. | FR-19 |
| TC-R05 | Fresh install/launch/permission setup and next-version upgrade; preserve options on upgrade and explain re-registration when needed. | FR-18/19 |
| TC-R06 | Normal quit/uninstall/reinstall: app removal and Dock restoration; since v0.3.9, reset settings/login while preserving unfinished journals. | FR-09/19/30, NFR-05 |
| TC-R07 | Historical v0.3.8 opt-in zap fixture: ordinary uninstall preserved preferences, zap removed three paths and first-run cache while retaining journals. Superseded by R08; do not reuse the ID. | FR-30 |
| TC-R08 | Install/upgrade/reinstall/uninstall an isolated artifact cask: preserve on upgrade, invoke reset on reinstall/removal without touching user data. | FR-30 |
| TC-R09 | Scan app-owned source/current docs for untranslated Korean, inspect English bundle metadata, render README through GitHub Markdown, and check links/anchors. Preserve multilingual test inputs and historical evidence. | FR-31, NFR-08 |

## 6. Evidence and release gates

### Unreleased icon rendering checks — FR-03 / P-02

| ID | Check | Result (2026-09-11) |
|---|---|---|
| TC-A52 | `iconArtworkKeepsRetinaPixelsAndReusesTextureDuringMagnification`: 576px rendered vector artwork at 2×, trilinear filtering, same CGImage through repeated size changes. | PASS |
| TC-A53 | `iconArtworkSelectsHighResolutionRepresentation`: distinguish 32px and 1024px source representations by color; choose high-resolution artwork. | PASS |
| TC-M67 | Compare resting/maximum-magnified app and utility icons on 1×/2× displays, reconnect/move displays, check aspect ratio and smooth motion. | NOT RUN |

These changes are local and unreleased. Published v0.4.0 evidence below is unchanged. No new on-screen frame-time or GPU measurements have been performed.

Validation on macOS 26.5.2 / arm64: `swift test --arch arm64` completed successfully (51 discovered tests; the opt-in Quick Look integration was skipped). Both new icon tests passed. Release build and strict code-signature verification passed. The local build was copied to `dist/everyDock.app` and `/Applications/everyDock.app` after normal quit, then launched. Homebrew assets/tags remain unchanged. TC-M67 still requires visual verification.

Current results: [QA-v0.4.0](QA-v0.4.0.md). Historical records: [initial QA](../QA.md), [v0.3.1](QA-v0.3.1.md), [v0.3.2](QA-v0.3.2.md), [v0.3.3](QA-v0.3.3.md), [v0.3.4](QA-v0.3.4.md), [v0.3.5](QA-v0.3.5.md), [v0.3.6](QA-v0.3.6.md), [v0.3.7](QA-v0.3.7.md), [v0.3.8](QA-v0.3.8.md), [v0.3.9](QA-v0.3.9.md), [v0.3.10](QA-v0.3.10.md). Historical records retain their original language and version-specific scope.

A defect report includes TC ID, expected/actual behavior, reproduction count, environment, permissions, commit, and redacted evidence. File loss, failed restoration, launch failure, or duplicate panels are P0. Assess interaction defects by task impact.

Beta release requires relevant build/distribution checks and honest disclosure of missing observations. Stable promotion requires P0 manual tests, file preservation, permission-enabled workflows, measured performance, installation/update/removal, and notarization. Do not describe the entire suite as passed while manual cases remain.
