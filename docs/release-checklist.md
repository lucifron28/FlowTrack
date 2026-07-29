# FlowTrack Release and Demo Checklist

FlowTrack is the final app name. The Android application ID and namespace are `com.flowtrack.app`. Canonical version is `1.0.0+1`.

## Pre-Release Verification & Hygiene

- [ ] Repository clean-state check (`git status --short`).
- [ ] Secret and tracked file audit (`git ls-files` check for keys, `.env`, `.db`, `.flowtrack-backup`, APKs).
- [ ] Code formatting check (`dart format --output=none --set-exit-if-changed lib test`).
- [ ] Static analysis gate (`flutter analyze` with 0 warnings/errors).
- [ ] Automated test gate (`flutter test` passing 100%).
- [ ] Generated Drift code integrity (`dart run build_runner build --delete-conflicting-outputs`, `git diff --exit-code`).
- [ ] Production-mode build verification (`flutter build apk --debug --dart-define=FLOWTRACK_MODE=production`).
- [ ] Application ID (`com.flowtrack.app`), version name (`1.0.0`), and version code (`1`) verification via AAPT/apkanalyzer.
- [ ] Artifact SHA-256 hash recording for release candidate build.

## Demo & Manual QA Readiness

- [ ] Run or install FlowTrack with `FLOWTRACK_MODE=demo`.
- [ ] Load or reset demo data from More > Settings > Demo data.
- [ ] Airplane-mode QA: confirm full app function without internet connection.
- [ ] Camera denial & manual entry QA: deny camera permission and complete sale using manual barcode entry.
- [ ] Scanner QA with `demo/qa-barcode-sheet.svg` and individual images in `demo/barcodes/`.
- [ ] Small-screen (320px width) & large-text (200% text scale) layout QA.
- [ ] Cash sale flow: amount received, change calculation, stock deduction, dashboard update.
- [ ] Credit sale flow: customer balance update, debt record creation.
- [ ] Credit payment flow: oldest-first debt allocation, partial payment, payment reversal.
- [ ] Expense flow: creation, categorization, voiding, net income update in reports.
- [ ] Barcode PDF export & share QA.
- [ ] Financial report PDF export & share QA.
- [ ] Backup create/restore smoke test with passphrase-protected `.flowtrack-backup` file.

## Android Identity

- App name: FlowTrack.
- Application ID: `com.flowtrack.app`.
- Namespace: `com.flowtrack.app`.
- Launcher label: `android/app/src/main/res/values/strings.xml`.
- Launcher icon: pending final icon asset from owner.

## Release Signing & Policy

Release signing is prepared but not configured with real keys in the repository.

1. Generate or provide the release keystore locally.
2. Copy `android/key.properties.example` to `android/key.properties`.
3. Fill in `storePassword`, `keyPassword`, `keyAlias`, and `storeFile`.
4. Keep `android/key.properties` and keystore files private. They are ignored by Git.
5. Run:

```bash
flutter build apk --release --dart-define=FLOWTRACK_MODE=production
```

**Policy:**
- If `android/key.properties` is missing, the release build fails closed immediately.
- Production releases must NEVER silently use debug signing.
- Debug-signed demo APKs must be clearly documented as non-production artifacts and MUST NOT be distributed as production releases.

## GitHub Demo Release

The repository includes `.github/workflows/demo-release.yml` for demo APK releases.

- Trigger: push a tag matching `v*`, or run the workflow manually from GitHub Actions.
- Output: a debug-signed APK attached to a GitHub prerelease.
- Intended use: phone QA, walkthroughs, and client demo installation.
- Not intended for production distribution or Play Store upload.

Suggested demo tag pattern:

```bash
v1.0.0-demo.1
```

Before tagging, make sure the release branch has been merged into `main`.

## Final Release Blockers

- Final launcher icon asset.
- Real release keystore and private `android/key.properties`.
- Physical Android device QA on target phone.
- Physical scanner QA under real store lighting and barcode sizes.
- Barcode and report PDF save/share QA on target device file system.
- Encrypted backup restore QA with a real `.flowtrack-backup` file on target device.
- CSV export decision.
