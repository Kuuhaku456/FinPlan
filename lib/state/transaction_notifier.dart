import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transaction_repository.dart';
import '../models/finance_transaction.dart';

import 'transaction_controller.dart';
import 'transaction_riverpod_v2.dart';

// =====================================================
// FINPLAN - TRANSACTION RIVERPOD BRIDGE
// =====================================================
//
// Mode lama:
// UI -> TransactionNotifier
//    -> TransactionController
//
// Mode Riverpod V2:
// UI -> TransactionNotifier
//    -> TransactionV2Notifier
//    -> TransactionRepository
//    -> SQLite
//
// Selama migrasi, V2 diaktifkan melalui:
//
// flutter run --dart-define=FINPLAN_TX_V2=true
//
// Tanpa flag, implementasi lama tetap digunakan.
// =====================================================

// =====================================================
// MODE PROVIDER
// =====================================================

final transactionV2ModeProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('FINPLAN_TX_V2', defaultValue: false);
});

// =====================================================
// LEGACY CONTROLLER PROVIDER
// =====================================================

final legacyTransactionControllerProvider = Provider<TransactionController>((
  ref,
) {
  throw StateError('TransactionController belum diinisialisasi.');
});

// =====================================================
// VIEW STATE
// =====================================================

class TransactionViewState {
  const TransactionViewState({
    required this.transactions,
    required this.summary,
    required this.selectedMonth,
    required this.isLoading,
    required this.isLoadingMore,
    required this.isSaving,
    required this.hasMore,
    required this.error,
    this.revision = 0,
  });

  final List<FinanceTransaction> transactions;

  final TransactionSummary summary;

  final DateTime selectedMonth;

  final bool isLoading;
  final bool isLoadingMore;
  final bool isSaving;
  final bool hasMore;

  final String? error;

  final int revision;

  // ===================================================
  // GETTERS
  // ===================================================

  int get totalIncome => summary.totalIncome;

  int get totalExpense => summary.totalExpense;

  int get netAmount => summary.netAmount;

  int get transactionCount => summary.transactionCount;

  // ===================================================
  // LEGACY STATE
  // ===================================================

  factory TransactionViewState.fromController(
    TransactionController controller,
  ) {
    return TransactionViewState(
      transactions: List<FinanceTransaction>.unmodifiable(
        controller.transactions,
      ),
      summary: controller.summary,
      selectedMonth: controller.selectedMonth,
      isLoading: controller.isLoading,
      isLoadingMore: controller.isLoadingMore,
      isSaving: controller.isSaving,
      hasMore: controller.hasMore,
      error: controller.error,
    );
  }

  // ===================================================
  // RIVERPOD V2 STATE
  // ===================================================

  factory TransactionViewState.fromV2(TransactionV2State v2) {
    return TransactionViewState(
      transactions: v2.transactions,
      summary: v2.summary,
      selectedMonth: v2.selectedMonth,
      isLoading: v2.isLoading,
      isLoadingMore: v2.isLoadingMore,
      isSaving: v2.isSaving,
      hasMore: v2.hasMore,
      error: v2.error,
      revision: v2.revision,
    );
  }
}

// =====================================================
// MAIN PROVIDER
// =====================================================

final transactionStateProvider =
    NotifierProvider<TransactionNotifier, TransactionViewState>(
      TransactionNotifier.new,
    );

// =====================================================
// MONTHLY TRENDS
// =====================================================

final monthlyTransactionTrendsProvider =
    FutureProvider<List<MonthlyTransactionTrend>>((ref) async {
      final useV2 = ref.watch(transactionV2ModeProvider);

      final trigger = ref.watch(
        transactionStateProvider.select(
          (value) => (
            month: value.selectedMonth,
            revision: value.revision,
            summary: value.summary,
          ),
        ),
      );

      // -----------------------------------------------
      // RIVERPOD V2
      // -----------------------------------------------

      if (useV2) {
        final rows = await ref
            .read(transactionV2Provider.notifier)
            .getMonthlyTrends(endingMonth: trigger.month, count: 6);

        return rows
            .map((row) {
              return MonthlyTransactionTrend(
                month: row.month,
                summary: row.summary,
              );
            })
            .toList(growable: false);
      }

      // -----------------------------------------------
      // LEGACY
      // -----------------------------------------------

      return ref
          .read(legacyTransactionControllerProvider)
          .getMonthlyTrends(endingMonth: trigger.month, count: 6);
    });

// =====================================================
// MONTHLY EXPENSE CATEGORIES
// =====================================================

final monthlyExpenseCategoriesProvider =
    FutureProvider<List<ExpenseCategorySummary>>((ref) async {
      final useV2 = ref.watch(transactionV2ModeProvider);

      final trigger = ref.watch(
        transactionStateProvider.select(
          (value) => (
            month: value.selectedMonth,
            revision: value.revision,
            summary: value.summary,
          ),
        ),
      );

      if (useV2) {
        return ref
            .read(transactionV2Provider.notifier)
            .getMonthlyExpenseCategorySummary(
              year: trigger.month.year,
              month: trigger.month.month,
            );
      }

      return ref
          .read(legacyTransactionControllerProvider)
          .getMonthlyExpenseCategorySummary(
            year: trigger.month.year,
            month: trigger.month.month,
          );
    });

// =====================================================
// TRANSACTION NOTIFIER
// =====================================================

class TransactionNotifier extends Notifier<TransactionViewState> {
  bool _autoLoadScheduled = false;

  // ===================================================
  // PROVIDER ACCESS
  // ===================================================

  bool get _useV2 {
    return ref.read(transactionV2ModeProvider);
  }

  TransactionController get _legacy {
    return ref.read(legacyTransactionControllerProvider);
  }

  TransactionV2Notifier get _v2 {
    return ref.read(transactionV2Provider.notifier);
  }

  // ===================================================
  // BUILD
  // ===================================================

  @override
  TransactionViewState build() {
    final useV2 = ref.watch(transactionV2ModeProvider);

    // -----------------------------------------------
    // RIVERPOD V2
    // -----------------------------------------------

    if (useV2) {
      final v2State = ref.watch(transactionV2Provider);

      // Memuat SQLite otomatis saat pertama kali
      // provider dibaca oleh FinanceShell/Dashboard.
      //
      // Menghindari pengubahan main.dart dan
      // finance_shell.dart yang sudah dimigrasikan.

      if (!_autoLoadScheduled) {
        _autoLoadScheduled = true;

        Future<void>.microtask(() async {
          if (!ref.mounted) return;

          final current = ref.read(transactionV2Provider);

          if (current.hasLoaded || current.isLoading) {
            return;
          }

          await ref.read(transactionV2Provider.notifier).loadTransactions();
        });
      }

      return TransactionViewState.fromV2(v2State);
    }

    // -----------------------------------------------
    // LEGACY MODE
    // -----------------------------------------------

    final controller = ref.watch(legacyTransactionControllerProvider);

    void syncState() {
      if (!ref.mounted) return;

      state = TransactionViewState.fromController(controller);
    }

    controller.addListener(syncState);

    ref.onDispose(() {
      controller.removeListener(syncState);
    });

    return TransactionViewState.fromController(controller);
  }

  // ===================================================
  // LOAD TRANSACTIONS
  // ===================================================

  Future<void> loadTransactions() {
    return _useV2 ? _v2.loadTransactions() : _legacy.loadTransactions();
  }

  // ===================================================
  // REFRESH
  // ===================================================

  Future<void> refresh() {
    return _useV2 ? _v2.refresh() : _legacy.refresh();
  }

  // ===================================================
  // SELECT MONTH
  // ===================================================

  Future<void> selectMonth(DateTime month) {
    return _useV2 ? _v2.selectMonth(month) : _legacy.selectMonth(month);
  }

  // ===================================================
  // LOAD MORE
  // ===================================================

  Future<void> loadMore() {
    return _useV2 ? _v2.loadMore() : _legacy.loadMore();
  }

  // ===================================================
  // ADD TRANSACTION
  // ===================================================

  Future<int> addTransaction(FinanceTransaction transaction) {
    return _useV2
        ? _v2.addTransaction(transaction)
        : _legacy.addTransaction(transaction);
  }

  // ===================================================
  // UPDATE TRANSACTION
  // ===================================================

  Future<bool> updateTransaction(FinanceTransaction transaction) {
    return _useV2
        ? _v2.updateTransaction(transaction)
        : _legacy.updateTransaction(transaction);
  }

  // ===================================================
  // DELETE TRANSACTION
  // ===================================================

  Future<bool> deleteTransaction(int id) {
    return _useV2 ? _v2.deleteTransaction(id) : _legacy.deleteTransaction(id);
  }

  // ===================================================
  // GET TRANSACTION BY ID
  // ===================================================

  Future<FinanceTransaction?> getTransactionById(int id) {
    return _useV2 ? _v2.getTransactionById(id) : _legacy.getTransactionById(id);
  }

  // ===================================================
  // ACCOUNT SUMMARY
  // ===================================================

  Future<TransactionSummary> getAccountSummary({
    required AccountType accountType,
    required String accountName,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (_useV2) {
      return _v2.getAccountSummary(
        accountType: accountType,
        accountName: accountName,
        startDate: startDate,
        endDate: endDate,
      );
    }

    return _legacy.getAccountSummary(
      accountType: accountType,
      accountName: accountName,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // ===================================================
  // EXPENSE CATEGORY SUMMARY
  // ===================================================

  Future<List<ExpenseCategorySummary>> getMonthlyExpenseCategorySummary({
    required int year,
    required int month,
  }) {
    if (_useV2) {
      return _v2.getMonthlyExpenseCategorySummary(year: year, month: month);
    }

    return _legacy.getMonthlyExpenseCategorySummary(year: year, month: month);
  }

  // ===================================================
  // CLEAR ERROR
  // ===================================================

  void clearError() {
    if (_useV2) {
      _v2.clearError();
    } else {
      _legacy.clearError();
    }
  }
}
