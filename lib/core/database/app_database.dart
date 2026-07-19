import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/flowtrack_models.dart';
import '../utils/barcode_utils.dart';
import '../utils/contact_utils.dart';

part 'app_database.g.dart';
part 'app_database_reports.dart';

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get barcode => text()();
  TextColumn get barcodeType => text()();
  IntColumn get sellingPrice => integer()();
  IntColumn get costPrice => integer().nullable()();
  IntColumn get stock => integer()();
  IntColumn get lowStockLevel => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {barcode},
  ];
}

class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get movementType => text()();
  IntColumn get quantity => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get relatedSaleId => text().nullable().references(Sales, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get saleNumber => text()();
  DateTimeColumn get saleDate => dateTime()();
  IntColumn get totalAmount => integer()();
  TextColumn get paymentType => text()();
  IntColumn get amountReceived => integer().nullable()();
  IntColumn get changeAmount => integer().nullable()();
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get status => text()();
  TextColumn get voidReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {saleNumber},
  ];
}

class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get productNameSnapshot => text()();
  TextColumn get barcodeSnapshot => text()();
  IntColumn get unitPriceSnapshot => integer()();
  IntColumn get costPriceSnapshot => integer().nullable()();
  IntColumn get quantity => integer()();
  IntColumn get subtotal => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get contactNumber => text().nullable()();
  IntColumn get outstandingBalance =>
      integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CreditRecords extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get saleId => text().nullable().references(Sales, #id)();
  IntColumn get amount => integer()();
  IntColumn get paidAmount => integer().withDefault(const Constant(0))();
  TextColumn get status => text()();
  DateTimeColumn get creditDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CreditPayments extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  IntColumn get amount => integer()();
  DateTimeColumn get paymentDate => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  BoolColumn get isReversed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get reversedAt => dateTime().nullable()();
  TextColumn get reversalReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get category => text()();
  TextColumn get description => text().nullable()();
  IntColumn get amount => integer()();
  DateTimeColumn get expenseDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isVoided => boolean().withDefault(const Constant(false))();
  DateTimeColumn get voidedAt => dateTime().nullable()();
  TextColumn get voidReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get id => text()();
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {key},
  ];
}

class AppMetadata extends Table {
  TextColumn get id => text()();
  IntColumn get databaseVersion => integer()();
  BoolColumn get firstRunCompleted =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get ownerAccountCreated =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class AuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get action => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Products,
    StockMovements,
    Sales,
    SaleItems,
    Customers,
    CreditRecords,
    CreditPayments,
    Expenses,
    Settings,
    AppMetadata,
    AuditLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults() : super(driftDatabase(name: 'flowtrack'));

  AppDatabase.inMemory() : super(NativeDatabase.memory());

  static const _uuid = Uuid();

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2 && to >= 2) {
        await m.addColumn(products, products.isActive);
        await m.addColumn(customers, customers.isActive);
      }
      if (from < 3 && to >= 3) {
        await customStatement('DROP TABLE IF EXISTS sync_queue');
      }
      if (from < 4 && to >= 4) {
        await m.addColumn(creditPayments, creditPayments.isReversed);
        await m.addColumn(creditPayments, creditPayments.reversedAt);
        await m.addColumn(creditPayments, creditPayments.reversalReason);
      }
      if (from < 5 && to >= 5) {
        await m.addColumn(expenses, expenses.isVoided);
        await m.addColumn(expenses, expenses.voidedAt);
        await m.addColumn(expenses, expenses.voidReason);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.wasCreated) {
        final now = DateTime.now();
        await into(appMetadata).insert(
          AppMetadataCompanion.insert(
            id: 'local',
            databaseVersion: schemaVersion,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    },
  );

  String _id() => _uuid.v4();
  String generateId() => _id();

  String _saleNumber(DateTime now) {
    return 'S-${now.microsecondsSinceEpoch}';
  }

  Stream<List<Product>> watchProducts() {
    final query = select(products)
      ..where((tbl) => tbl.isActive.equals(true))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);
    return query.watch();
  }

  Future<List<Product>> getActiveProducts() {
    final query = select(products)
      ..where((tbl) => tbl.isActive.equals(true))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);
    return query.get();
  }

  Future<Product?> findProductByBarcode(String barcode) async {
    final cleanBarcode = normalizeBarcode(barcode);

    // 1. Exact match query
    final query = select(products)
      ..where((tbl) => tbl.barcode.equals(cleanBarcode));
    final exactResult = await query.getSingleOrNull();
    if (exactResult != null) {
      return exactResult;
    }

    // 2. Leading-zero fallback matching
    if (cleanBarcode.length == 13 && cleanBarcode.startsWith('0')) {
      final fallbackBarcode = cleanBarcode.substring(1);
      final fallbackQuery = select(products)
        ..where((tbl) => tbl.barcode.equals(fallbackBarcode));
      return fallbackQuery.getSingleOrNull();
    } else if (cleanBarcode.length == 12) {
      final fallbackBarcode = '0$cleanBarcode';
      final fallbackQuery = select(products)
        ..where((tbl) => tbl.barcode.equals(fallbackBarcode));
      return fallbackQuery.getSingleOrNull();
    }

    return null;
  }

  Future<Product?> getProduct(String productId) {
    final query = select(products)..where((tbl) => tbl.id.equals(productId));
    return query.getSingleOrNull();
  }

  Stream<Product?> watchProduct(String productId) {
    final query = select(products)..where((tbl) => tbl.id.equals(productId));
    return query.watchSingleOrNull();
  }

  Future<String> createProduct({
    required String name,
    required String barcode,
    required BarcodeType barcodeType,
    required int sellingPrice,
    int? costPrice,
    required int initialStock,
    required int lowStockLevel,
  }) async {
    _requireText(name, 'Product name');
    _requireText(barcode, 'Barcode');
    _requireNonNegative(sellingPrice, 'Selling price');
    if (costPrice != null) {
      _requireNonNegative(costPrice, 'Cost price');
    }
    _requireNonNegative(initialStock, 'Initial stock');
    _requireNonNegative(lowStockLevel, 'Low stock level');

    final normalizedBarcode = normalizeBarcode(barcode);
    if (barcodeType == BarcodeType.manufacturer) {
      if (isSupportedRetailBarcode(normalizedBarcode) &&
          !hasValidRetailBarcodeChecksum(normalizedBarcode)) {
        throw StateError('Invalid EAN/UPC check digit.');
      }
    }

    final existing = await findProductByBarcode(normalizedBarcode);
    if (existing != null) {
      throw StateError('This product already exists. Add stock instead.');
    }

    final productId = _id();
    final now = DateTime.now();
    await transaction(() async {
      await into(products).insert(
        ProductsCompanion.insert(
          id: productId,
          name: name.trim(),
          barcode: normalizedBarcode,
          barcodeType: barcodeType.dbValue,
          sellingPrice: sellingPrice,
          costPrice: Value(costPrice),
          stock: initialStock,
          lowStockLevel: lowStockLevel,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (initialStock > 0) {
        await _insertStockMovement(
          productId: productId,
          movementType: StockMovementType.initialStock,
          quantity: initialStock,
          notes: 'Initial stock',
          createdAt: now,
        );
      }
    });
    return productId;
  }

  Future<void> editProduct({
    required String productId,
    required int sellingPrice,
    int? costPrice,
    required int lowStockLevel,
  }) async {
    _requireNonNegative(sellingPrice, 'Selling price');
    if (costPrice != null) {
      _requireNonNegative(costPrice, 'Cost price');
    }
    _requireNonNegative(lowStockLevel, 'Low stock level');

    await (update(products)..where((tbl) => tbl.id.equals(productId))).write(
      ProductsCompanion(
        sellingPrice: Value(sellingPrice),
        costPrice: Value(costPrice),
        lowStockLevel: Value(lowStockLevel),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateProductActive({
    required String productId,
    required bool isActive,
  }) async {
    await (update(products)..where((tbl) => tbl.id.equals(productId))).write(
      ProductsCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> addStock({
    required String productId,
    required int quantity,
    String? notes,
  }) async {
    _requirePositive(quantity, 'Quantity');
    await _changeStock(
      productId: productId,
      quantityDelta: quantity,
      movementType: StockMovementType.restock,
      notes: notes,
    );
  }

  Future<void> adjustStock({
    required String productId,
    required int quantity,
    required bool add,
    required String reason,
    String? notes,
  }) async {
    _requirePositive(quantity, 'Quantity');
    _requireText(reason, 'Reason');
    await _changeStock(
      productId: productId,
      quantityDelta: add ? quantity : -quantity,
      movementType: add
          ? StockMovementType.adjustmentAdd
          : StockMovementType.adjustmentDeduct,
      reason: reason,
      notes: notes,
    );
  }

  Future<void> _changeStock({
    required String productId,
    required int quantityDelta,
    required StockMovementType movementType,
    String? reason,
    String? notes,
  }) async {
    final now = DateTime.now();
    await transaction(() async {
      final product = await getProduct(productId);
      if (product == null) {
        throw StateError('Product not found.');
      }
      final nextStock = product.stock + quantityDelta;
      if (nextStock < 0) {
        throw StateError('Stock cannot become negative.');
      }
      await (update(products)..where((tbl) => tbl.id.equals(productId))).write(
        ProductsCompanion(stock: Value(nextStock), updatedAt: Value(now)),
      );
      await _insertStockMovement(
        productId: productId,
        movementType: movementType,
        quantity: quantityDelta.abs(),
        reason: reason,
        notes: notes,
        createdAt: now,
      );
    });
  }

  Stream<List<StockMovement>> watchStockMovements(String productId) {
    final query = select(stockMovements)
      ..where((tbl) => tbl.productId.equals(productId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);
    return query.watch();
  }

  Stream<List<Sale>> watchSales() {
    final query = select(sales)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.saleDate)]);
    return query.watch();
  }

  Future<Sale?> getSale(String saleId) {
    final query = select(sales)..where((tbl) => tbl.id.equals(saleId));
    return query.getSingleOrNull();
  }

  Future<List<SaleItem>> getSaleItems(String saleId) {
    final query = select(saleItems)..where((tbl) => tbl.saleId.equals(saleId));
    return query.get();
  }

  Future<String> completeSale({
    required List<SaleRequestLine> lines,
    required PaymentType paymentType,
    required DateTime saleDate,
    int? amountReceived,
    String? customerId,
    String? customerName,
    String? contactNumber,
  }) async {
    if (lines.isEmpty) {
      throw StateError('Cannot complete an empty sale.');
    }

    final quantitiesByProductId = <String, int>{};
    for (final line in lines) {
      if (line.productId.trim().isEmpty) {
        throw StateError('Product ID cannot be blank.');
      }
      if (line.quantity <= 0) {
        throw StateError('Quantity must be greater than zero.');
      }
      quantitiesByProductId.update(
        line.productId,
        (current) => current + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }

    final now = DateTime.now();
    final saleId = _id();

    await transaction(() async {
      int total = 0;

      final uniqueProductIds = quantitiesByProductId.keys.toList();
      final productsList = await (select(
        products,
      )..where((tbl) => tbl.id.isIn(uniqueProductIds))).get();

      final productMap = {for (final p in productsList) p.id: p};

      for (final productId in uniqueProductIds) {
        final product = productMap[productId];
        if (product == null) {
          throw StateError('Product is not available.');
        }
        if (!product.isActive) {
          throw StateError('${product.name} is not available.');
        }
        final requiredQty = quantitiesByProductId[productId]!;
        if (product.stock < requiredQty) {
          throw StateError('Not enough stock available for ${product.name}.');
        }
        total += product.sellingPrice * requiredQty;
      }

      if (paymentType == PaymentType.cash) {
        if (amountReceived == null) {
          throw StateError('Cash sale requires amount received.');
        }
        if (amountReceived < total) {
          throw StateError('Amount received is below the current sale total.');
        }
      }

      String? finalCustomerId = customerId;
      if (paymentType == PaymentType.credit) {
        if (finalCustomerId == null) {
          _requireText(customerName, 'Customer name');
          finalCustomerId = await _createCustomerInTransaction(
            name: customerName!,
            contactNumber: contactNumber,
            now: now,
          );
        } else {
          final customer = await getCustomer(finalCustomerId);
          if (customer == null || !customer.isActive) {
            throw StateError('Customer not found.');
          }
        }
      }

      await into(sales).insert(
        SalesCompanion.insert(
          id: saleId,
          saleNumber: _saleNumber(now),
          saleDate: saleDate,
          totalAmount: total,
          paymentType: paymentType.dbValue,
          amountReceived: Value(amountReceived),
          changeAmount: Value(
            paymentType == PaymentType.cash
                ? calculateCashChange(
                    amountReceived: amountReceived!,
                    total: total,
                  )
                : null,
          ),
          customerId: Value(finalCustomerId),
          status: SaleStatus.completed.dbValue,
          createdAt: now,
          updatedAt: now,
        ),
      );

      for (final productId in uniqueProductIds) {
        final product = productMap[productId]!;
        final quantity = quantitiesByProductId[productId]!;
        final subtotal = product.sellingPrice * quantity;

        await into(saleItems).insert(
          SaleItemsCompanion.insert(
            id: _id(),
            saleId: saleId,
            productId: productId,
            productNameSnapshot: product.name,
            barcodeSnapshot: product.barcode,
            unitPriceSnapshot: product.sellingPrice,
            costPriceSnapshot: Value(product.costPrice),
            quantity: quantity,
            subtotal: subtotal,
          ),
        );

        await (update(
          products,
        )..where((tbl) => tbl.id.equals(productId))).write(
          ProductsCompanion(
            stock: Value(product.stock - quantity),
            updatedAt: Value(now),
          ),
        );

        await _insertStockMovement(
          productId: productId,
          movementType: StockMovementType.saleDeduction,
          quantity: quantity,
          relatedSaleId: saleId,
          createdAt: now,
        );
      }

      if (paymentType == PaymentType.credit && finalCustomerId != null) {
        await into(creditRecords).insert(
          CreditRecordsCompanion.insert(
            id: _id(),
            customerId: finalCustomerId,
            saleId: Value(saleId),
            amount: total,
            status: CreditStatus.unpaid.dbValue,
            creditDate: saleDate,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await _increaseCustomerBalance(finalCustomerId, total, now);
      }
    });

    return saleId;
  }

  Future<void> voidSale(String saleId, {String? reason}) async {
    final now = DateTime.now();
    await transaction(() async {
      final sale = await getSale(saleId);
      if (sale == null) {
        throw StateError('Sale not found.');
      }
      if (sale.status == SaleStatus.voided.dbValue) {
        throw StateError('Sale is already voided.');
      }
      if (sale.paymentType == PaymentType.credit.dbValue) {
        final recordQuery = select(creditRecords)
          ..where((tbl) => tbl.saleId.equals(saleId));
        final record = await recordQuery.getSingleOrNull();
        if (record != null && record.paidAmount > 0) {
          throw StateError(
            'Cannot void a credit sale that already has partial payments. Reverse payments first.',
          );
        }
      }
      final items = await getSaleItems(saleId);
      for (final item in items) {
        final product = await getProduct(item.productId);
        if (product == null) {
          continue;
        }
        await (update(
          products,
        )..where((tbl) => tbl.id.equals(item.productId))).write(
          ProductsCompanion(
            stock: Value(product.stock + item.quantity),
            updatedAt: Value(now),
          ),
        );
        await _insertStockMovement(
          productId: item.productId,
          movementType: StockMovementType.voidRestore,
          quantity: item.quantity,
          relatedSaleId: saleId,
          reason: reason,
          createdAt: now,
        );
      }
      await (update(sales)..where((tbl) => tbl.id.equals(saleId))).write(
        SalesCompanion(
          status: Value(SaleStatus.voided.dbValue),
          voidReason: Value(reason),
          updatedAt: Value(now),
        ),
      );
      if (sale.paymentType == PaymentType.credit.dbValue &&
          sale.customerId != null) {
        final recordQuery = select(creditRecords)
          ..where((tbl) => tbl.saleId.equals(saleId));
        final record = await recordQuery.getSingleOrNull();
        if (record != null && record.status != CreditStatus.voided.dbValue) {
          await (update(
            creditRecords,
          )..where((tbl) => tbl.id.equals(record.id))).write(
            CreditRecordsCompanion(
              status: Value(CreditStatus.voided.dbValue),
              updatedAt: Value(now),
            ),
          );
          await _rebuildCustomerCreditState(sale.customerId!, now);
        }
      }
      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          id: _id(),
          action: 'void_sale',
          entityType: 'sale',
          entityId: saleId,
          notes: Value(reason),
          createdAt: now,
        ),
      );
    });
  }

  Stream<List<Customer>> watchCustomers() {
    final query = select(customers)
      ..where((tbl) => tbl.isActive.equals(true))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);
    return query.watch();
  }

  Future<List<Customer>> getActiveCustomers() {
    final query = select(customers)
      ..where((tbl) => tbl.isActive.equals(true))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);
    return query.get();
  }

  Future<Customer?> getCustomer(String customerId) {
    final query = select(customers)..where((tbl) => tbl.id.equals(customerId));
    return query.getSingleOrNull();
  }

  Stream<Customer?> watchCustomer(String customerId) {
    final query = select(customers)..where((tbl) => tbl.id.equals(customerId));
    return query.watchSingleOrNull();
  }

  Future<void> updateCustomer({
    required String customerId,
    required String name,
    String? contactNumber,
  }) async {
    _requireText(name, 'Customer name');
    final normalizedContact = normalizeContactNumber(contactNumber);
    return transaction(() async {
      await _ensureContactAvailable(
        normalizedContact,
        excludingCustomerId: customerId,
      );
      await (update(
        customers,
      )..where((tbl) => tbl.id.equals(customerId))).write(
        CustomersCompanion(
          name: Value(name.trim()),
          contactNumber: Value(normalizedContact),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> deleteCustomer(String customerId) async {
    final customer = await getCustomer(customerId);
    if (customer == null) {
      throw StateError('Customer not found.');
    }
    if (customer.outstandingBalance > 0) {
      throw StateError('Cannot delete customer with outstanding balance.');
    }
    final records = await (select(
      creditRecords,
    )..where((tbl) => tbl.customerId.equals(customerId))).get();
    if (records.isNotEmpty) {
      throw StateError(
        'Cannot delete customer with active transaction history.',
      );
    }
    await (delete(customers)..where((tbl) => tbl.id.equals(customerId))).go();
  }

  Future<String> createCustomer({
    required String name,
    String? contactNumber,
  }) async {
    _requireText(name, 'Customer name');
    final normalizedContact = normalizeContactNumber(contactNumber);
    return transaction(() async {
      await _ensureContactAvailable(normalizedContact);
      final id = _id();
      final now = DateTime.now();
      await into(customers).insert(
        CustomersCompanion.insert(
          id: id,
          name: name.trim(),
          contactNumber: Value(normalizedContact),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return id;
    });
  }

  Future<void> _ensureContactAvailable(
    String? normalizedContact, {
    String? excludingCustomerId,
    String? customErrorMessage,
  }) async {
    if (normalizedContact == null) return;

    final existing = await getActiveCustomers();

    for (final customer in existing) {
      if (customer.id == excludingCustomerId) continue;

      if (customer.contactNumber != null &&
          normalizeContactNumber(customer.contactNumber) == normalizedContact) {
        throw StateError(
          customErrorMessage ??
              'A customer with this contact number already exists.',
        );
      }
    }
  }

  Future<String> _createCustomerInTransaction({
    required String name,
    String? contactNumber,
    required DateTime now,
  }) async {
    final normalizedContact = normalizeContactNumber(contactNumber);
    await _ensureContactAvailable(
      normalizedContact,
      customErrorMessage:
          'A customer with this contact number already exists. Please select the existing customer instead of creating a new one.',
    );

    final id = _id();
    await into(customers).insert(
      CustomersCompanion.insert(
        id: id,
        name: name.trim(),
        contactNumber: Value(normalizedContact),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Stream<List<CreditRecord>> watchCreditRecords(String customerId) {
    final query = select(creditRecords)
      ..where((tbl) => tbl.customerId.equals(customerId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.creditDate)]);
    return query.watch();
  }

  Stream<List<CreditPayment>> watchCreditPayments(String customerId) {
    final query = select(creditPayments)
      ..where((tbl) => tbl.customerId.equals(customerId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.paymentDate)]);
    return query.watch();
  }

  Future<void> _rebuildCustomerCreditState(
    String customerId,
    DateTime now,
  ) async {
    final recordsQuery = select(creditRecords)
      ..where(
        (tbl) =>
            tbl.customerId.equals(customerId) &
            tbl.status.isNotValue(CreditStatus.voided.dbValue),
      )
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.creditDate),
        (tbl) => OrderingTerm.asc(tbl.createdAt),
        (tbl) => OrderingTerm.asc(tbl.id),
      ]);
    final records = await recordsQuery.get();

    final paymentsQuery = select(creditPayments)
      ..where(
        (tbl) =>
            tbl.customerId.equals(customerId) & tbl.isReversed.equals(false),
      )
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.paymentDate),
        (tbl) => OrderingTerm.asc(tbl.createdAt),
        (tbl) => OrderingTerm.asc(tbl.id),
      ]);
    final payments = await paymentsQuery.get();

    var remainingPayment = payments.fold<int>(0, (sum, p) => sum + p.amount);
    var newOutstandingBalance = 0;

    for (final record in records) {
      final totalAmount = record.amount;
      int nextPaid = 0;
      CreditStatus nextStatus;

      if (remainingPayment >= totalAmount) {
        nextPaid = totalAmount;
        nextStatus = CreditStatus.paid;
        remainingPayment -= totalAmount;
      } else if (remainingPayment > 0) {
        nextPaid = remainingPayment;
        nextStatus = CreditStatus.partiallyPaid;
        remainingPayment = 0;
      } else {
        nextPaid = 0;
        nextStatus = CreditStatus.unpaid;
      }

      newOutstandingBalance += (totalAmount - nextPaid);

      await (update(
        creditRecords,
      )..where((tbl) => tbl.id.equals(record.id))).write(
        CreditRecordsCompanion(
          paidAmount: Value(nextPaid),
          status: Value(nextStatus.dbValue),
          updatedAt: Value(now),
        ),
      );
    }

    final finalBalance = max(0, newOutstandingBalance - remainingPayment);

    await (update(customers)..where((tbl) => tbl.id.equals(customerId))).write(
      CustomersCompanion(
        outstandingBalance: Value(finalBalance),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> recordCreditPayment({
    required String customerId,
    required int amount,
    required DateTime paymentDate,
    String? notes,
  }) async {
    _requirePositive(amount, 'Payment amount');
    final now = DateTime.now();
    await transaction(() async {
      final customer = await getCustomer(customerId);
      if (customer == null) {
        throw StateError('Customer not found.');
      }
      if (amount > customer.outstandingBalance) {
        throw StateError('Payment exceeds outstanding balance.');
      }

      await into(creditPayments).insert(
        CreditPaymentsCompanion.insert(
          id: _id(),
          customerId: customerId,
          amount: amount,
          paymentDate: paymentDate,
          notes: Value(notes),
          createdAt: now,
          isReversed: const Value(false),
        ),
      );

      await _rebuildCustomerCreditState(customerId, now);
    });
  }

  Future<void> reverseCreditPayment({
    required String paymentId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Reversal reason is required.');
    }
    final now = DateTime.now();
    await transaction(() async {
      final paymentQuery = select(creditPayments)
        ..where((tbl) => tbl.id.equals(paymentId));
      final payment = await paymentQuery.getSingleOrNull();
      if (payment == null) {
        throw StateError('Payment not found.');
      }
      if (payment.isReversed) {
        throw StateError('Payment is already reversed.');
      }

      await (update(
        creditPayments,
      )..where((tbl) => tbl.id.equals(paymentId))).write(
        CreditPaymentsCompanion(
          isReversed: const Value(true),
          reversedAt: Value(now),
          reversalReason: Value(reason.trim()),
        ),
      );

      await _rebuildCustomerCreditState(payment.customerId, now);

      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          id: _id(),
          action: 'reverse_credit_payment',
          entityType: 'credit_payment',
          entityId: paymentId,
          notes: Value(reason.trim()),
          createdAt: now,
        ),
      );
    });
  }

  Stream<List<Expense>> watchExpenses() {
    final query = select(expenses)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.expenseDate)]);
    return query.watch();
  }

  Future<void> createExpense({
    required String category,
    String? description,
    required int amount,
    required DateTime expenseDate,
  }) async {
    _requireText(category, 'Category');
    _requirePositive(amount, 'Expense amount');
    final now = DateTime.now();
    await into(expenses).insert(
      ExpensesCompanion.insert(
        id: _id(),
        category: category,
        description: Value(description),
        amount: amount,
        expenseDate: expenseDate,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<Expense?> getExpense(String expenseId) {
    final query = select(expenses)..where((tbl) => tbl.id.equals(expenseId));
    return query.getSingleOrNull();
  }

  Future<void> updateExpense({
    required String expenseId,
    required String category,
    String? description,
    required int amount,
    required DateTime expenseDate,
  }) async {
    _requireText(category, 'Category');
    _requirePositive(amount, 'Expense amount');
    final now = DateTime.now();
    await transaction(() async {
      final expense = await getExpense(expenseId);
      if (expense == null) {
        throw StateError('Expense not found.');
      }
      if (expense.isVoided) {
        throw StateError('Voided expenses cannot be edited.');
      }
      await (update(expenses)..where((tbl) => tbl.id.equals(expenseId))).write(
        ExpensesCompanion(
          category: Value(category),
          description: Value(description),
          amount: Value(amount),
          expenseDate: Value(expenseDate),
          updatedAt: Value(now),
        ),
      );
      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          id: _id(),
          action: 'update_expense',
          entityType: 'expense',
          entityId: expenseId,
          notes: const Value('Updated expense details.'),
          createdAt: now,
        ),
      );
    });
  }

  Future<void> voidExpense({
    required String expenseId,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    _requireText(trimmedReason, 'Void reason');
    final now = DateTime.now();
    await transaction(() async {
      final expense = await getExpense(expenseId);
      if (expense == null) {
        throw StateError('Expense not found.');
      }
      if (expense.isVoided) {
        throw StateError('Expense is already voided.');
      }
      await (update(expenses)..where((tbl) => tbl.id.equals(expenseId))).write(
        ExpensesCompanion(
          isVoided: const Value(true),
          voidedAt: Value(now),
          voidReason: Value(trimmedReason),
          updatedAt: Value(now),
        ),
      );
      await into(auditLogs).insert(
        AuditLogsCompanion.insert(
          id: _id(),
          action: 'void_expense',
          entityType: 'expense',
          entityId: expenseId,
          notes: Value(trimmedReason),
          createdAt: now,
        ),
      );
    });
  }

  Future<void> setSetting(String key, String value) async {
    final now = DateTime.now();
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(id: key, key: key, value: value, updatedAt: now),
    );
  }

  Future<void> updateStoreName(String name) async {
    await setSetting('store_name', name.trim());
  }

  Future<String?> getSetting(String key) async {
    final query = select(settings)..where((tbl) => tbl.key.equals(key));
    return (await query.getSingleOrNull())?.value;
  }

  Future<void> clearBusinessDataForDemo() async {
    await transaction(() async {
      await delete(auditLogs).go();
      await delete(creditPayments).go();
      await delete(creditRecords).go();
      await delete(saleItems).go();
      await delete(stockMovements).go();
      await delete(sales).go();
      await delete(expenses).go();
      await delete(products).go();
      await delete(customers).go();
      await (delete(
        settings,
      )..where((tbl) => tbl.key.equals('qa_sample_data_loaded'))).go();
    });
  }

  Future<void> _increaseCustomerBalance(
    String customerId,
    int amount,
    DateTime now,
  ) async {
    final customer = await getCustomer(customerId);
    if (customer == null) {
      throw StateError('Customer not found.');
    }
    final next = max(0, customer.outstandingBalance + amount);
    await (update(customers)..where((tbl) => tbl.id.equals(customerId))).write(
      CustomersCompanion(
        outstandingBalance: Value(next),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> _insertStockMovement({
    required String productId,
    required StockMovementType movementType,
    required int quantity,
    String? reason,
    String? relatedSaleId,
    String? notes,
    required DateTime createdAt,
  }) {
    return into(stockMovements).insert(
      StockMovementsCompanion.insert(
        id: _id(),
        productId: productId,
        movementType: movementType.dbValue,
        quantity: quantity,
        reason: Value(reason),
        relatedSaleId: Value(relatedSaleId),
        notes: Value(notes),
        createdAt: createdAt,
      ),
    );
  }

  void _requireText(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      throw StateError('$label is required.');
    }
  }

  void _requirePositive(int value, String label) {
    if (value <= 0) {
      throw StateError('$label must be greater than 0.');
    }
  }

  void _requireNonNegative(int value, String label) {
    if (value < 0) {
      throw StateError('$label cannot be negative.');
    }
  }
}
