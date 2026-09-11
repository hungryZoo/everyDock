# Releases and Homebrew Distribution

Baseline: 2026-09-11. Source: [hungryZoo/everyDock](https://github.com/hungryZoo/everyDock). Cask: [hungryZoo/homebrew-tap](https://github.com/hungryZoo/homebrew-tap/blob/main/Casks/everydock.rb).

## 1. Version and validation

Update the version/build in `Resources/Info.plist`; Settings reads bundle metadata. Keep MRD, PRD, SRS, TC, README, and the current QA record aligned. Do not mark untested features as passed.

```bash
swift test --arch arm64
EVERYDOCK_RUN_QL_TEST=1 swift test --arch arm64
./scripts/package-release.sh
```

Packaging uses a temporary staging directory so it does not overwrite a running `dist/everyDock.app`. It checks arm64 and minimum macOS 26, strips debug symbols, re-signs, and verifies the bundle. Output: `dist/releases/everyDock-<version>-arm64.zip` and `SHA256SUMS`. Include only the app, never user settings, journals, screenshots, or private files.

Default signing is ad-hoc. `CODE_SIGN_IDENTITY` can select another identity; the script does not perform notarization. Developer ID, hardened runtime, notarization, and stapling remain stable-release work.

## 2. Pre-release review

- Review staged source/docs/scripts; exclude `.build`, `dist`, credentials, permission databases, and user data.
- Require the final source CI to pass tests and packaging on macOS 26 arm64.
- Record TC-R01–04 evidence and limits. English presentation/documentation checks are TC-R09; actual visual checks are TC-M66.
- Review new UI text in English while preserving external content and storage identifiers.
- Render README with GitHub’s Markdown API and check links/anchors before committing:

```bash
gh api markdown -f mode=gfm -f context=hungryZoo/everyDock -F text=@README.md > .build/readme.html
```

The owner’s [agents-dev-skills](https://github.com/hungryZoo/agents-dev-skills) supplies the README, Homebrew, and release-note conventions. Do not fabricate missing demo media or license terms.

## 3. Publish a release

Write new notes under `.github/release-notes/v<version>.md`; earlier notes remain under `docs/releases`. Notes lead with user-visible changes since the previous release, repeat the official installation sequence, and include checksum verification. Substitute the new version and reviewed commit before running these commands:

```bash
git tag -a v<version> <commit> -m 'everyDock v<version> public beta'
git push origin v<version>
gh release create v<version> \
  dist/releases/everyDock-<version>-arm64.zip \
  dist/releases/SHA256SUMS \
  --repo hungryZoo/everyDock --verify-tag --prerelease \
  --title 'everyDock v<version> — <headline>' \
  --notes-file .github/release-notes/v<version>.md
```

These are placeholders, not commands to paste unchanged. Never overwrite a published tag or asset. Check the public release page and attached assets after publishing. [GitHub release documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).

## 4. Update the tap

Use a separate checkout and preserve unrelated packages. Change version/checksum for the pinned release URL in `Casks/everydock.rb`. Verify the SHA-256 against an unauthenticated download of the published asset. Beta livecheck does not automatically promote releases.

```bash
brew tap hungryZoo/tap
brew trust --cask hungryZoo/tap/everydock
brew style hungryZoo/tap/everydock
brew audit --cask hungryZoo/tap/everydock
brew fetch --cask hungryZoo/tap/everydock
```

Record ordinary audit separately from online/strict/notarization checks, which can fail for the ad-hoc beta. The legacy uninstall_preflight hook has a documented style exception because its removal-versus-upgrade decision must happen at runtime. Do not hide Homebrew warnings.

Use a fresh installation or isolated test environment for install coverage. `brew reinstall` deliberately resets preferences, so do not use it as a settings-preserving upgrade test. Verify the app-scoped quarantine step and launch instructions from README. Cask scripts do not disable Gatekeeper or clear quarantine automatically.

Uninstall/reinstall invokes the cleanup helper; upgrade preserves settings. Cleanup stops the app, restores the native Dock, unregisters login, and clears preferences/caches. Installed cask snapshots determine uninstall behavior. Zap excludes unfinished recovery journals. See [README](../README.md) for user commands.

References: [Tap maintenance](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap), [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook), [Tap Trust](https://docs.brew.sh/Tap-Trust).

## 5. Recovery from a bad release

Publish a new patch and checksum rather than replacing an existing ZIP. Explain the defect. An emergency cask disable must state its reason and must not delete existing users’ settings/journals. Rerun migration, upgrade, and reset-removal cases if their behavior changes.

Use the final stripped/re-signed release bundle for OS permission registration and device checks. Do not rebuild that bundle after approval and silently treat the new signature as validated. Record the exact source, asset, installed version, and remaining manual checks.
