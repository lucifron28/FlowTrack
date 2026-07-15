import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../database/app_database.dart';

class BackupService {
  const BackupService(this._database);

  static const backupVersion = 1;
  static const fileExtension = 'flowtrack-backup';
  static const _channel = MethodChannel('flowtrack/backup_file');

  final AppDatabase _database;

  Future<String> createBackupJson({DateTime? createdAt}) async {
    final backup = await _createBackupMap(createdAt: createdAt);
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  Future<String?> saveBackupFile() async {
    final json = await createBackupJson();
    final bytes = Uint8List.fromList(utf8.encode(json));
    return _channel.invokeMethod<String>('saveBackup', {
      'fileName': _backupFileName(DateTime.now()),
      'bytes': bytes,
    });
  }

  Future<void> shareBackupFile() async {
    final json = await createBackupJson();
    final bytes = Uint8List.fromList(utf8.encode(json));
    await _channel.invokeMethod<void>('shareBackup', {
      'fileName': _backupFileName(DateTime.now()),
      'bytes': bytes,
    });
  }

  Future<bool> pickAndRestoreBackup() async {
    final bytes = await _channel.invokeMethod<Uint8List>('pickBackup');
    if (bytes == null || bytes.isEmpty) {
      return false;
    }
    await restoreFromJsonString(utf8.decode(bytes));
    return true;
  }

  Future<void> restoreFromJsonString(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, Object?>) {
      throw const BackupException(
        'Backup file is not a valid FlowTrack backup.',
      );
    }

    final metadata = _readMap(decoded, 'metadata');
    final data = _readMap(decoded, 'data');
    final appName = metadata['appName'];
    final version = metadata['backupVersion'];
    if (appName != AppConfig.appName) {
      throw const BackupException('Backup file is not for FlowTrack.');
    }
    if (version != backupVersion) {
      throw BackupException('Backup version $version is not supported.');
    }

    await _database.transaction(() async {
      await _clearRestorableData();
      await _restoreRows(
        data,
        'appMetadata',
        (json) => AppMetadataData.fromJson(json).toCompanion(true),
        _database.appMetadata,
      );
      await _restoreRows(
        data,
        'settings',
        (json) => Setting.fromJson(json).toCompanion(true),
        _database.settings,
      );
      await _restoreRows(
        data,
        'products',
        (json) => Product.fromJson(json).toCompanion(true),
        _database.products,
      );
      await _restoreRows(
        data,
        'customers',
        (json) => Customer.fromJson(json).toCompanion(true),
        _database.customers,
      );
      await _restoreRows(
        data,
        'sales',
        (json) => Sale.fromJson(json).toCompanion(true),
        _database.sales,
      );
      await _restoreRows(
        data,
        'saleItems',
        (json) => SaleItem.fromJson(json).toCompanion(true),
        _database.saleItems,
      );
      await _restoreRows(
        data,
        'creditRecords',
        (json) => CreditRecord.fromJson(json).toCompanion(true),
        _database.creditRecords,
      );
      await _restoreRows(
        data,
        'creditPayments',
        (json) {
          final Map<String, dynamic> copy = Map<String, dynamic>.from(json);
          copy.putIfAbsent('isReversed', () => false);
          copy.putIfAbsent('reversedAt', () => null);
          copy.putIfAbsent('reversalReason', () => null);
          return CreditPayment.fromJson(copy).toCompanion(true);
        },
        _database.creditPayments,
      );
      await _restoreRows(
        data,
        'expenses',
        (json) => Expense.fromJson(json).toCompanion(true),
        _database.expenses,
      );
      await _restoreRows(
        data,
        'stockMovements',
        (json) => StockMovement.fromJson(json).toCompanion(true),
        _database.stockMovements,
      );
      await _restoreRows(
        data,
        'auditLogs',
        (json) => AuditLog.fromJson(json).toCompanion(true),
        _database.auditLogs,
      );
    });
  }

  Future<Map<String, Object?>> _createBackupMap({DateTime? createdAt}) async {
    final created = createdAt ?? DateTime.now();
    return {
      'metadata': {
        'appName': AppConfig.appName,
        'appVersion': AppConfig.appVersion,
        'backupVersion': backupVersion,
        'databaseVersion': _database.schemaVersion,
        'createdAt': created.toUtc().toIso8601String(),
      },
      'data': {
        'products': await _jsonRows(_database.select(_database.products).get()),
        'stockMovements': await _jsonRows(
          _database.select(_database.stockMovements).get(),
        ),
        'sales': await _jsonRows(_database.select(_database.sales).get()),
        'saleItems': await _jsonRows(
          _database.select(_database.saleItems).get(),
        ),
        'customers': await _jsonRows(
          _database.select(_database.customers).get(),
        ),
        'creditRecords': await _jsonRows(
          _database.select(_database.creditRecords).get(),
        ),
        'creditPayments': await _jsonRows(
          _database.select(_database.creditPayments).get(),
        ),
        'expenses': await _jsonRows(_database.select(_database.expenses).get()),
        'settings': await _jsonRows(_database.select(_database.settings).get()),
        'appMetadata': await _jsonRows(
          _database.select(_database.appMetadata).get(),
        ),
        'auditLogs': await _jsonRows(
          _database.select(_database.auditLogs).get(),
        ),
      },
    };
  }

  Future<void> _clearRestorableData() async {
    await _database.delete(_database.auditLogs).go();
    await _database.delete(_database.creditPayments).go();
    await _database.delete(_database.creditRecords).go();
    await _database.delete(_database.saleItems).go();
    await _database.delete(_database.stockMovements).go();
    await _database.delete(_database.sales).go();
    await _database.delete(_database.expenses).go();
    await _database.delete(_database.products).go();
    await _database.delete(_database.customers).go();
    await _database.delete(_database.settings).go();
    await _database.delete(_database.appMetadata).go();
  }

  Future<List<Map<String, Object?>>> _jsonRows<T extends DataClass>(
    Future<List<T>> rows,
  ) async {
    return (await rows).map((row) => row.toJson()).toList();
  }

  Future<void> _restoreRows<T extends Table, D>(
    Map<String, Object?> data,
    String key,
    Insertable<D> Function(Map<String, Object?> json) fromJson,
    TableInfo<T, D> table,
  ) async {
    final rows = _readList(data, key);
    for (final row in rows) {
      if (row is! Map<String, Object?>) {
        throw BackupException('Backup table $key contains an invalid row.');
      }
      await _database.into(table).insert(fromJson(row));
    }
  }

  Map<String, Object?> _readMap(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is Map<String, Object?>) {
      return value;
    }
    throw BackupException('Backup is missing $key.');
  }

  List<Object?> _readList(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is List<Object?>) {
      return value;
    }
    throw BackupException('Backup is missing table $key.');
  }

  String _backupFileName(DateTime now) {
    final local = now.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'flowtrack-backup-${local.year}-${two(local.month)}-${two(local.day)}-'
        '${two(local.hour)}${two(local.minute)}.$fileExtension';
  }
}

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}
