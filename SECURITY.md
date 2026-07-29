# FlowTrack Security Policy

## Security Model & Boundary

FlowTrack is an offline-first mobile application designed to operate entirely locally on the user's Android device without external servers or cloud dependencies.

### Local Data Protection
- Business data (inventory, sales, credits, expenses, store settings) is stored in a local SQLite database using standard Android file permissions.
- Physical device security (device PIN/passcode and storage encryption) forms the primary security layer for local data.

### Owner Authentication
- Owner credentials and sensitive authentication parameters are stored in Android KeyStore-backed secure storage via `flutter_secure_storage`.
- Owner authentication hashes and salts are strictly excluded from backup files.

### Encrypted Backups
- Generated `.flowtrack-backup` files (version 2) use AES-256-GCM encryption with keys derived via PBKDF2-HMAC-SHA256 (210,000 iterations and random salt).
- The user is solely responsible for creating and remembering the backup passphrase. Lost passphrases cannot be recovered.
- Legacy version 1 plaintext backups trigger an explicit UI warning before restoring.

### Android Permissions & Boundaries
- `android.permission.CAMERA`: Used exclusively for real-time barcode scanning. Manual barcode entry remains fully functional if camera access is denied.
- `android.permission.INTERNET`: Strictly limited to Flutter development/debug builds for hot reload and debugging tools. Production Android manifests contain zero internet permissions.

### Release Signing Policy
- Production release builds require private release signing configured via untracked `android/key.properties`.
- Build configurations fail closed if release signing keys are absent. Debug-signed APKs must never be distributed as production software.

## Reporting Security Vulnerabilities

If you discover a security vulnerability or secret leakage risk in FlowTrack:
1. Do not open a public GitHub issue detailing the vulnerability.
2. Contact the maintainer directly or follow private reporting channels.
3. Provide a clear description and steps to reproduce without publishing sensitive machine information.

## Known Security Boundaries & Physical Prerequisite
- FlowTrack relies on the underlying Android operating system to restrict file access to the app sandbox.
- Devices that are rooted or compromised lose OS sandbox guarantees.
- Physical device verification and secure device locking are required for production operation.
