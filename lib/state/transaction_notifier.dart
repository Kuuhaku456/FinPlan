import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transaction_repository.dart';
import '../models/finance_transaction.dart';
import 'transaction_controller.dart';

// ==========================================
// LEGACY CONTROLLER PROVIDER
// ==========================================

/// Menggunakan TransactionController yang
/// sudah diinisialisasi melalui ProviderScope.
final legacyTransactionControllerProvider =
    Provider<TransactionController>(
  (ref) => throw StateError(
    'TransactionController belum diinisialisasi.',
  ),
);

// ==========================================
// TRANSACTION VIEW STATE
// ==========================================

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

  int get totalIncome => summary.totalIncome;

  int get totalExpense => summary.totalExpense;

  int get netAmount => summary.netAmount;

  int get transactionCount =>
      summary.transactionCount;

  // ========================================
  // CREATE STATE FROM CONTROLLER
  // ========================================

  factory TransactionViewState.fromController(
    TransactionController controller,
  ) {
    return TransactionViewState(
      transactions:
          List<FinanceTransaction>.unmodifiable(
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

// ==========================================
// TRANSACTION STATE PROVIDER
// ==========================================

final transactionStateProvider =
    NotifierProvider<
        TransactionNotifier,
        TransactionViewState>(
  TransactionNotifier.new,
);

// ==========================================
// MONTHLY TRANSACTION TRENDS PROVIDER
// ==========================================

/// Menampilkan tren transaksi 6 bulan.
///
/// Menggunakan data rekap dari SQLite.
final monthlyTransactionTrendsProvider =
    FutureProvider<List<MonthlyTransactionTrend>>(
  (ref) async {
    final trigger = ref.watch(
      transactionStateProvider.select(
        (state) => (
          month: state.selectedMonth,
          summary: state.summary,
        ),
      ),
    );

    return ref
        .read(legacyTransactionControllerProvider)
        .getMonthlyTrends(
          endingMonth: trigger.month,
          count: 6,
        );
  },
);

// ==========================================
// MONTHLY EXPENSE CATEGORIES PROVIDER
// ==========================================

/// PROVIDER BARU
///
/// Mengambil seluruh pengeluaran berdasarkan
/// kategori untuk bulan yang sedang dipilih.
///
/// Data berasal dari query SQLite langsung,
/// sehingga tidak terpengaruh pagination.
///
/// Provider akan menghitung ulang ketika:
/// - Bulan transaksi diganti
/// - Transaksi ditambahkan
/// - Transaksi diedit
/// - Transaksi dihapus
/// - Rekap transaksi diperbarui
final monthlyExpenseCategoriesProvider =
    FutureProvider<List<ExpenseCategorySummary>>(
  (ref) async {
    final trigger = ref.watch(
      transactionStateProvider.select(
        (state) => (
          month: state.selectedMonth,
          summary: state.summary,
        ),
      ),
    );

    return ref
        .read(legacyTransactionControllerProvider)
        .getMonthlyExpenseCategorySummary(
          year: trigger.month.year,
          month: trigger.month.month,
        );
  },
);

// ==========================================
// TRANSACTION NOTIFIER
// ==========================================

class TransactionNotifier
    extends Notifier<TransactionViewState> {
  TransactionController get _controller {
    return ref.read(
      legacyTransactionControllerProvider,
    );
  }

  // ========================================
  // BUILD
  // ========================================

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

    ref.onDispose(
      () => controller.removeListener(syncState),
    );

    return TransactionViewState.fromController(
      controller,
    );
  }

  // ========================================
  // LOAD TRANSACTIONS
  // ========================================

  Future<void> loadTransactions() {
    return _controller.loadTransactions();
  }

  // ========================================
  // REFRESH
  // ========================================

  Future<void> refresh() {
    return _controller.refresh();
  }

  // ========================================
  // SELECT MONTH
  // ========================================

  Future<void> selectMonth(DateTime month) {
    return _controller.selectMonth(month);
  }

  // ========================================
  // LOAD MORE
  // ========================================

  Future<void> loadMore() {
    return _controller.loadMore();
  }

  // ========================================
  // ADD TRANSACTION
  // ========================================

  Future<int> addTransaction(
    FinanceTransaction transaction,
  ) {
    return _controller.addTransaction(
      transaction,
    );
  }

  // ========================================
  // UPDATE TRANSACTION
  // ========================================

  Future<bool> updateTransaction(
    FinanceTransaction transaction,
  ) {
    return _controller.updateTransaction(
      transaction,
    );
  }

  // ========================================
  // DELETE TRANSACTION
  // ========================================

  Future<bool> deleteTransaction(int id) {
    return _controller.deleteTransaction(id);
  }

  // ========================================
  // GET TRANSACTION BY ID
  // ========================================

  Future<FinanceTransaction?> getTransactionById(
    int id,
  ) {
    return _controller.getTransactionById(id);
  }

  // ========================================
  // ACCOUNT SUMMARY
  // ========================================

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

  // ========================================
  // MONTHLY CATEGORY SUMMARY
  // ========================================

  Future<List<ExpenseCategorySummary>>
      getMonthlyExpenseCategorySummary({
    required int year,
    required int month,
  }) {
    return _controller.getMonthlyExpenseCategorySummary(
      year: year,
      month: month,
    );
  }

  // ========================================
  // CLEAR ERROR
  // ========================================

  void clearError() {
    _controller.clearError();
  }
}