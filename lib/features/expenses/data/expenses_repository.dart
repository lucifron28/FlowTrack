import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class ExpensesRepository {
  Stream<List<Expense>> watchExpenses();
  Future<String> recordExpense({
    required String category,
    required int amount,
    String? notes,
    required DateTime expenseDate,
  });
  Future<void> voidExpense(String expenseId, {required String reason});
}

class DriftExpensesRepository implements ExpensesRepository {
  DriftExpensesRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Expense>> watchExpenses() => _db.watchExpenses();

  @override
  Future<String> recordExpense({
    required String category,
    required int amount,
    String? notes,
    required DateTime expenseDate,
  }) {
    return _db.recordExpense(
      category: category,
      amount: amount,
      notes: notes,
      expenseDate: expenseDate,
    );
  }

  @override
  Future<void> voidExpense(String expenseId, {required String reason}) {
    return _db.voidExpense(expenseId, reason: reason);
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftExpensesRepository(db);
});
