import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class ExpensesRepository {
  Stream<List<Expense>> watchExpenses();

  Future<void> createExpense({
    required String category,
    String? description,
    required int amount,
    required DateTime expenseDate,
  });

  Future<void> updateExpense({
    required String expenseId,
    required String category,
    String? description,
    required int amount,
    required DateTime expenseDate,
  });

  Future<void> voidExpense({required String expenseId, required String reason});
}

class DriftExpensesRepository implements ExpensesRepository {
  DriftExpensesRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Expense>> watchExpenses() => _db.watchExpenses();

  @override
  Future<void> createExpense({
    required String category,
    String? description,
    required int amount,
    required DateTime expenseDate,
  }) {
    return _db.createExpense(
      category: category,
      description: description,
      amount: amount,
      expenseDate: expenseDate,
    );
  }

  @override
  Future<void> updateExpense({
    required String expenseId,
    required String category,
    String? description,
    required int amount,
    required DateTime expenseDate,
  }) {
    return _db.updateExpense(
      expenseId: expenseId,
      category: category,
      description: description,
      amount: amount,
      expenseDate: expenseDate,
    );
  }

  @override
  Future<void> voidExpense({
    required String expenseId,
    required String reason,
  }) {
    return _db.voidExpense(expenseId: expenseId, reason: reason);
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftExpensesRepository(db);
});
