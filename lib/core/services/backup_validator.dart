import '../../core/config/app_config.dart';
import '../../core/utils/barcode_utils.dart';
import '../../core/utils/contact_utils.dart';

class BackupValidator {
  const BackupValidator();

  void validateBackup(Map<String, dynamic> decoded, int expectedBackupVersion) {
    if (!decoded.containsKey('metadata') || !decoded.containsKey('data')) {
      throw Exception('Missing metadata or data blocks.');
    }

    final metadata = decoded['metadata'];
    if (metadata is! Map<String, dynamic>) {
      throw Exception('Invalid metadata block.');
    }

    if (metadata['appName'] != AppConfig.appName) {
      throw Exception('Backup file is not for FlowTrack.');
    }

    final version = metadata['backupVersion'];
    // We only support restoring version 1 (legacy plaintext) or version 2 (encrypted).
    if (version != 1 && version != 2) {
      throw Exception('Backup version \$version is not supported.');
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid data block.');
    }

    final requiredTables = [
      'appMetadata',
      'settings',
      'products',
      'customers',
      'sales',
      'saleItems',
      'creditRecords',
      'creditPayments',
      'expenses',
      'stockMovements',
      'auditLogs',
    ];

    for (final table in requiredTables) {
      if (!data.containsKey(table)) {
        throw Exception('Missing required table: \$table.');
      }
      if (data[table] is! List) {
        throw Exception('Table \$table must be a list.');
      }
      for (final row in (data[table] as List)) {
        if (row is! Map<String, dynamic>) {
          throw Exception('Rows in \$table must be objects.');
        }
      }
    }

    final products = (data['products'] as List).cast<Map<String, dynamic>>();
    final stockMovements = (data['stockMovements'] as List).cast<Map<String, dynamic>>();
    final customers = (data['customers'] as List).cast<Map<String, dynamic>>();
    final sales = (data['sales'] as List).cast<Map<String, dynamic>>();
    final saleItems = (data['saleItems'] as List).cast<Map<String, dynamic>>();
    final creditRecords =
        (data['creditRecords'] as List).cast<Map<String, dynamic>>();
    final creditPayments =
        (data['creditPayments'] as List).cast<Map<String, dynamic>>();
    final expenses = (data['expenses'] as List).cast<Map<String, dynamic>>();
    final settings = (data['settings'] as List).cast<Map<String, dynamic>>();

    final allIds = <String>{};
    void checkId(String id, String table) {
      if (allIds.contains(id)) {
        throw Exception('Duplicate primary ID \$id found in \$table.');
      }
      allIds.add(id);
    }

    // Settings keys
    final settingKeys = <String>{};
    for (final s in settings) {
      final key = s['key'] as String;
      if (settingKeys.contains(key)) {
        throw Exception('Duplicate setting key \$key.');
      }
      settingKeys.add(key);
    }

    // Products
    final productIds = <String>{};
    final productBarcodes = <String>{};
    for (final p in products) {
      final id = p['id'] as String;
      checkId(id, 'products');
      productIds.add(id);

      final barcode = p['barcode'] as String?;
      if (barcode != null && barcode.isNotEmpty) {
        final normalized = normalizeBarcode(barcode);
        if (normalized.isNotEmpty) {
          if (productBarcodes.contains(normalized)) {
            throw Exception('Duplicate normalized product barcode \$normalized.');
          }
          productBarcodes.add(normalized);
        }
      }

      final price = (p['sellingPrice'] as num).toInt();
      final cost = p['costPrice'] != null ? (p['costPrice'] as num).toInt() : 0;
      final stock = (p['stock'] as num).toInt();
      if (price < 0 || cost < 0 || stock < 0) {
        throw Exception('Negative price, cost, or stock for product \$id.');
      }
    }

    // Customers
    final customerIds = <String>{};
    final customerContacts = <String>{};
    for (final c in customers) {
      final id = c['id'] as String;
      checkId(id, 'customers');
      customerIds.add(id);

      final contact = c['contactNumber'] as String?;
      final normalized = normalizeContactNumber(contact);
      if (normalized != null) {
        if (customerContacts.contains(normalized)) {
          throw Exception('Duplicate normalized customer contact \$normalized.');
        }
        customerContacts.add(normalized);
      }

      final balance = (c['outstandingBalance'] as num).toInt();
      if (balance < 0) {
        throw Exception('Negative outstanding balance for customer \$id.');
      }
    }

    // Sales
    final saleIds = <String>{};
    final saleNumbers = <String>{};
    for (final s in sales) {
      final id = s['id'] as String;
      checkId(id, 'sales');
      saleIds.add(id);

      final customerId = s['customerId'] as String?;
      if (customerId != null && !customerIds.contains(customerId)) {
        throw Exception('Sale \$id references missing customer \$customerId.');
      }

      final numStr = s['saleNumber'] as String;
      if (saleNumbers.contains(numStr)) {
        throw Exception('Duplicate sale number \$numStr.');
      }
      saleNumbers.add(numStr);

      final total = (s['totalAmount'] as num).toInt();
      final paid = s['amountReceived'] != null ? (s['amountReceived'] as num).toInt() : 0;
      if (total < 0 || paid < 0) {
        throw Exception('Negative total or paid amount for sale \$id.');
      }
      if (s['paymentType'] == 'credit' && paid > total) {
        throw Exception('Paid amount exceeds total for sale \$id.');
      }
    }

    // Sale Items
    final itemTotals = <String, int>{};
    for (final item in saleItems) {
      if (item['id'] == null) throw Exception('item id is null: \$item');
      if (item['saleId'] == null) throw Exception('item saleId is null: \$item');
      if (item['productId'] == null) throw Exception('item productId is null: \$item');

      final id = item['id'] as String;
      checkId(id, 'saleItems');

      final saleId = item['saleId'] as String;
      if (!saleIds.contains(saleId)) {
        throw Exception('Sale item \$id references missing sale \$saleId.');
      }

      final productId = item['productId'] as String;
      if (!productIds.contains(productId)) {
        throw Exception(
            'Sale item \$id references missing product \$productId.');
      }

      final qty = (item['quantity'] as num).toInt();
      final subtotal = (item['subtotal'] as num).toInt();
      if (qty <= 0) {
        throw Exception('Non-positive quantity for sale item \$id.');
      }
      if (subtotal < 0) {
        throw Exception('Negative subtotal for sale item \$id.');
      }

      itemTotals[saleId] = (itemTotals[saleId] ?? 0) + subtotal;
    }

    // Check sale header totals
    for (final s in sales) {
      final id = s['id'] as String;
      final headerTotal = (s['totalAmount'] as num).toInt();
      final calculatedTotal = itemTotals[id] ?? 0;
      if (headerTotal != calculatedTotal) {
        throw Exception('Sale \$id total does not match sum of items.');
      }
    }

    // Stock Movements
    for (final sm in stockMovements) {
      final id = sm['id'] as String;
      checkId(id, 'stockMovements');

      final productId = sm['productId'] as String;
      if (!productIds.contains(productId)) {
        throw Exception('Stock movement \$id references missing product \$productId.');
      }

      final smSaleId = sm['relatedSaleId'] as String?;
      if (smSaleId != null && !saleIds.contains(smSaleId)) {
        throw Exception('Stock movement \$id references missing sale \$smSaleId.');
      }
    }

    // Credit Records
    final creditRecordIds = <String>{};
    final customerRemainingBalances = <String, int>{};
    for (final cr in creditRecords) {
      final id = cr['id'] as String;
      checkId(id, 'creditRecords');
      creditRecordIds.add(id);

      final customerId = cr['customerId'] as String;
      if (!customerIds.contains(customerId)) {
        throw Exception(
            'Credit record \$id references missing customer \$customerId.');
      }

      final crSaleId = cr['saleId'] as String?;
      if (crSaleId != null && !saleIds.contains(crSaleId)) {
        throw Exception('Credit record \$id references missing sale \$crSaleId.');
      }

      final status = cr['status'] as String? ?? 'active';
      final isVoided = status == 'voided';
      final amount = (cr['amount'] as num).toInt();
      final paid = (cr['paidAmount'] as num).toInt();
      final remaining = amount - paid;

      if (amount <= 0) {
        throw Exception('Non-positive amount for credit record \$id.');
      }
      if (remaining < 0) {
        throw Exception('Negative remaining amount for credit record \$id.');
      }

      if (!isVoided) {
        customerRemainingBalances[customerId] =
            (customerRemainingBalances[customerId] ?? 0) + remaining;
      }
    }

    // Check customer outstanding balances
    for (final c in customers) {
      final id = c['id'] as String;
      final headerBalance = (c['outstandingBalance'] as num).toInt();
      final calculatedBalance = customerRemainingBalances[id] ?? 0;
      if (headerBalance != calculatedBalance) {
        throw Exception(
            'Customer \$id balance does not match active credit records.');
      }
    }

    // Credit Payments
    for (final cp in creditPayments) {
      final id = cp['id'] as String;
      checkId(id, 'creditPayments');

      final customerId = cp['customerId'] as String;
      if (!customerIds.contains(customerId)) {
        throw Exception(
            'Credit payment $id references missing customer $customerId.');
      }

      final amount = (cp['amount'] as num).toInt();
      if (amount <= 0) {
        throw Exception('Non-positive amount for credit payment $id.');
      }

      final isReversed = cp['isReversed'] as bool? ?? false;
      if (isReversed) {
        if (cp['reversedAt'] == null || cp['reversalReason'] == null) {
          throw Exception(
              'Reversed payment $id is missing reversal timestamp or reason.');
        }
      }
    }

    // Expenses
    for (final ex in expenses) {
      final id = ex['id'] as String;
      checkId(id, 'expenses');

      final amount = (ex['amount'] as num).toInt();
      if (amount <= 0) {
        throw Exception('Non-positive amount for expense \$id.');
      }
    }
    
    // Normalize data (modifies the map in-place)
    for (final p in products) {
      final barcode = p['barcode'] as String?;
      if (barcode != null && barcode.isNotEmpty) {
        p['barcode'] = normalizeBarcode(barcode);
      }
    }
    for (final c in customers) {
      final contact = c['contactNumber'] as String?;
      if (contact != null) {
        c['contactNumber'] = normalizeContactNumber(contact);
      }
    }
  }
}
