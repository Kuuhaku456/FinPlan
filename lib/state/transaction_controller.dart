
import 'package:flutter/foundation.dart';

import '../data/transaction_repository.dart';
import '../models/finance_transaction.dart';

// ==========================================
// TRANSACTION CONTROLLER FINPLAN
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
  // 1. STATE TRANSAKSI
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
  // 2. GETTER
  // ========================================

  List<FinanceTransaction> get transactions {
    return _transactions;
  }

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
  // 3. TANGGAL AWAL DAN AKHIR BULAN
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
  // 4. MEMUAT DATA TRANSAKSI
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
      // Rekap dihitung dari seluruh transaksi
      // pada bulan terpilih, bukan hanya
      // transaksi yang muncul di halaman pertama.
      final newSummary =
          await _repository.getMonthlySummary(
        year: firstDay.year,
        month: firstDay.month,
      );

      final newTransactions =
          await _repository.getTransactions(
        startDate: firstDay,
        endDate: lastDay,
        limit: _pageSize,
        offset: 0,
      );

      // Abaikan hasil request lama.
      if (_disposed || request != _requestVersion) {
        return;
      }

      _summary = newSummary;

      _transactions = List.unmodifiable(
        newTransactions,
      );

      _hasMore = newTransactions.length == _pageSize;

      _error = null;
    } catch (e) {
      if (_disposed || request != _requestVersion) {
        return;
      }

      _error = 'Gagal memuat transaksi. Coba lagi.';
    } finally {
      if (!_disposed && request == _requestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ========================================
  // 5. REFRESH DATA
  // ========================================

  Future<void> refresh() async {
    await loadTransactions();
  }

  // ========================================
  // 6. MENGGANTI BULAN
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
  // 7. MEMUAT TRANSAKSI BERIKUTNYA
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

      if (_disposed || request != _requestVersion) {
        return;
      }

      _transactions = List.unmodifiable([
        ..._transactions,
        ...nextTransactions,
      ]);

      _hasMore = nextTransactions.length == _pageSize;
    } catch (e) {
      if (_disposed || request != _requestVersion) {
        return;
      }

      _error = 'Gagal memuat transaksi berikutnya.';
    } finally {
      if (!_disposed && request == _requestVersion) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  // ========================================
  // 8. HELPER UNTUK OPERASI PENYIMPANAN
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

      // Jika transaksi dibuat untuk bulan lain,
      // tampilkan bulan transaksi tersebut.
      if (focusMonth != null) {
        _selectedMonth = DateTime(
          focusMonth.year,
          focusMonth.month,
          1,
        );
      }

      // Perbarui daftar dan total transaksi.
      await loadTransactions();

      return result;
    } catch (e) {
      if (!_disposed) {
        _error = 'Gagal menyimpan perubahan transaksi.';
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
  // 9. CREATE - TAMBAH TRANSAKSI
  // ========================================

  Future<int> addTransaction(
    FinanceTransaction transaction,
  ) async {
    return _performMutation<int>(
      () {
        return _repository.insertTransaction(
          transaction,
        );
      },
      focusMonth: transaction.date,
    );
  }

  // ========================================
  // 10. UPDATE - EDIT TRANSAKSI
  // ========================================

  Future<bool> updateTransaction(
    FinanceTransaction transaction,
  ) async {
    return _performMutation<bool>(
      () {
        return _repository.updateTransaction(
          transaction,
        );
      },
      focusMonth: transaction.date,
    );
  }

  // ========================================
  // 11. DELETE - HAPUS TRANSAKSI
  // ========================================

  Future<bool> deleteTransaction(int id) async {
    return _performMutation<bool>(
      () {
        return _repository.deleteTransaction(id);
      },
    );
  }

  // ========================================
  // 12. MENGAMBIL DETAIL TRANSAKSI
  // ========================================

  Future<FinanceTransaction?> getTransactionById(
    int id,
  ) async {
    return _repository.getTransactionById(id);
  }

  // ========================================
  // 13. REKAP PER AKUN
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
  // 14. MENGHAPUS PESAN ERROR
  // ========================================

  void clearError() {
    if (_disposed) return;

    _error = null;

    notifyListeners();
  }

  // ========================================
  // 15. MENUTUP DATABASE
  // ========================================

  Future<void> closeDatabase() async {
    await _repository.close();
  }

  // ========================================
  // 16. MEMBERSIHKAN CONTROLLER
  // ========================================

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;

    super.dispose();
  }
}
