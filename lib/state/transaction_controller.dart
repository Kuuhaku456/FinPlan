import 'package:flutter/foundation.dart';

import '../data/transaction_repository.dart';
import '../models/finance_transaction.dart';

// ==========================================
// MONTHLY TRANSACTION TREND
// ==========================================

class MonthlyTransactionTrend {
  const MonthlyTransactionTrend({
    required this.month,
    required this.summary,
  });

  final DateTime month;
  final TransactionSummary summary;

  int get income => summary.totalIncome;
  int get expense => summary.totalExpense;
  int get net => summary.netAmount;
}

// ==========================================
// TRANSACTION CONTROLLER
// ==========================================

class TransactionController extends ChangeNotifier {
  TransactionController(
    this._repository, {
    DateTime? initialMonth,
  }) {
    final date = initialMonth ?? DateTime.now();

    _selectedMonth = DateTime(
      date.year,
      date.month,
      1,
    );
  }

  final TransactionRepository _repository;

  static const int _pageSize = 50;

  // ========================================
  // STATE
  // ========================================

  List<FinanceTransaction> _transactions = const [];

  TransactionSummary _summary =
      const TransactionSummary(
    totalIncome: 0,
    totalExpense: 0,
    transactionCount: 0,
  );

  late DateTime _selectedMonth;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSaving = false;
  bool _hasMore = false;
  bool _disposed = false;

  String? _error;

  int _requestVersion = 0;

  // ========================================
  // GETTERS
  // ========================================

  List<FinanceTransaction> get transactions =>
      _transactions;

  TransactionSummary get summary => _summary;

  DateTime get selectedMonth => _selectedMonth;

  bool get isLoading => _isLoading;

  bool get isLoadingMore => _isLoadingMore;

  bool get isSaving => _isSaving;

  bool get hasMore => _hasMore;

  String? get error => _error;

  int get totalIncome => _summary.totalIncome;

  int get totalExpense => _summary.totalExpense;

  int get netAmount => _summary.netAmount;

  int get transactionCount =>
      _summary.transactionCount;

  // ========================================
  // DATE HELPERS
  // ========================================

  DateTime get _firstDay {
    return DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );
  }

  DateTime get _lastDay {
    return DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    );
  }

  // ========================================
  // LOAD TRANSACTIONS
  // ========================================

  Future<void> loadTransactions() async {
    if (_disposed) return;

    final request = ++_requestVersion;

    final firstDay = _firstDay;
    final lastDay = _lastDay;

    _isLoading = true;
    _error = null;

    notifyListeners();

    try {
      // Rekap seluruh transaksi dalam bulan.
      final newSummary =
          await _repository.getMonthlySummary(
        year: firstDay.year,
        month: firstDay.month,
      );

      // Daftar transaksi menggunakan pagination.
      final newTransactions =
          await _repository.getTransactions(
        startDate: firstDay,
        endDate: lastDay,
        limit: _pageSize,
        offset: 0,
      );

      if (_disposed || request != _requestVersion) {
        return;
      }

      _summary = newSummary;

      _transactions = List.unmodifiable(
        newTransactions,
      );

      _hasMore =
          newTransactions.length == _pageSize;

      _error = null;
    } catch (_) {
      if (_disposed || request != _requestVersion) {
        return;
      }

      _error =
          'Gagal memuat transaksi. Coba lagi.';
    } finally {
      if (!_disposed &&
          request == _requestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ========================================
  // REFRESH
  // ========================================

  Future<void> refresh() async {
    await loadTransactions();
  }

  // ========================================
  // SELECT MONTH
  // ========================================

  Future<void> selectMonth(DateTime month) async {
    if (_disposed) return;

    final normalized = DateTime(
      month.year,
      month.month,
      1,
    );

    if (_selectedMonth.year == normalized.year &&
        _selectedMonth.month == normalized.month) {
      return;
    }

    _selectedMonth = normalized;

    await loadTransactions();
  }

  // ========================================
  // LOAD MORE
  // ========================================

  Future<void> loadMore() async {
    if (_disposed ||
        _isLoading ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }

    final request = _requestVersion;

    final firstDay = _firstDay;
    final lastDay = _lastDay;

    final offset = _transactions.length;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextTransactions =
          await _repository.getTransactions(
        startDate: firstDay,
        endDate: lastDay,
        limit: _pageSize,
        offset: offset,
      );

      if (_disposed ||
          request != _requestVersion) {
        return;
      }

      _transactions = List.unmodifiable([
        ..._transactions,
        ...nextTransactions,
      ]);

      _hasMore =
          nextTransactions.length == _pageSize;
    } catch (_) {
      if (_disposed ||
          request != _requestVersion) {
        return;
      }

      _error =
          'Gagal memuat transaksi berikutnya.';
    } finally {
      if (!_disposed &&
          request == _requestVersion) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  // ========================================
  // MUTATION HELPER
  // ========================================

  Future<T> _performMutation<T>(
    Future<T> Function() operation, {
    DateTime? focusMonth,
  }) async {
    if (_disposed) {
      throw StateError(
        'TransactionController sudah ditutup.',
      );
    }

    if (_isSaving) {
      throw StateError(
        'Tunggu sampai transaksi sebelumnya selesai.',
      );
    }

    _isSaving = true;
    _error = null;

    notifyListeners();

    try {
      final result = await operation();

      if (focusMonth != null) {
        _selectedMonth = DateTime(
          focusMonth.year,
          focusMonth.month,
          1,
        );
      }

      await loadTransactions();

      return result;
    } catch (_) {
      if (!_disposed) {
        _error =
            'Gagal menyimpan perubahan transaksi.';

        notifyListeners();
      }

      rethrow;
    } finally {
      if (!_disposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  // ========================================
  // ADD TRANSACTION
  // ========================================

  Future<int> addTransaction(
    FinanceTransaction transaction,
  ) async {
    return _performMutation<int>(
      () => _repository.insertTransaction(
        transaction,
      ),
      focusMonth: transaction.date,
    );
  }

  // ========================================
  // UPDATE TRANSACTION
  // ========================================

  Future<bool> updateTransaction(
    FinanceTransaction transaction,
  ) async {
    return _performMutation<bool>(
      () => _repository.updateTransaction(
        transaction,
      ),
      focusMonth: transaction.date,
    );
  }

  // ========================================
  // DELETE TRANSACTION
  // ========================================

  Future<bool> deleteTransaction(int id) async {
    return _performMutation<bool>(
      () => _repository.deleteTransaction(id),
    );
  }

  // ========================================
  // GET TRANSACTION BY ID
  // ========================================

  Future<FinanceTransaction?> getTransactionById(
    int id,
  ) async {
    return _repository.getTransactionById(id);
  }

  // ========================================
  // ACCOUNT SUMMARY
  // ========================================

  Future<TransactionSummary> getAccountSummary({
    required AccountType accountType,
    required String accountName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _repository.getAccountSummary(
      accountType: accountType,
      accountName: accountName,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // ========================================
  // MONTHLY TRANSACTION TRENDS
  // ========================================

  /// Mengambil tren pemasukan dan pengeluaran
  /// dari database untuk beberapa bulan.
  Future<List<MonthlyTransactionTrend>>
      getMonthlyTrends({
    DateTime? endingMonth,
    int count = 6,
  }) async {
    if (count < 1 || count > 24) {
      throw ArgumentError(
        'Jumlah bulan harus antara 1 dan 24.',
      );
    }

    final end = endingMonth ?? _selectedMonth;

    final months = List<DateTime>.generate(
      count,
      (index) => DateTime(
        end.year,
        end.month - count + index + 1,
        1,
      ),
    );

    return Future.wait(
      months.map((month) async {
        final summary =
            await _repository.getMonthlySummary(
          year: month.year,
          month: month.month,
        );

        return MonthlyTransactionTrend(
          month: month,
          summary: summary,
        );
      }),
    );
  }

  // ========================================
  // MONTHLY EXPENSE CATEGORY SUMMARY
  // ========================================

  /// Fitur baru:
  /// Mengambil rekap pengeluaran per kategori
  /// dari SQLite berdasarkan bulan tertentu.
  ///
  /// Tidak menggunakan daftar transaksi
  /// yang dibatasi pagination.
  Future<List<ExpenseCategorySummary>>
      getMonthlyExpenseCategorySummary({
    required int year,
    required int month,
  }) async {
    return _repository.getMonthlyExpenseCategorySummary(
      year: year,
      month: month,
    );
  }

  // ========================================
  // CLEAR ERROR
  // ========================================

  void clearError() {
    if (_disposed) return;

    _error = null;
    notifyListeners();
  }

  // ========================================
  // CLOSE DATABASE
  // ========================================

  Future<void> closeDatabase() async {
    await _repository.close();
  }

  // ========================================
  // DISPOSE
  // ========================================

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;

    super.dispose();
  }
}