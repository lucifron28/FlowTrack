# FlowTrack Backup and Restore

FlowTrack uses local encrypted backup files with the `.flowtrack-backup` extension.
No cloud service is required.

## Backup Contents

Included:

- products
- stock movements
- sales
- sale items
- customers
- credit records
- credit payments
- expenses
- settings
- app metadata
- audit logs

Not included:

- owner password
- secure-storage password salt or hash
- generated barcode PDF files
- temporary cache files

## Backup Format

The new backup file (version 2) is a JSON envelope containing securely encrypted business data:

- `format`: `flowtrack-encrypted-backup`
- `formatVersion`: 2
- `kdf`: Key derivation function details (PBKDF2-HMAC-SHA256, 210,000 iterations, 16-byte random salt)
- `cipher`: Encryption details (AES-256-GCM, 12-byte random nonce, Base64 ciphertext, Base64 MAC)

The encrypted payload internally contains the standard backup JSON structure:
- `metadata`: app name, app version, backup version, database version, and creation time
- `data`: arrays for each backed-up table

Current backup version:

```text
2
```

**Legacy Format Support:**
Legacy version 1 plaintext backups are still supported for restoring, but generating new backups will only produce encrypted version 2 files. The app will warn you before restoring an unencrypted backup.

## Passphrase Responsibility

You must provide a secure passphrase (at least 8 characters) when creating a backup.
**Do not lose your passphrase; a forgotten passphrase cannot be recovered, and your backup will be permanently inaccessible.**

## Owner Flow

Create or share a backup:

1. Open More > Settings.
2. Open Backup and restore.
3. Tap Create and share backup, or Save backup to Downloads.
4. Enter a secure passphrase.
5. Save the file somewhere outside the phone when possible.

Restore a backup:

1. Open More > Settings.
2. Open Backup and restore.
3. Tap Restore backup.
4. Choose a `.flowtrack-backup` file.
5. If encrypted, enter the correct passphrase.
6. Review the backup preview (creation time, row counts).
7. Confirm the overwrite warning.

Restore replaces current local store data transactionally. Owner login is not changed.

## Restore Safety & Atomicity

The app performs complete preflight validation before any current data is cleared:

- expected app name and supported format version
- required metadata fields
- every required table exists and is structurally valid
- constraints are checked: no duplicate primary IDs, barcodes, contacts, sale numbers
- financial data integrity: no negative stock/prices, no over-payments, sale total equals sum of items, customer balance equals active credit remaining
- reversal validity
- 25 MiB file size limit is enforced

If any error occurs during parsing, decryption, or validation, the restore is aborted and the current database remains entirely unchanged.

## Current Limits

- Restore has Android file picker QA pending on target devices.
- There is no CSV export yet.
- There is no automatic scheduled backup yet.
