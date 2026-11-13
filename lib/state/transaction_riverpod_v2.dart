import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transaction_repository.dart';
import '../models/finance_transaction.dart';

// =====================================================
// FINPLAN - TRANSACTION RIVERPOD V2
// =====================================================
//
// State management langsung ke TransactionRepository.
//
// Tidak menggunakan:
// - TransactionController
// - ChangeNotifier
// - notifyListeners()
//
// Database SQLite dan skemanya tidak berubah.
// =====================================================

// -----------------------------------------------------
// DEPENDENCY PROVIDERS
// -----------------------------------------------------

final transactionRepositoryV2Provider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

final transactionInitialMonthV2Provider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// -----------------------------------------------------
// STATE MODEL
// -----------------------------------------------------

class TransactionV2State {
  const TransactionV2State({
    required this.selectedMonth,
    this.transactions = const <FinanceTransaction>[],
    this.summary = const TransactionSummary(
      totalIncome: 0,
      totalExpense: 0,
      transactionCount: 0,
    ),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSaving = false,
    this.hasMore = false,
    this.hasLoaded = false,
    this.revision = 0,
    this.error,
  });

  final DateTime selectedMonth;
  final List<FinanceTransaction> transactions;
  final TransactionSummary summary;

  final bool isLoading;
  final bool isLoadingMore;
  final bool isSaving;
  final bool hasMore;
  final bool hasLoaded;

  // Berubah saat database berhasil dimuat ulang.
  // Dipakai untuk memperbarui provider grafik.
  final int revision;

  final String? error;

  int get totalIncome => summary.totalIncome;
  int get totalExpense => summary.totalExpense;
  int get netAmount => summary.netAmount;
  int get transactionCount => summary.transactionCount;

  bool get isBusy => isLoading || isLoadingMore || isSaving;

  TransactionV2State copyWith({
    DateTime? selectedMonth,
    List<FinanceTransaction>? transactions,
    TransactionSummary? summary,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSaving,
    bool? hasMore,
    bool? hasLoaded,
    int? revision,
    String? error,
    bool clearError = false,
  }) {
    return TransactionV2State(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      transactions: transactions == null
          ? this.transactions
          : List<FinanceTransaction>.unmodifiable(transactions),
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSaving: isSaving ?? this.isSaving,
      hasMore: hasMore ?? this.hasMore,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      revision: revision ?? this.revision,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// -----------------------------------------------------
// PROVIDER
// -----------------------------------------------------

final transactionV2Provider =
    NotifierProvider<TransactionV2Notifier, TransactionV2State>(
      TransactionV2Notifier.new,
    );

// -----------------------------------------------------
// MONTHLY TREND MODEL
// -----------------------------------------------------

class TransactionV2MonthTrend {
  const TransactionV2MonthTrend({required this.month, required this.summary});

  final DateTime month;
  final TransactionSummary summary;

  int get income => summary.totalIncome;
  int get expense => summary.totalExpense;
  int get net => summary.netAmount;
}

// -----------------------------------------------------
// NOTIFIER
// -----------------------------------------------------

class TransactionV2Notifier extends Notifier<TransactionV2State> {
  static const int pageSize = 50;

  int _requestVersion = 0;

  TransactionRepository get _repository =>
      ref.read(transactionRepositoryV2Provider);

  @override
  TransactionV2State build() {
    final month = ref.read(transactionInitialMonthV2Provider);

    return TransactionV2State(
      selectedMonth: DateTime(month.year, month.month, 1),
    );
  }

  // ---------------------------------------------------
  // DATE HELPERS
  // ---------------------------------------------------

  DateTime _firstDay(DateTime month) {
    return DateTime(month.year, month.month, 1);
  }

  DateTime _lastDay(DateTime month) {
    return DateTime(month.year, month.month + 1, 0);
  }

  // ---------------------------------------------------
  // LOAD TRANSACTIONS
  // ---------------------------------------------------

  Future<void> loadTransactions() async {
    if (!ref.mounted) return;

    final request = ++_requestVersion;
    final month = state.selectedMonth;

    final firstDay = _firstDay(month);
    final lastDay = _lastDay(month);

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final summary = await _repository.getMonthlySummary(
        year: month.year,
        month: month.month,
      );

      final transactions = await _repository.getTransactions(
        startDate: firstDay,
        endDate: lastDay,
        limit: pageSize,
        offset: 0,
      );

      if (!ref.mounted || request != _requestVersion) {
        return;
      }

      state = state.copyWith(
        transactions: transactions,
        summary: summary,
        hasMore: transactions.length == pageSize,
        hasLoaded: true,
        revision: state.revision + 1,
        clearError: true,
      );
    } catch (_) {
      if (!ref.mounted || request != _requestVersion) {
        return;
      }

      state = state.copyWith(error: 'Gagal memuat transaksi. Coba lagi.');
    } finally {
      if (ref.mounted && request == _requestVersion) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  // ---------------------------------------------------
  // REFRESH
  // ---------------------------------------------------

  Future<void> refresh() {
    return loadTransactions();
  }

  // ---------------------------------------------------
  // SELECT MONTH
  // ---------------------------------------------------

  Future<void> selectMonth(DateTime month) async {
    if (!ref.mounted) return;

    final normalized = DateTime(month.year, month.month, 1);

    final current = state.selectedMonth;

    if (current.year == normalized.year && current.month == normalized.month) {
      return;
    }

    state = state.copyWith(
      selectedMonth: normalized,
      hasMore: false,
      hasLoaded: false,
      clearError: true,
    );

    await loadTransactions();
  }

  // ---------------------------------------------------
  // PAGINATION
  // ---------------------------------------------------

  Future<void> loadMore() async {
    if (!ref.mounted) return;

    if (state.isLoading ||
        state.isLoadingMore ||
        state.isSaving ||
        !state.hasMore) {
      return;
    }

    final request = _requestVersion;
    final month = state.selectedMonth;
    final offset = state.transactions.length;

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final next = await _repository.getTransactions(
        startDate: _firstDay(month),
        endDate: _lastDay(month),
        limit: pageSize,
        offset: offset,
      );

      if (!ref.mounted || request != _requestVersion) {
        return;
      }

      state = state.copyWith(
        transactions: [...state.transactions, ...next],
        hasMore: next.length == pageSize,
        clearError: true,
      );
    } catch (_) {
      if (!ref.mounted || request != _requestVersion) {
        return;
      }

      state = state.copyWith(error: 'Gagal memuat transaksi berikutnya.');
    } finally {
      if (ref.mounted && request == _requestVersion) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  // ---------------------------------------------------
  // MUTATION HELPER
  // ---------------------------------------------------

  Future<T> _performMutation<T>(
    Future<T> Function() operation, {
    DateTime? focusMonth,
  }) async {
    if (!ref.mounted) {
      throw StateError('Pengelola transaksi sudah ditutup.');
    }

    if (state.isSaving) {
      throw StateError('Tunggu sampai transaksi sebelumnya selesai.');
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final result = await operation();

      if (!ref.mounted) {
        return result;
      }

      if (focusMonth != null) {
        state = state.copyWith(
          selectedMonth: DateTime(focusMonth.year, focusMonth.month, 1),
        );
      }

      // Muat ulang seluruh ringkasan dari SQLite,
      // bukan hanya mengubah angka di UI.
      await loadTransactions();

      return result;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(error: 'Gagal menyimpan perubahan transaksi.');
      }

      rethrow;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isSaving: false);
      }
    }
  }

  // ---------------------------------------------------
  // ADD TRANSACTION
  // ---------------------------------------------------

  Future<int> addTransaction(FinanceTransaction transaction) {
    return _performMutation(
      () => _repository.insertTransaction(transaction),
      focusMonth: transaction.date,
    );
  }

  // ---------------------------------------------------
  // UPDATE TRANSACTION
  // ---------------------------------------------------

  Future<bool> updateTransaction(FinanceTransaction transaction) {
    return _performMutation(
      () => _repository.updateTransaction(transaction),
      focusMonth: transaction.date,
    );
  }

  // ---------------------------------------------------
  // DELETE TRANSACTION
  // ---------------------------------------------------

  Future<bool> deleteTransaction(int id) {
    return _performMutation(() => _repository.deleteTransaction(id));
  }

  // ---------------------------------------------------
  // GET TRANSACTION
  // ---------------------------------------------------

  Future<FinanceTransaction?> getTransactionById(int id) {
    return _repository.getTransactionById(id);
  }

  // ---------------------------------------------------
  // ACCOUNT SUMMARY
  // ---------------------------------------------------

  Future<TransactionSummary> getAccountSummary({
    required AccountType accountType,
    required String accountName,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _repository.getAccountSummary(
      accountType: accountType,
      accountName: accountName,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // ---------------------------------------------------
  // EXPENSE CATEGORY SUMMARY
  // ---------------------------------------------------

  Future<List<ExpenseCategorySummary>> getMonthlyExpenseCategorySummary({
    required int year,
    required int month,
  }) {
    return _repository.getMonthlyExpenseCategorySummary(
      year: year,
      month: month,
    );
  }

  // ---------------------------------------------------
  // MONTHLY TRENDS
  // ---------------------------------------------------

  Future<List<TransactionV2MonthTrend>> getMonthlyTrends({
    DateTime? endingMonth,
    int count = 6,
  }) async {
    if (count < 1 || count > 24) {
      throw ArgumentError('Jumlah bulan harus antara 1 dan 24.');
    }

    final end = endingMonth ?? state.selectedMonth;

    final months = List<DateTime>.generate(
      count,
      (index) => DateTime(end.year, end.month - count + index + 1, 1),
    );

    return Future.wait(
      months.map((month) async {
        final summary = await _repository.getMonthlySummary(
          year: month.year,
          month: month.month,
        );

        return TransactionV2MonthTrend(month: month, summary: summary);
      }),
    );
  }

  // ---------------------------------------------------
  // CLEAR ERROR
  // ---------------------------------------------------

  void clearError() {
    if (!ref.mounted) return;

    state = state.copyWith(clearError: true);
  }
}

// -----------------------------------------------------
// DASHBOARD: MONTHLY TRENDS
// -----------------------------------------------------

final transactionV2TrendsProvider =
    FutureProvider<List<TransactionV2MonthTrend>>((ref) async {
      final trigger = ref.watch(
        transactionV2Provider.select(
          (state) => (month: state.selectedMonth, revision: state.revision),
        ),
      );

      return ref
          .read(transactionV2Provider.notifier)
          .getMonthlyTrends(endingMonth: trigger.month, count: 6);
    });

// -----------------------------------------------------
// DASHBOARD: EXPENSE CATEGORY SUMMARY
// -----------------------------------------------------

final transactionV2CategoriesProvider =
    FutureProvider<List<ExpenseCategorySummary>>((ref) async {
      final trigger = ref.watch(
        transactionV2Provider.select(
          (state) => (month: state.selectedMonth, revision: state.revision),
        ),
      );

      return ref
          .read(transactionV2Provider.notifier)
          .getMonthlyExpenseCategorySummary(
            year: trigger.month.year,
            month: trigger.month.month,
          );
    });
