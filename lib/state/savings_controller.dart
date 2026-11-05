import 'package:flutter/foundation.dart';

import '../data/savings_repository.dart';
import '../models/savings_goal.dart';

// ============================================================
// SAVINGS CONTROLLER
// ============================================================

class SavingsController extends ChangeNotifier {
  SavingsController(this._repository);

  final SavingsRepository _repository;

  // ==========================================================
  // STATE
  // ==========================================================

  List<SavingsGoal> _allGoals = [];

  SavingsSummary _summary = const SavingsSummary(
    totalSaved: 0,
    totalTarget: 0,
    activeGoals: 0,
    completedGoals: 0,
    archivedGoals: 0,
  );

  final Map<String, List<SavingsMovement>> _historyCache = {};

  final Set<String> _loadingHistoryIds = {};

  bool _isLoading = false;

  bool _hasLoaded = false;

  int _activeMutations = 0;

  String? _error;

  bool _isDisposed = false;

  // Untuk mencegah hasil load lama menimpa data terbaru.
  int _loadRequestId = 0;

  // Untuk menandai versi data yang sedang ditampilkan.
  int _dataVersion = 0;

  // ==========================================================
  // GETTERS: STATUS
  // ==========================================================

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  bool get isSaving => _activeMutations > 0;

  String? get error => _error;

  bool get hasError => _error != null;

  // ==========================================================
  // GETTERS: DATA KANTONG
  // ==========================================================

  List<SavingsGoal> get allGoals {
    return List<SavingsGoal>.unmodifiable(
      _allGoals,
    );
  }

  List<SavingsGoal> get activeGoals {
    return List<SavingsGoal>.unmodifiable(
      _allGoals.where(
        (goal) => !goal.isArchived,
      ),
    );
  }

  List<SavingsGoal> get archivedGoals {
    return List<SavingsGoal>.unmodifiable(
      _allGoals.where(
        (goal) => goal.isArchived,
      ),
    );
  }

  // Alias untuk halaman daftar kantong.
  List<SavingsGoal> get goals => activeGoals;

  // ==========================================================
  // GETTERS: RINGKASAN
  // ==========================================================

  SavingsSummary get summary => _summary;

  int get totalSaved => _summary.totalSaved;

  int get totalTarget => _summary.totalTarget;

  int get remainingTarget => _summary.remainingTarget;

  double get progress => _summary.progress;

  double get progressPercent => _summary.progressPercent;

  int get activeGoalCount => _summary.activeGoals;

  int get completedGoalCount => _summary.completedGoals;

  int get archivedGoalCount => _summary.archivedGoals;

  bool get hasGoals => _summary.activeGoals > 0;

  // ==========================================================
  // NOTIFY SECARA AMAN
  // ==========================================================

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ==========================================================
  // FORMAT ERROR
  // ==========================================================

  String _errorMessage(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    if (error is ArgumentError) {
      return error.message?.toString() ??
          'Data yang dimasukkan tidak valid.';
    }

    return error.toString();
  }

  // ==========================================================
  // HAPUS PESAN ERROR
  // ==========================================================

  void clearError() {
    if (_error == null) return;

    _error = null;

    _notifySafely();
  }

  // ==========================================================
  // HITUNG RINGKASAN DARI DATA TERBARU
  // ==========================================================

  SavingsSummary _calculateSummary(
    List<SavingsGoal> goals,
  ) {
    int totalSaved = 0;
    int totalTarget = 0;
    int activeCount = 0;
    int completedCount = 0;
    int archivedCount = 0;

    for (final goal in goals) {
      if (goal.isArchived) {
        archivedCount++;
        continue;
      }

      activeCount++;

      totalSaved += goal.savedAmount;
      totalTarget += goal.targetAmount;

      if (goal.isCompleted) {
        completedCount++;
      }
    }

    return SavingsSummary(
      totalSaved: totalSaved,
      totalTarget: totalTarget,
      activeGoals: activeCount,
      completedGoals: completedCount,
      archivedGoals: archivedCount,
    );
  }

  // ==========================================================
  // SORT RIWAYAT
  // ==========================================================

  List<SavingsMovement> _sortMovements(
    List<SavingsMovement> movements,
  ) {
    final sorted = <SavingsMovement>[
      ...movements,
    ];

    sorted.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return List<SavingsMovement>.unmodifiable(
      sorted,
    );
  }

  // ==========================================================
  // PERBARUI CACHE RIWAYAT
  // ==========================================================

  void _rebuildHistoryCache(
    List<SavingsGoal> goals,
  ) {
    _historyCache.clear();

    for (final goal in goals) {
      _historyCache[goal.id] = _sortMovements(
        goal.movements,
      );
    }
  }

  // ==========================================================
  // MEMUAT SEMUA KANTONG
  // ==========================================================

  Future<void> loadGoals({
    bool showLoading = true,
  }) async {
    if (_isDisposed) return;

    final requestId = ++_loadRequestId;

    if (showLoading) {
      _isLoading = true;
    }

    _error = null;

    _notifySafely();

    try {
      final loadedGoals = await _repository.getAllGoals(
        includeArchived: true,
      );

      // Abaikan hasil apabila controller sudah dispose
      // atau ada permintaan load yang lebih baru.
      if (_isDisposed || requestId != _loadRequestId) {
        return;
      }

      _allGoals = List<SavingsGoal>.unmodifiable(
        loadedGoals,
      );

      // Ringkasan dihitung dari daftar yang sama
      // agar total dan daftar kantong tetap konsisten.
      _summary = _calculateSummary(
        _allGoals,
      );

      _rebuildHistoryCache(
        _allGoals,
      );

      _dataVersion++;

      _hasLoaded = true;

      _error = null;
    } catch (error) {
      if (_isDisposed || requestId != _loadRequestId) {
        return;
      }

      _error = _errorMessage(error);

      // Data lama tetap dipertahankan jika load gagal.
    } finally {
      if (!_isDisposed && requestId == _loadRequestId) {
        _isLoading = false;

        _notifySafely();
      }
    }
  }

  // ==========================================================
  // REFRESH DATA
  // ==========================================================

  Future<void> refresh() {
    return loadGoals(
      showLoading: false,
    );
  }

  // ==========================================================
  // MENCARI KANTONG DARI ID
  // ==========================================================

  SavingsGoal? goalById(String goalId) {
    for (final goal in _allGoals) {
      if (goal.id == goalId) {
        return goal;
      }
    }

    return null;
  }

  // ==========================================================
  // MENGAMBIL RIWAYAT DARI CACHE
  // ==========================================================

  List<SavingsMovement> historyForGoal(
    String goalId,
  ) {
    return _historyCache[goalId] ??
        const <SavingsMovement>[];
  }

  // ==========================================================
  // STATUS LOADING RIWAYAT
  // ==========================================================

  bool isLoadingHistory(String goalId) {
    return _loadingHistoryIds.contains(goalId);
  }

  // ==========================================================
  // MEMUAT RIWAYAT LANGSUNG DARI REPOSITORY
  // ==========================================================

  Future<List<SavingsMovement>> loadMovementHistory(
    String goalId,
  ) async {
    if (_isDisposed) {
      return const <SavingsMovement>[];
    }

    _loadingHistoryIds.add(goalId);

    final requestedVersion = _dataVersion;

    _notifySafely();

    try {
      final movements = await _repository.getMovementHistory(
        goalId,
      );

      final sorted = _sortMovements(movements);

      if (!_isDisposed) {
        // Jangan menimpa riwayat baru dengan hasil
        // permintaan lama.
        if (requestedVersion == _dataVersion) {
          _historyCache[goalId] = sorted;

          _notifySafely();
        }
      }

      return sorted;
    } catch (error) {
      if (!_isDisposed) {
        _error = _errorMessage(error);

        _notifySafely();
      }

      rethrow;
    } finally {
      if (!_isDisposed) {
        _loadingHistoryIds.remove(goalId);

        _notifySafely();
      }
    }
  }

  // ==========================================================
  // HELPER UNTUK OPERASI PENYIMPANAN
  // ==========================================================

  Future<T> _performMutation<T>(
    Future<T> Function() operation,
  ) async {
    if (_isDisposed) {
      throw StateError(
        'SavingsController sudah ditutup.',
      );
    }

    _activeMutations++;

    _error = null;

    _notifySafely();

    try {
      final result = await operation();

      // Ambil data paling baru dari penyimpanan
      // setelah operasi berhasil.
      await refresh();

      return result;
    } catch (error) {
      if (!_isDisposed) {
        _error = _errorMessage(error);

        _notifySafely();
      }

      // Dilempar kembali agar UI bisa menampilkan
      // SnackBar sesuai jenis kesalahan.
      rethrow;
    } finally {
      _activeMutations--;

      _notifySafely();
    }
  }

  // ==========================================================
  // MEMBUAT KANTONG BARU
  // ==========================================================

  Future<SavingsGoal> createGoal(
    SavingsGoal goal,
  ) {
    return _performMutation(() {
      return _repository.createGoal(goal);
    });
  }

  // ==========================================================
  // SIMPAN KANTONG (CREATE ATAU EDIT)
  // ==========================================================

  Future<SavingsGoal> saveGoal(
    SavingsGoal goal,
  ) {
    return _performMutation(() {
      return _repository.saveGoal(goal);
    });
  }

  // ==========================================================
  // EDIT INFORMASI KANTONG
  // ==========================================================

  Future<SavingsGoal> updateGoal(
    SavingsGoal goal,
  ) {
    return _performMutation(() {
      return _repository.updateGoal(goal);
    });
  }

  // Alias yang lebih mudah dibaca pada halaman edit.
  Future<SavingsGoal> editGoal(
    SavingsGoal goal,
  ) {
    return updateGoal(goal);
  }

  // ==========================================================
  // TAMBAH TABUNGAN MANUAL
  // ==========================================================

  Future<SavingsGoal> addSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) {
    return _performMutation(() {
      return _repository.addSavings(
        goalId,
        amount,
        note: note,
        date: date,
      );
    });
  }

  // ==========================================================
  // AMBIL TABUNGAN MANUAL
  // ==========================================================

  Future<SavingsGoal> withdrawSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) {
    return _performMutation(() {
      return _repository.withdrawSavings(
        goalId,
        amount,
        note: note,
        date: date,
      );
    });
  }

  // ==========================================================
  // ARSIPKAN KANTONG
  // ==========================================================

  Future<SavingsGoal> archiveGoal(
    String goalId,
  ) {
    return _performMutation(() {
      return _repository.archiveGoal(goalId);
    });
  }

  // ==========================================================
  // PULIHKAN KANTONG
  // ==========================================================

  Future<SavingsGoal> restoreGoal(
    String goalId,
  ) {
    return _performMutation(() {
      return _repository.restoreGoal(goalId);
    });
  }

  // ==========================================================
  // HAPUS KANTONG
  // ==========================================================

  Future<bool> deleteGoal(
    String goalId,
  ) {
    return _performMutation(() {
      return _repository.deleteGoal(goalId);
    });
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _isDisposed = true;

    // Membatalkan penerapan hasil load yang masih berjalan.
    _loadRequestId++;

    _historyCache.clear();
    _loadingHistoryIds.clear();

    super.dispose();
  }
}