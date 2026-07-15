import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flowtrack/core/config/app_config.dart';
import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/services/backup_service.dart';

Future<String> createUnencryptedBackupJsonForTest(AppDatabase db, {DateTime? createdAt, int backupVersion = 1}) async {
  final created = createdAt ?? DateTime.now();
  final backup = {
    'metadata': {
      'appName': AppConfig.appName,
      'appVersion': AppConfig.appVersion,
      'backupVersion': backupVersion,
      'databaseVersion': db.schemaVersion,
      'createdAt': created.toUtc().toIso8601String(),
    },
    'data': {
      'products': (await db.select(db.products).get()).map((e) => e.toJson(serializer: const ValueSerializer.defaults())).toList(),
      'stockMovements': (await db.select(db.stockMovements).get()).map((e) => e.toJson(serializer: const ValueSerializer.defaults())).toList(),
      'sales': (await db.select(db.sales).get()).map((e) => e.toJson(serializer: const ValueSerializer.defaults())).toList(),
      'saleItems': (await db.select(db.saleItems).get()).map((e) => e.toJson(serializer: const ValueSerializer.defaults())).toList(),
      'customers': (await db.select(db.customers).get()).map((e) => e.toJson(serializer: const ValueSerializer.defaults())).toList(),
      'creditRecords': (await db.select(db.creditRecords).get()).map((e) => e.toJson(serializer: const ValueSerializer.defaults())).toList(),
      'creditPayments': (await db.select(db.creditPayments).get()).map((e) => e.toJson(serializer: const ValueSerializer.defaults())).toList(),
      'expenses': (await db.select(db.expenses).get()).map((e) => e.toJson(serializer: const ValueSerializer.defaults())).toList(),
      'settings': (await db.select(db.settings).get()).map((e) => e.toJson(serializer: const ValueSerializer.defaults())).toList(),
      'appMetadata': (await db.select(db.appMetadata).get()).map((e) => e.toJson(serializer: const ValueSerializer.defaults())).toList(),
      'auditLogs': (await db.select(db.auditLogs).get()).map((e) => e.toJson(serializer: const ValueSerializer.defaults())).toList(),
    }
  };
  return const JsonEncoder.withIndent('  ').convert(backup);
}
