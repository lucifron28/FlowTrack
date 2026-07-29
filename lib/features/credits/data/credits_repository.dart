import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class CreditsRepository {
  Stream<List<Customer>> watchCustomers();
  Stream<Customer?> watchCustomer(String customerId);
  Stream<List<CreditRecordListEntry>> watchCreditRecordsWithSale(
    String customerId,
  );
  Stream<List<CreditPayment>> watchCreditPayments(String customerId);

  Future<String> createCustomer({required String name, String? contactNumber});

  Future<void> updateCustomer({
    required String customerId,
    required String name,
    String? contactNumber,
  });

  Future<void> deleteCustomer(String customerId);

  Future<void> recordCreditPayment({
    required String customerId,
    required int amount,
    required DateTime paymentDate,
    String? notes,
  });

  Future<void> reverseCreditPayment({
    required String paymentId,
    required String reason,
  });
}

class DriftCreditsRepository implements CreditsRepository {
  DriftCreditsRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Customer>> watchCustomers() => _db.watchCustomers();

  @override
  Stream<Customer?> watchCustomer(String customerId) {
    return _db.watchCustomer(customerId);
  }

  @override
  Stream<List<CreditRecordListEntry>> watchCreditRecordsWithSale(
    String customerId,
  ) {
    return _db.watchCreditRecordsWithSale(customerId);
  }

  @override
  Stream<List<CreditPayment>> watchCreditPayments(String customerId) {
    return _db.watchCreditPayments(customerId);
  }

  @override
  Future<String> createCustomer({required String name, String? contactNumber}) {
    return _db.createCustomer(name: name, contactNumber: contactNumber);
  }

  @override
  Future<void> updateCustomer({
    required String customerId,
    required String name,
    String? contactNumber,
  }) {
    return _db.updateCustomer(
      customerId: customerId,
      name: name,
      contactNumber: contactNumber,
    );
  }

  @override
  Future<void> deleteCustomer(String customerId) {
    return _db.deleteCustomer(customerId);
  }

  @override
  Future<void> recordCreditPayment({
    required String customerId,
    required int amount,
    required DateTime paymentDate,
    String? notes,
  }) {
    return _db.recordCreditPayment(
      customerId: customerId,
      amount: amount,
      paymentDate: paymentDate,
      notes: notes,
    );
  }

  @override
  Future<void> reverseCreditPayment({
    required String paymentId,
    required String reason,
  }) {
    return _db.reverseCreditPayment(paymentId: paymentId, reason: reason);
  }
}

final creditsRepositoryProvider = Provider<CreditsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftCreditsRepository(db);
});
