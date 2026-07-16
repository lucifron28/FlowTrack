import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../database/app_database.dart';

import 'backup_crypto_service.dart';
import 'backup_validator.dart';

class ValidatedBackup {
  final Map<String, dynamic> _data;
  
  final int backupVersion;
  final String createdAt;
  final int productsCount;
  final int salesCount;

  const ValidatedBackup._(this._data, {
    required this.backupVersion,
    required this.createdAt,
    required this.productsCount,
    required this.salesCount,
  });
}

class BackupService {
  const BackupService(
    this._database,
    this._cryptoService,
    this._validator,
  );

  static const backupVersion = 2;
  static const fileExtension = 'flowtrack-backup';
  static const _channel = MethodChannel('flowtrack/backup_file');

  final AppDatabase _database;
  final BackupCryptoService _cryptoService;
  final BackupValidator _validator;


  Future<String> createBackupJson(String passphrase, {
    DateTime? createdAt,
  }) async {
    if (passphrase.length < 8) {
      throw const BackupException('Passphrase must be at least 8 characters.');
    }
    final backup = await _createBackupMap(createdAt: createdAt);
    final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
    return _cryptoService.encryptBackup(jsonString, passphrase);
  }

  Future<String?> saveBackupFile(String passphrase) async {
    final json = await createBackupJson(passphrase);
    final bytes = Uint8List.fromList(utf8.encode(json));
    return _channel.invokeMethod<String>('saveBackup', {
      'fileName': _backupFileName(DateTime.now()),
      'bytes': bytes,
    });
  }

  Future<void> shareBackupFile(String passphrase) async {
    final json = await createBackupJson(passphrase);
    final bytes = Uint8List.fromList(utf8.encode(json));
    await _channel.invokeMethod<void>('shareBackup', {
      'fileName': _backupFileName(DateTime.now()),
      'bytes': bytes,
    });
  }

  Future<String?> pickBackupFile() async {
    final bytes = await _channel.invokeMethod<Uint8List>('pickBackup');
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    // Limit to 25 MiB
    if (bytes.length > 25 * 1024 * 1024) {
      throw const BackupException('Backup file is too large (exceeds 25 MiB).');
    }
    return utf8.decode(bytes);
  }

  Future<ValidatedBackup> validateBackupString(
    String fileContents, {
    String? passphrase,
  }) async {
    // Limit to 25 MiB in Dart as well
    if (utf8.encode(fileContents).length > 25 * 1024 * 1024) {
      throw const BackupException('Backup file is too large (exceeds 25 MiB).');
    }

    String jsonString = fileContents;
    bool isEncrypted = false;
    
    Map<String, dynamic>? envelope;
    try {
      final decoded = jsonDecode(fileContents);
      if (decoded is Map<String, dynamic>) {
        envelope = decoded;
      }
    } catch (e) {
      // Not JSON, might be corrupt
      throw const BackupException('Backup file is not valid JSON.');
    }

    // Malformed encrypted envelopes can fall through as legacy files:
    // Any file containing the encrypted format marker must be handled as encrypted and rejected if its envelope is malformed or unsupported.
    if (envelope != null && envelope['format'] == BackupCryptoService.formatLabel) {
      if (envelope['formatVersion'] != BackupCryptoService.formatVersion) {
        throw const BackupException('Incorrect passphrase or corrupted backup.');
      }
      isEncrypted = true;
      if (passphrase == null || passphrase.isEmpty) {
        throw const BackupException('Passphrase required.'); // Need passphrase signal
      }
      try {
        jsonString = await _cryptoService.decryptBackup(fileContents, passphrase);
      } catch (e) {
        // Return exactly "Incorrect passphrase or corrupted backup."
        throw const BackupException('Incorrect passphrase or corrupted backup.');
      }
    }

    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const BackupException('Backup file is not a valid FlowTrack backup.');
    }

    try {
      _validator.validateBackup(decoded, isEncrypted ? 2 : 1);
    } catch (e) {
      throw BackupException(e.toString().replaceAll('Exception: ', ''));
    }

    final metadata = decoded['metadata'] as Map<String, dynamic>? ?? {};
    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    return ValidatedBackup._(
      decoded,
      backupVersion: metadata['backupVersion'] as int? ?? (isEncrypted ? 2 : 1),
      createdAt: metadata['createdAt'] as String? ?? 'Unknown time',
      productsCount: (data['products'] as List?)?.length ?? 0,
      salesCount: (data['sales'] as List?)?.length ?? 0,
    );
  }

  Future<void> restoreValidatedBackup(ValidatedBackup validatedBackup) async {
    final decoded = validatedBackup._data;
    final data = _readMap(decoded, 'data');

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
        (json) {
          final copy = Map<String, Object?>.from(json);
          copy.putIfAbsent('isVoided', () => false);
          copy.putIfAbsent('voidedAt', () => null);
          copy.putIfAbsent('voidReason', () => null);
          return Expense.fromJson(copy).toCompanion(true);
        },
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
      
      await _database.into(_database.auditLogs).insert(
        AuditLogsCompanion.insert(
          id: _database.generateId(),
          action: 'restore_backup',
          entityType: 'database',
          entityId: 'backup',
          notes: const Value('Database restored from backup.'),
          createdAt: DateTime.now(),
        ),
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
