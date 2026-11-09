import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/transaction_category.dart';
import '../lib/data/transaction_repository.dart';
import '../lib/models/finance_transaction.dart';
import '../lib/state/transaction_controller.dart';
import '../lib/state/transaction_notifier.dart';

// =====================================================
// FINPLAN - TRANSACTION NOTIFIER TEST
// =====================================================

// =====================================================
// FAKE REPOSITORY
// =====================================================

/// Repository untuk testing.
/// Semua transaksi disimpan di memori.
/// Tidak membuka database SQLite.
class _MemoryTransactionRepository
    extends TransactionRepository {

  final Map<int, FinanceTransaction> _transactions = {};

  int _nextId = 1;

  bool failNextSummary = false;

  Future<void>? summaryGate;

  // =====================================================
  // FILTER TRANSACTIONS
  // =====================================================

  Iterable<FinanceTransaction> _filter({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    AccountType? accountType,
    String? accountName,
  }) {
    return _transactions.values.where((transaction) {

      if (startDate != null &&
          transaction.date.isBefore(startDate)) {
        return false;
      }

      if (endDate != null &&
          transaction.date.isAfter(endDate)) {
        return false;
      }

      if (type != null &&
          transaction.type != type) {
        return false;
      }

      if (accountType != null &&
          transaction.accountType != accountType) {
        return false;
      }

      if (accountName != null &&
          transaction.accountName != accountName) {
        return false;
      }

      return true;
    });
  }

  // =====================================================
  // CALCULATE SUMMARY
  // =====================================================

  TransactionSummary _calculateSummary(
    Iterable<FinanceTransaction> transactions,
  ) {
    var totalIncome = 0;
    var totalExpense = 0;
    var count = 0;

    for (final transaction in transactions) {
      count++;

      if (transaction.type == TransactionType.income) {
        totalIncome += transaction.amount;
      } else {
        totalExpense += transaction.amount;
      }
    }

    return TransactionSummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      transactionCount: count,
    );
  }

  // =====================================================
  // INSERT TRANSACTION
  // =====================================================

  @override
  Future<int> insertTransaction(
    FinanceTransaction transaction,
  ) async {
    if (transaction.amount <= 0) {
      throw ArgumentError(
        'Nominal harus lebih dari 0.',
      );
    }

    final id = _nextId++;

    final saved = FinanceTransaction.fromMap({
      ...transaction.toMap(),
      'id': id,
    });

    _transactions[id] = saved;

    return id;
  }

  // =====================================================
  // GET TRANSACTIONS
  // =====================================================

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

    final transactions = _filter(
      startDate: startDate,
      endDate: endDate,
      type: type,
      accountType: accountType,
      accountName: accountName,
    ).toList();

    // Urutan terbaru terlebih dahulu.
    transactions.sort((a, b) {
      final dateComparison =
          b.date.compareTo(a.date);

      if (dateComparison != 0) {
        return dateComparison;
      }

      return (b.id ?? 0).compareTo(a.id ?? 0);
    });

    return transactions
        .skip(offset)
        .take(limit)
        .toList();
  }

  // =====================================================
  // GET TRANSACTION BY ID
  // =====================================================

  @override
  Future<FinanceTransaction?> getTransactionById(
    int id,
  ) async {
    return _transactions[id];
  }

  // =====================================================
  // UPDATE TRANSACTION
  // =====================================================

  @override
  Future<bool> updateTransaction(
    FinanceTransaction transaction,
  ) async {
    final id = transaction.id;

    if (id == null || !_transactions.containsKey(id)) {
      return false;
    }

    if (transaction.amount <= 0) {
      throw ArgumentError(
        'Nominal harus lebih dari 0.',
      );
    }

    _transactions[id] = transaction;

    return true;
  }

  // =====================================================
  // DELETE TRANSACTION
  // =====================================================

  @override
  Future<bool> deleteTransaction(int id) async {
    return _transactions.remove(id) != null;
  }

  // =====================================================
  // MONTHLY SUMMARY
  // =====================================================

  @override
  Future<TransactionSummary> getMonthlySummary({
    required int year,
    required int month,
  }) async {

    if (summaryGate != null) {
      await summaryGate;
    }

    if (failNextSummary) {
      failNextSummary = false;

      throw StateError(
        'Simulasi kegagalan memuat ringkasan.',
      );
    }

    final transactions = _transactions.values.where(
      (transaction) {
        return transaction.date.year == year &&
            transaction.date.month == month;
      },
    );

    return _calculateSummary(transactions);
  }

  // =====================================================
  // ACCOUNT SUMMARY
  // =====================================================

  @override
  Future<TransactionSummary> getAccountSummary({
    required AccountType accountType,
    required String accountName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {

    final transactions = _filter(
      accountType: accountType,
      accountName: accountName,
      startDate: startDate,
      endDate: endDate,
    );

    return _calculateSummary(transactions);
  }
}

// =====================================================
// TEST DATA HELPER
// =====================================================

FinanceTransaction _createTransaction({
  required DateTime date,
  required int amount,
  TransactionType type = TransactionType.expense,
  AccountType accountType = AccountType.bank,
  String accountName = 'BCA',
  String description = 'Transaksi Testing',
}) {
  return FinanceTransaction(
    date: date,
    amount: amount,
    type: type,
    accountType: accountType,
    accountName: accountName,
    description: description,
  );
}

// =====================================================
// MAIN TEST
// =====================================================

void main() {

  late _MemoryTransactionRepository repository;

  late TransactionController controller;

  late ProviderContainer container;

  late TransactionNotifier notifier;

  // =====================================================
  // SETUP
  // =====================================================

  setUp(() {
    repository = _MemoryTransactionRepository();

    controller = TransactionController(
      repository,
      initialMonth: DateTime(2026, 11),
    );

    container = ProviderContainer(
      overrides: [
        legacyTransactionControllerProvider.overrideWithValue(
          controller,
        ),
      ],
    );

    notifier = container.read(
      transactionStateProvider.notifier,
    );
  });

  // =====================================================
  // TEARDOWN
  // =====================================================

  tearDown(() {
    container.dispose();
    controller.dispose();
  });

  group('TransactionNotifier', () {

    // =================================================
    // TEST 1 - INITIAL STATE
    // =================================================

    test(
      'state awal transaksi kosong dan bulan sesuai',
      () {

        final state = container.read(
          transactionStateProvider,
        );

        expect(
          state.transactions,
          isEmpty,
        );

        expect(
          state.totalIncome,
          0,
        );

        expect(
          state.totalExpense,
          0,
        );

        expect(
          state.netAmount,
          0,
        );

        expect(
          state.transactionCount,
          0,
        );

        expect(
          state.selectedMonth,
          DateTime(2026, 11, 1),
        );

        expect(
          state.isLoading,
          isFalse,
        );

        expect(
          state.isSaving,
          isFalse,
        );

        expect(
          state.error,
          isNull,
        );
      },
    );

    // =================================================
    // TEST 2 - ADD TRANSACTIONS
    // =================================================

    test(
      'menambahkan pemasukan dan pengeluaran',
      () async {

        final income = _createTransaction(
          date: DateTime(2026, 11, 7),
          amount: 6000000,
          type: TransactionType.income,
          description: 'Gaji',
        );

        final expense = _createTransaction(
          date: DateTime(2026, 11, 7),
          amount: 25000,
          type: TransactionType.expense,
          description: 'Makan siang',
        );

        await notifier.addTransaction(income);

        await notifier.addTransaction(expense);

        final state = container.read(
          transactionStateProvider,
        );

        expect(
          state.transactions.length,
          2,
        );

        expect(
          state.totalIncome,
          6000000,
        );

        expect(
          state.totalExpense,
          25000,
        );

        expect(
          state.netAmount,
          5975000,
        );

        expect(
          state.transactionCount,
          2,
        );

        expect(
          state.error,
          isNull,
        );
      },
    );

    // =================================================
    // TEST 3 - EDIT TRANSACTION
    // =================================================

    test(
      'mengedit nominal dan deskripsi transaksi',
      () async {

        final original = _createTransaction(
          date: DateTime(2026, 11, 7),
          amount: 25000,
          description: 'Makan siang',
        );

        final id = await notifier.addTransaction(
          original,
        );

        final saved = await notifier.getTransactionById(
          id,
        );

        expect(saved, isNotNull);

        final updated = saved!.copyWith(
          amount: 35000,
          description: 'Makan siang dan minum',
        );

        final success = await notifier.updateTransaction(
          updated,
        );

        expect(
          success,
          isTrue,
        );

        final state = container.read(
          transactionStateProvider,
        );

        expect(
          state.transactions.length,
          1,
        );

        expect(
          state.transactions.first.amount,
          35000,
        );

        expect(
          state.transactions.first.description,
          'Makan siang dan minum',
        );

        expect(
          state.totalExpense,
          35000,
        );
      },
    );

    // =================================================
    // TEST 4 - DELETE TRANSACTION
    // =================================================

    test(
      'menghapus transaksi dan memperbarui ringkasan',
      () async {

        final transaction = _createTransaction(
          date: DateTime(2026, 11, 7),
          amount: 50000,
          description: 'Transportasi',
        );

        final id = await notifier.addTransaction(
          transaction,
        );

        expect(
          container
              .read(transactionStateProvider)
              .transactionCount,
          1,
        );

        final success = await notifier.deleteTransaction(
          id,
        );

        expect(
          success,
          isTrue,
        );

        final state = container.read(
          transactionStateProvider,
        );

        expect(
          state.transactions,
          isEmpty,
        );

        expect(
          state.totalExpense,
          0,
        );

        expect(
          state.transactionCount,
          0,
        );

        final deleteAgain =
            await notifier.deleteTransaction(id);

        expect(
          deleteAgain,
          isFalse,
        );
      },
    );

    // =================================================
    // TEST 5 - MONTH FILTER
    // =================================================

    test(
      'filter bulan hanya menampilkan transaksi yang sesuai',
      () async {

        await notifier.addTransaction(
          _createTransaction(
            date: DateTime(2026, 11, 7),
            amount: 100000,
            description: 'November',
          ),
        );

        await notifier.addTransaction(
          _createTransaction(
            date: DateTime(2026, 10, 20),
            amount: 50000,
            description: 'Oktober',
          ),
        );

        // Penambahan transaksi Oktober otomatis
        // memindahkan bulan aktif ke Oktober.
        var state = container.read(
          transactionStateProvider,
        );

        expect(
          state.selectedMonth.month,
          10,
        );

        expect(
          state.transactions.length,
          1,
        );

        expect(
          state.transactions.first.description,
          'Oktober',
        );

        // Pindah ke November.
        await notifier.selectMonth(
          DateTime(2026, 11),
        );

        state = container.read(
          transactionStateProvider,
        );

        expect(
          state.selectedMonth.month,
          11,
        );

        expect(
          state.transactions.length,
          1,
        );

        expect(
          state.transactions.first.description,
          'November',
        );

        expect(
          state.totalExpense,
          100000,
        );
      },
    );

    // =================================================
    // TEST 6 - PAGINATION
    // =================================================

    test(
      'memuat transaksi lebih dari 50 menggunakan pagination',
      () async {

        // Isi repository secara langsung.
        // Tidak menggunakan notifier agar tes lebih cepat.
        for (var i = 0; i < 55; i++) {
          await repository.insertTransaction(
            _createTransaction(
              date: DateTime(2026, 11, 7),
              amount: 10000 + i,
              description: 'Transaksi $i',
            ),
          );
        }

        await notifier.loadTransactions();

        var state = container.read(
          transactionStateProvider,
        );

        // Halaman pertama berisi 50 transaksi.
        expect(
          state.transactions.length,
          50,
        );

        // Ringkasan harus menghitung semua transaksi.
        expect(
          state.transactionCount,
          55,
        );

        expect(
          state.hasMore,
          isTrue,
        );

        // Muat halaman kedua.
        await notifier.loadMore();

        state = container.read(
          transactionStateProvider,
        );

        expect(
          state.transactions.length,
          55,
        );

        expect(
          state.hasMore,
          isFalse,
        );

        expect(
          state.isLoadingMore,
          isFalse,
        );
      },
    );

    // =================================================
    // TEST 7 - ERROR HANDLING
    // =================================================

    test(
      'menampilkan error dan berhasil refresh kembali',
      () async {

        repository.failNextSummary = true;

        await notifier.loadTransactions();

        var state = container.read(
          transactionStateProvider,
        );

        expect(
          state.error,
          isNotNull,
        );

        expect(
          state.isLoading,
          isFalse,
        );

        // Refresh setelah error.
        await notifier.refresh();

        state = container.read(
          transactionStateProvider,
        );

        expect(
          state.error,
          isNull,
        );

        expect(
          state.isLoading,
          isFalse,
        );

        expect(
          state.transactions,
          isEmpty,
        );
      },
    );

    // =================================================
    // TEST 8 - LOADING STATE
    // =================================================

    test(
      'loading state berubah selama proses memuat data',
      () async {

        final gate = Completer<void>();

        repository.summaryGate = gate.future;

        final future = notifier.loadTransactions();

        var state = container.read(
          transactionStateProvider,
        );

        expect(
          state.isLoading,
          isTrue,
        );

        // Selesaikan proses memuat data.
        gate.complete();

        await future;

        state = container.read(
          transactionStateProvider,
        );

        expect(
          state.isLoading,
          isFalse,
        );

        expect(
          state.error,
          isNull,
        );
      },
    );

    // =================================================
    // TEST 9 - ACCOUNT SUMMARY
    // =================================================

    test(
      'menghitung ringkasan transaksi berdasarkan akun',
      () async {

        await notifier.addTransaction(
          _createTransaction(
            date: DateTime(2026, 11, 7),
            amount: 50000,
            accountName: 'BCA',
            description: 'Makan',
          ),
        );

        await notifier.addTransaction(
          _createTransaction(
            date: DateTime(2026, 11, 7),
            amount: 30000,
            accountType: AccountType.eMoney,
            accountName: 'DANA',
            description: 'Transportasi',
          ),
        );

        final summary = await notifier.getAccountSummary(
          accountType: AccountType.bank,
          accountName: 'BCA',
        );

        expect(
          summary.totalExpense,
          50000,
        );

        expect(
          summary.transactionCount,
          1,
        );
      },
    );

    // =================================================
    // TEST 10 - INVALID AMOUNT
    // =================================================

    test(
      'menolak transaksi dengan nominal tidak valid',
      () async {

        final transaction = _createTransaction(
          date: DateTime(2026, 11, 7),
          amount: 0,
        );

        await expectLater(
          notifier.addTransaction(transaction),
          throwsArgumentError,
        );

        final state = container.read(
          transactionStateProvider,
        );

        expect(
          state.transactions,
          isEmpty,
        );

        expect(
          state.transactionCount,
          0,
        );

        expect(
          state.isSaving,
          isFalse,
        );
      },
    );
  });
}