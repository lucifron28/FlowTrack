// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/core/services/backup_crypto_service.dart';
import 'package:flowtrack/core/services/backup_service.dart';
import 'package:flowtrack/core/services/backup_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;

  setUp(() {
    database = AppDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  test('new credit sale stores customerNameSnapshot for existing and new checkout customers, null for cash', () async {
    final p1 = await database.createProduct(
      name: 'Noodles',
      barcode: 'P-101',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 1500,
      initialStock: 20,
      lowStockLevel: 5,
    );
    final c1 = await database.createCustomer(
      name: 'Existing Customer',
      contactNumber: '09171112233',
    );

    // 1. Credit sale with existing customer
    final saleId1 = await database.completeSale(
      lines: [SaleRequestLine(productId: p1, quantity: 1)],
      paymentType: PaymentType.credit,
      saleDate: DateTime.now(),
      customerId: c1,
    );

    // 2. Credit sale with new customer created at checkout
    final saleId2 = await database.completeSale(
      lines: [SaleRequestLine(productId: p1, quantity: 1)],
      paymentType: PaymentType.credit,
      saleDate: DateTime.now(),
      customerName: 'Checkout Customer',
    );

    // 3. Cash sale
    final saleId3 = await database.completeSale(
      lines: [SaleRequestLine(productId: p1, quantity: 1)],
      paymentType: PaymentType.cash,
      saleDate: DateTime.now(),
      amountReceived: 2000,
    );

    final sale1 = await database.getSale(saleId1);
    final sale2 = await database.getSale(saleId2);
    final sale3 = await database.getSale(saleId3);

    expect(sale1!.customerId, c1);
    expect(sale1.customerNameSnapshot, 'Existing Customer');

    expect(sale2!.customerId, isNotNull);
    expect(sale2.customerNameSnapshot, 'Checkout Customer');

    expect(sale3!.customerId, isNull);
    expect(sale3.customerNameSnapshot, isNull);
  });

  test('renaming a customer does not alter historical snapshot on completed sale', () async {
    final p1 = await database.createProduct(
      name: 'Bread',
      barcode: 'P-102',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 500,
      initialStock: 10,
      lowStockLevel: 2,
    );
    final c1 = await database.createCustomer(name: 'Original Name');

    final saleId = await database.completeSale(
      lines: [SaleRequestLine(productId: p1, quantity: 1)],
      paymentType: PaymentType.credit,
      saleDate: DateTime.now(),
      customerId: c1,
    );

    await database.updateCustomer(
      customerId: c1,
      name: 'Renamed Customer',
    );

    final sale = await database.getSale(saleId);
    expect(sale!.customerNameSnapshot, 'Original Name');

    final entry = await database.getSaleWithCustomer(saleId);
    expect(entry!.customerName, 'Original Name');
  });

  test('versioned v5 database automatically migrates to v6, backfilling credit sales and handling legacy cash customer IDs', () async {
    final tempDir = await Directory.systemTemp.createTemp('flowtrack_v5_test');
    final dbPath = p.join(tempDir.path, 'v5_legacy.db');

    final sqliteDb = sqlite3.open(dbPath);
    sqliteDb.execute('PRAGMA foreign_keys = ON;');
    sqliteDb.execute('''
      CREATE TABLE customers (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        contact_number TEXT,
        outstanding_balance INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE sales (
        id TEXT NOT NULL PRIMARY KEY,
        sale_number TEXT NOT NULL UNIQUE,
        sale_date INTEGER NOT NULL,
        total_amount INTEGER NOT NULL,
        payment_type TEXT NOT NULL,
        amount_received INTEGER,
        change_amount INTEGER,
        customer_id TEXT REFERENCES customers(id),
        status TEXT NOT NULL,
        void_reason TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE products (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        barcode TEXT NOT NULL,
        barcode_type TEXT NOT NULL,
        selling_price INTEGER NOT NULL,
        cost_price INTEGER,
        stock INTEGER NOT NULL,
        low_stock_level INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE sale_items (
        id TEXT NOT NULL PRIMARY KEY,
        sale_id TEXT NOT NULL REFERENCES sales(id),
        product_id TEXT NOT NULL REFERENCES products(id),
        product_name_snapshot TEXT NOT NULL,
        barcode_snapshot TEXT NOT NULL,
        unit_price_snapshot INTEGER NOT NULL,
        cost_price_snapshot INTEGER,
        quantity INTEGER NOT NULL,
        subtotal INTEGER NOT NULL
      );
      CREATE TABLE credit_records (
        id TEXT NOT NULL PRIMARY KEY,
        customer_id TEXT NOT NULL REFERENCES customers(id),
        sale_id TEXT REFERENCES sales(id),
        amount INTEGER NOT NULL,
        paid_amount INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        credit_date INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE credit_payments (
        id TEXT NOT NULL PRIMARY KEY,
        customer_id TEXT NOT NULL REFERENCES customers(id),
        amount INTEGER NOT NULL,
        payment_date INTEGER NOT NULL,
        notes TEXT,
        created_at INTEGER NOT NULL,
        is_reversed INTEGER NOT NULL DEFAULT 0,
        reversed_at INTEGER,
        reversal_reason TEXT
      );
      CREATE TABLE expenses (
        id TEXT NOT NULL PRIMARY KEY,
        category TEXT NOT NULL,
        description TEXT,
        amount INTEGER NOT NULL,
        expense_date INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_voided INTEGER NOT NULL DEFAULT 0,
        voided_at INTEGER,
        void_reason TEXT
      );
      CREATE TABLE settings (
        id TEXT NOT NULL PRIMARY KEY,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE app_metadata (
        id TEXT NOT NULL PRIMARY KEY,
        database_version INTEGER NOT NULL,
        first_run_completed INTEGER NOT NULL DEFAULT 0,
        owner_account_created INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE stock_movements (
        id TEXT NOT NULL PRIMARY KEY,
        product_id TEXT NOT NULL REFERENCES products(id),
        movement_type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        related_sale_id TEXT REFERENCES sales(id),
        reason TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE audit_logs (
        id TEXT NOT NULL PRIMARY KEY,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        notes TEXT,
        created_at INTEGER NOT NULL
      );
      PRAGMA user_version = 5;
    ''');

    sqliteDb.execute('''
      INSERT INTO products (id, name, barcode, barcode_type, selling_price, cost_price, stock, low_stock_level, is_active, created_at, updated_at)
      VALUES ('p1', 'Noodles', 'P-101', 'manufacturer', 1500, 1200, 50, 10, 1, 1750000000, 1750000000);

      INSERT INTO customers (id, name, contact_number, outstanding_balance, is_active, created_at, updated_at)
      VALUES ('c1', 'Legacy Credit Customer', '09170001111', 1500, 1, 1750000000, 1750000000);

      INSERT INTO sales (id, sale_number, sale_date, total_amount, payment_type, amount_received, change_amount, customer_id, status, void_reason, created_at, updated_at)
      VALUES ('s_credit', 'SAL-V5-101', 1750000000, 1500, 'credit', NULL, NULL, 'c1', 'completed', NULL, 1750000000, 1750000000);

      INSERT INTO sale_items (id, sale_id, product_id, product_name_snapshot, barcode_snapshot, unit_price_snapshot, cost_price_snapshot, quantity, subtotal)
      VALUES ('item_1', 's_credit', 'p1', 'Noodles', 'P-101', 1500, 1200, 1, 1500);

      INSERT INTO sales (id, sale_number, sale_date, total_amount, payment_type, amount_received, change_amount, customer_id, status, void_reason, created_at, updated_at)
      VALUES ('s_cash_normal', 'SAL-V5-102', 1750000000, 800, 'cash', 1000, 200, NULL, 'completed', NULL, 1750000000, 1750000000);

      INSERT INTO sale_items (id, sale_id, product_id, product_name_snapshot, barcode_snapshot, unit_price_snapshot, cost_price_snapshot, quantity, subtotal)
      VALUES ('item_2', 's_cash_normal', 'p1', 'Noodles', 'P-101', 800, 600, 1, 800);

      INSERT INTO sales (id, sale_number, sale_date, total_amount, payment_type, amount_received, change_amount, customer_id, status, void_reason, created_at, updated_at)
      VALUES ('s_cash_stale', 'SAL-V5-103', 1750000000, 500, 'cash', 500, 0, 'c1', 'completed', NULL, 1750000000, 1750000000);

      INSERT INTO sale_items (id, sale_id, product_id, product_name_snapshot, barcode_snapshot, unit_price_snapshot, cost_price_snapshot, quantity, subtotal)
      VALUES ('item_3', 's_cash_stale', 'p1', 'Noodles', 'P-101', 500, 400, 1, 500);

      INSERT INTO credit_records (id, customer_id, sale_id, amount, paid_amount, status, credit_date, created_at, updated_at)
      VALUES ('cr_1', 'c1', 's_credit', 1500, 0, 'unpaid', 1750000000, 1750000000, 1750000000);
    ''');

    sqliteDb.close();

    final migratedDb = AppDatabase(NativeDatabase(File(dbPath)));
    final creditSale = await migratedDb.getSale('s_credit');
    final normalCashSale = await migratedDb.getSale('s_cash_normal');
    final staleCashSale = await migratedDb.getSale('s_cash_stale');

    expect(migratedDb.schemaVersion, 6);
    expect(creditSale!.customerNameSnapshot, 'Legacy Credit Customer');
    expect(normalCashSale!.customerNameSnapshot, isNull);
    expect(staleCashSale!.customerNameSnapshot, isNull);

    final backupService = BackupService(
      migratedDb,
      const BackupCryptoService(),
      const BackupValidator(),
    );

    final backupJson = await backupService.createBackupJson('TestPass123!');
    final validated = await backupService.validateBackupString(backupJson, passphrase: 'TestPass123!');
    expect(validated.salesCount, 3);

    await migratedDb.close();
    await tempDir.delete(recursive: true);
  });
}
