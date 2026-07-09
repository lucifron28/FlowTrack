# FlowTrack Release and Demo Checklist

FlowTrack is the final app name. The Android application ID and namespace are `com.flowtrack.app`.

## Demo Readiness

- Load or reset demo data from More > Settings > Demo data.
- Confirm the app opens and works in airplane mode after login.
- Test scanner permission denial and manual barcode entry.
- Test scanning with `demo/qa-barcode-sheet.svg` and individual images in `demo/barcodes/`.
- Complete one cash sale and verify amount received, change, stock deduction, dashboard, and reports.
- Complete one credit sale and verify customer outstanding balance.
- Record a credit payment and verify oldest-first allocation.
- Add an expense and verify dashboard/report net income.
- Void a completed sale and verify inventory/report changes.
- Save or share a tingi barcode PDF from a store-generated product.
- Create/share a `.flowtrack-backup` file, then restore it on a test install.

## Android Identity

- App name: FlowTrack.
- Application ID: `com.flowtrack.app`.
- Namespace: `com.flowtrack.app`.
- Launcher label: `android/app/src/main/res/values/strings.xml`.
- Launcher icon: pending final icon asset from owner.

## Release Signing

Release signing is prepared but not configured with real keys in the repo.

1. Generate or provide the release keystore locally.
2. Copy `android/key.properties.example` to `android/key.properties`.
3. Fill in `storePassword`, `keyPassword`, `keyAlias`, and `storeFile`.
4. Keep `android/key.properties` and keystore files private. They are ignored by Git.
5. Run:

```bash
flutter build apk --release
```

If `android/key.properties` is missing, the release build falls back to debug signing for local development only. Do not ship a debug-signed APK.

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

- Final launcher icon.
- Real release keystore and private `android/key.properties`.
- Physical Android QA on target phone.
- Scanner QA under real lighting and barcode sizes.
- Barcode PDF save/share QA.
- Backup restore QA with a real `.flowtrack-backup` file.
- Report export decision.
