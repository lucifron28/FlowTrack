# Changelog

All notable changes to FlowTrack will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - Unreleased

### Added
- Offline-first sari-sari store management app with local Drift/SQLite database storage.
- Sales counter supporting cash and utang (credit) sales with automatic stock deduction and customer balances.
- Inventory tracking with product creation, low-stock warnings, stock history preview, barcode generation, and PDF printing.
- Debtor/Credit management with oldest-first credit payment allocation and transaction history.
- Expense monitoring with category classification, description, and voiding functionality.
- Financial reporting with daily and custom period summaries and PDF export.
- AES-256-GCM encrypted backup and restore system (`.flowtrack-backup` version 2) with transactional validation and legacy plaintext version 1 restore compatibility.
- Accessibility controls for large-text minimum scaling and dynamic responsive layout wrapping.
- Isolated feature data access repositories for inventory, sales, credits, and expenses.

### Security & Release Hygiene
- Strictly offline main Android manifest with camera-only permission boundary.
- Fail-closed Android release signing configuration requiring private `key.properties`.
- Hardened `.gitignore` preventing accidental commitment of keys, keystores, database files, backups, and APKs.
- Application identity set to `com.flowtrack.app` with canonical metadata version `1.0.0+1`.
