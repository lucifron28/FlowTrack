import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class CreditsRepository {
  Stream<List<Customer>> watchCustomers();
  Stream<CustomerCreditSummary?> watchCustomerCreditSummary(String customerId);
  Stream<List<Sale>> watchCustomerSales(String customerId);
  Stream<List<CreditPayment>> watchCustomerPayments(String customerId);
  Future<String> createCustomer({
    required String name,
    String? phone,
    String? address,
  });
  Future<void> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? address,
  });
  Future<void> deleteCustomer(String customerId);
  Future<String> recordCreditPayment({
    required String customerId,
    required int amount,
    String? notes,
    String? saleId,
    required DateTime paymentDate,
  });
}

class DriftCreditsRepository implements CreditsRepository {
  DriftCreditsRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Customer>> watchCustomers() => _db.watchCustomers();

  @override
  Stream<CustomerCreditSummary?> watchCustomerCreditSummary(String customerId) {
    return _db.watchCustomerCreditSummary(customerId);
  }

  @override
  Stream<List<Sale>> watchCustomerSales(String customerId) {
    return _db.watchCustomerSales(customerId);
  }

  @override
  Stream<List<CreditPayment>> watchCustomerPayments(String customerId) {
    return _db.watchCustomerPayments(customerId);
  }

  @override
  Future<String> createCustomer({
    required String name,
    String? phone,
    String? address,
  }) {
    return _db.createCustomer(
      name: name,
      phone: phone,
      address: address,
    );
  }

  @override
  Future<void> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? address,
  }) {
    return _db.updateCustomer(
      id: id,
      name: name,
      phone: phone,
      address: address,
    );
  }

  @override
  Future<void> deleteCustomer(String customerId) {
    return _db.deleteCustomer(customerId);
  }

  @override
  Future<String> recordCreditPayment({
    required String customerId,
    required int amount,
    String? notes,
    String? saleId,
    required DateTime paymentDate,
  }) {
    return _db.recordCreditPayment(
      customerId: customerId,
      amount: amount,
      notes: notes,
      saleId: saleId,
      paymentDate: paymentDate,
    );
  }
}

final creditsRepositoryProvider = Provider<CreditsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftCreditsRepository(db);
});
