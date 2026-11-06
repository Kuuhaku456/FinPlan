import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transaction_repository.dart';
import '../models/finance_transaction.dart';
import 'transaction_controller.dart';

// =====================================================
// FINPLAN - TRANSACTION RIVERPOD
// =====================================================

// Menghubungkan Riverpod dengan TransactionController lama.
//
// Controller lama tetap dipertahankan selama migrasi
// agar database SQLite dan transaksi pengguna tidak berubah.

final legacyTransactionControllerProvider =
    Provider<TransactionController>(
  (ref) => throw StateError(
    'TransactionController belum diinisialisasi.',
  ),
);

// =====================================================
// TRANSACTION STATE
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
  });

  final List<FinanceTransaction> transactions;

  final TransactionSummary summary;

  final DateTime selectedMonth;

  final bool isLoading;

  final bool isLoadingMore;

  final bool isSaving;

  final bool hasMore;

  final String? error;

  // =================================================
  // GETTERS
  // =================================================

  int get totalIncome => summary.totalIncome;

  int get totalExpense => summary.totalExpense;

  int get netAmount => summary.netAmount;

  int get transactionCount => summary.transactionCount;

  // =================================================
  // MEMBACA DATA DARI CONTROLLER LAMA
  // =================================================

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
}

// =====================================================
// TRANSACTION PROVIDER
// =====================================================

final transactionStateProvider =
    NotifierProvider<TransactionNotifier, TransactionViewState>(
  TransactionNotifier.new,
);

// =====================================================
// TRANSACTION NOTIFIER
// =====================================================

class TransactionNotifier extends Notifier<TransactionViewState> {
  TransactionController get _controller =>
      ref.read(legacyTransactionControllerProvider);

  // =================================================
  // INITIALIZATION
  // =================================================

  @override
  TransactionViewState build() {
    final controller = ref.watch(
      legacyTransactionControllerProvider,
    );

    void syncState() {
      state = TransactionViewState.fromController(
        controller,
      );
    }

    controller.addListener(syncState);

    ref.onDispose(() {
      controller.removeListener(syncState);
    });

    return TransactionViewState.fromController(
      controller,
    );
  }

  // =================================================
  // LOAD TRANSACTIONS
  // =================================================

  Future<void> loadTransactions() {
    return _controller.loadTransactions();
  }

  // =================================================
  // REFRESH
  // =================================================

  Future<void> refresh() {
    return _controller.refresh();
  }

  // =================================================
  // FILTER MONTH
  // =================================================

  Future<void> selectMonth(DateTime month) {
    return _controller.selectMonth(month);
  }

  // =================================================
  // PAGINATION
  // =================================================

  Future<void> loadMore() {
    return _controller.loadMore();
  }

  // =================================================
  // ADD TRANSACTION
  // =================================================

  Future<int> addTransaction(
    FinanceTransaction transaction,
  ) {
    return _controller.addTransaction(transaction);
  }

  // =================================================
  // UPDATE TRANSACTION
  // =================================================

  Future<bool> updateTransaction(
    FinanceTransaction transaction,
  ) {
    return _controller.updateTransaction(transaction);
  }

  // =================================================
  // DELETE TRANSACTION
  // =================================================

  Future<bool> deleteTransaction(int id) {
    return _controller.deleteTransaction(id);
  }

  // =================================================
  // GET TRANSACTION DETAIL
  // =================================================

  Future<FinanceTransaction?> getTransactionById(
    int id,
  ) {
    return _controller.getTransactionById(id);
  }

  // =================================================
  // ACCOUNT SUMMARY
  // =================================================

  Future<TransactionSummary> getAccountSummary({
    required AccountType accountType,
    required String accountName,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _controller.getAccountSummary(
      accountType: accountType,
      accountName: accountName,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // =================================================
  // CLEAR ERROR
  // =================================================

  void clearError() {
    _controller.clearError();
  }
}