# FlowTrack Backup and Restore

FlowTrack uses local JSON backup files with the `.flowtrack-backup` extension.
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

The backup file is JSON with two top-level sections:

- `metadata`: app name, app version, backup version, database version, and creation time
- `data`: arrays for each backed-up table

Current backup version:

```text
1
```

## Owner Flow

Create or share a backup:

1. Open More > Settings.
2. Open Backup and restore.
3. Tap Create and share backup, or Save backup to Downloads.
4. Save the file somewhere outside the phone when possible.

Restore a backup:

1. Open More > Settings.
2. Open Backup and restore.
3. Tap Restore backup.
4. Confirm the overwrite warning.
5. Choose a `.flowtrack-backup` file.

Restore replaces current local store data. Owner login is not changed.

## Restore Safety

The app rejects:

- invalid JSON
- backups not marked for FlowTrack
- unsupported backup versions
- backups missing required table sections

Rows are restored directly so product IDs, sale IDs, sale item snapshots,
customer balances, credit payment status, and audit history remain intact.

## Current Limits

- Backups are not encrypted yet.
- Restore has Android file picker QA pending on target devices.
- There is no CSV export yet.
- There is no automatic scheduled backup yet.
