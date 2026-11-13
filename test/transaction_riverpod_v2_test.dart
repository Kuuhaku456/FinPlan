
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celeng_id/data/transaction_repository.dart';
import 'package:celeng_id/models/finance_transaction.dart';
import 'package:celeng_id/models/transaction_category.dart';
import 'package:celeng_id/state/transaction_riverpod_v2.dart';

// =====================================================
// MEMORY REPOSITORY FOR TESTING
// =====================================================

class MemoryTransactionRepository extends Fake
    implements TransactionRepository {
  final Map<int, FinanceTransaction> _data = {};

  int _nextId = 1;

  Iterable<FinanceTransaction> _filter({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    TransactionCategory? category,
    AccountType? accountType,
    String? accountName,
  }) {
    return _data.values.where((item) {
      if (startDate != null &&
          item.date.isBefore(startDate)) {
        return false;
      }

      if (endDate != null &&
          item.date.isAfter(endDate)) {
        return false;
      }

      if (type != null && item.type != type) {
        return false;
      }

      if (category != null && item.category != category) {
        return false;
      }

      if (accountType != null &&
          item.accountType != accountType) {
        return false;
      }

      if (accountName != null &&
          item.accountName != accountName) {
        return false;
      }

      return true;
    });
  }

  TransactionSummary _summary(
    Iterable<FinanceTransaction> items,
  ) {
    var income = 0;
    var expense = 0;
    var count = 0;

    for (final item in items) {
      count++;

      if (item.type == TransactionType.income) {
        income += item.amount;
      } else {
        expense += item.amount;
      }
    }

    return TransactionSummary(
      totalIncome: income,
      totalExpense: expense,
      transactionCount: count,
    );
  }

  @override
  Future<int> insertTransaction(
    FinanceTransaction transaction,
  ) async {
    if (transaction.amount <= 0) {
      throw ArgumentError(
        'Nominal harus lebih dari nol.',
      );
    }

    final id = _nextId++;

    _data[id] = FinanceTransaction(
      id: id,
      date: transaction.date,
      amount: transaction.amount,
      type: transaction.type,
      category: transaction.category,
      accountType: transaction.accountType,
      accountName: transaction.accountName,
      description: transaction.description,
      createdAt: transaction.createdAt,
    );

    return id;
  }

  @override
  Future<List<FinanceTransaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    TransactionCategory? category,
    AccountType? accountType,
    String? accountName,
    int limit = 100,
    int offset = 0,
  }) async {
    final items = _filter(
      startDate: startDate,
      endDate: endDate,
      type: type,
      category: category,
      accountType: accountType,
      accountName: accountName,
    ).toList();

    items.sort((a, b) {
      final dateResult = b.date.compareTo(a.date);

      if (dateResult != 0) return dateResult;

      return (b.id ?? 0).compareTo(a.id ?? 0);
    });

    return items.skip(offset).take(limit).toList();
  }

  @override
  Future<TransactionSummary> getMonthlySummary({
    required int year,
    required int month,
  }) async {
    return _summary(
      _data.values.where(
        (item) =>
            item.date.year == year &&
            item.date.month == month,
      ),
    );
  }

  @override
  Future<FinanceTransaction?> getTransactionById(
    int id,
  ) async {
    return _data[id];
  }

  @override
  Future<bool> updateTransaction(
    FinanceTransaction transaction,
  ) async {
    final id = transaction.id;

    if (id == null || !_data.containsKey(id)) {
      return false;
    }

    if (transaction.amount <= 0) {
      throw ArgumentError(
        'Nominal harus lebih dari nol.',
      );
    }

    _data[id] = transaction;
    return true;
  }

  @override
  Future<bool> deleteTransaction(int id) async {
    return _data.remove(id) != null;
  }

  @override
  Future<TransactionSummary> getAccountSummary({
    required AccountType accountType,
    required String accountName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _summary(
      _filter(
        startDate: startDate,
        endDate: endDate,
        accountType: accountType,
        accountName: accountName,
      ),
    );
  }

  @override
  Future<List<ExpenseCategorySummary>>
      getMonthlyExpenseCategorySummary({
    required int year,
    required int month,
  }) async {
    final totals = <TransactionCategory, int>{};
    final counts = <TransactionCategory, int>{};

    for (final item in _data.values) {
      if (item.date.year != year ||
          item.date.month != month ||
          item.type != TransactionType.expense) {
        continue;
      }

      totals.update(
        item.category,
        (value) => value + item.amount,
        ifAbsent: () => item.amount,
      );

      counts.update(
        item.category,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return totals.entries.map((entry) {
      return ExpenseCategorySummary(
        category: entry.key,
        totalAmount: entry.value,
        transactionCount: counts[entry.key] ?? 0,
      );
    }).toList();
  }
}

// =====================================================
// TEST TRANSACTION HELPER
// =====================================================

FinanceTransaction makeTransaction({
  required int amount,
  required int month,
  int day = 5,
  TransactionType type = TransactionType.expense,
  TransactionCategory category = TransactionCategory.other,
}) {
  return FinanceTransaction(
    date: DateTime(2026, month, day),
    amount: amount,
    type: type,
    category: category,
    accountType: AccountType.bank,
    accountName: 'BCA',
    description: 'Testing FinPlan',
  );
}

// =====================================================
// TEST SUITE
// =====================================================

void main() {
  late MemoryTransactionRepository repository;
  late ProviderContainer container;
  late TransactionV2Notifier notifier;

  setUp(() {
    repository = MemoryTransactionRepository();

    container = ProviderContainer(
      overrides: [
        transactionRepositoryV2Provider.overrideWithValue(
          repository,
        ),
        transactionInitialMonthV2Provider.overrideWithValue(
          DateTime(2026, 11),
        ),
      ],
    );

    notifier = container.read(
      transactionV2Provider.notifier,
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('State awal kosong dan bulan November', () {
    final state = container.read(transactionV2Provider);

    expect(state.transactions, isEmpty);
    expect(state.selectedMonth, DateTime(2026, 11, 1));
    expect(state.totalIncome, 0);
    expect(state.totalExpense, 0);
    expect(state.hasLoaded, false);
  });

  test('Berhasil memuat data kosong', () async {
    await notifier.loadTransactions();

    final state = container.read(transactionV2Provider);

    expect(state.hasLoaded, true);
    expect(state.transactions, isEmpty);
    expect(state.isLoading, false);
    expect(state.error, isNull);
  });

  test('Tambah pemasukan dan pengeluaran', () async {
    await notifier.addTransaction(
      makeTransaction(
        amount: 6000000,
        month: 11,
        type: TransactionType.income,
      ),
    );

    await notifier.addTransaction(
      makeTransaction(
        amount: 50000,
        month: 11,
        category: TransactionCategory.food,
      ),
    );

    final state = container.read(transactionV2Provider);

    expect(state.totalIncome, 6000000);
    expect(state.totalExpense, 50000);
    expect(state.netAmount, 5950000);
    expect(state.transactionCount, 2);
    expect(state.transactions, hasLength(2));
  });

  test('Edit dan hapus transaksi', () async {
    final id = await notifier.addTransaction(
      makeTransaction(
        amount: 50000,
        month: 11,
      ),
    );

    final original = await notifier.getTransactionById(id);

    expect(original, isNotNull);

    final updated = await notifier.updateTransaction(
      original!.copyWith(
        amount: 75000,
      ),
    );

    expect(updated, true);

    var state = container.read(transactionV2Provider);

    expect(state.totalExpense, 75000);

    final deleted = await notifier.deleteTransaction(id);

    expect(deleted, true);

    state = container.read(transactionV2Provider);

    expect(state.totalExpense, 0);
    expect(state.transactionCount, 0);
  });

  test('Memilih bulan memperbarui data', () async {
    await notifier.addTransaction(
      makeTransaction(
        amount: 100000,
        month: 10,
      ),
    );

    await notifier.addTransaction(
      makeTransaction(
        amount: 200000,
        month: 11,
      ),
    );

    await notifier.selectMonth(
      DateTime(2026, 10),
    );

    final state = container.read(transactionV2Provider);

    expect(state.selectedMonth, DateTime(2026, 10, 1));
    expect(state.totalExpense, 100000);
    expect(state.transactions, hasLength(1));
  });

  test('Pagination memuat 55 transaksi', () async {
    for (var i = 0; i < 55; i++) {
      await repository.insertTransaction(
        makeTransaction(
          amount: 10000,
          month: 11,
        ),
      );
    }

    await notifier.loadTransactions();

    var state = container.read(transactionV2Provider);

    expect(state.transactions.length, 50);
    expect(state.hasMore, true);
    expect(state.transactionCount, 55);

    await notifier.loadMore();

    state = container.read(transactionV2Provider);

    expect(state.transactions.length, 55);
    expect(state.hasMore, false);
  });

  test('Grafik kategori mengambil semua data', () async {
    await notifier.addTransaction(
      makeTransaction(
        amount: 30000,
        month: 11,
        category: TransactionCategory.food,
      ),
    );

    await notifier.addTransaction(
      makeTransaction(
        amount: 20000,
        month: 11,
        category: TransactionCategory.food,
      ),
    );

    final categories = await container.read(
      transactionV2CategoriesProvider.future,
    );

    expect(categories, hasLength(1));
    expect(categories.first.totalAmount, 50000);
    expect(categories.first.transactionCount, 2);
  });

  test('Nominal tidak valid menghasilkan error', () async {
    await expectLater(
      notifier.addTransaction(
        makeTransaction(
          amount: 0,
          month: 11,
        ),
      ),
      throwsArgumentError,
    );

    final state = container.read(transactionV2Provider);

    expect(state.isSaving, false);
    expect(state.error, isNotNull);

    notifier.clearError();

    expect(
      container.read(transactionV2Provider).error,
      isNull,
    );
  });
}
