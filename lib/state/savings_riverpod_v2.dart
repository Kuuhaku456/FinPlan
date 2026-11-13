import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/savings_repository.dart';
import '../models/savings_goal.dart';

// =====================================================
// FINPLAN - SAVINGS RIVERPOD V2
// =====================================================
//
// Riverpod -> SavingsRepository -> SharedPreferences
//
// Tidak menggunakan SavingsController ataupun
// ChangeNotifier.
//
// Format data yang tersimpan tetap digunakan.
// =====================================================

final savingsRepositoryV2Provider = Provider<SavingsRepository>((ref) {
  return SavingsRepository();
});

// =====================================================
// STATE
// =====================================================

class SavingsV2State {
  const SavingsV2State({
    this.allGoals = const <SavingsGoal>[],
    this.summary = const SavingsSummary(
      totalSaved: 0,
      totalTarget: 0,
      activeGoals: 0,
      completedGoals: 0,
      archivedGoals: 0,
    ),
    this.historyCache = const {},
    this.loadingHistoryIds = const {},
    this.isLoading = false,
    this.hasLoaded = false,
    this.isSaving = false,
    this.error,
  });

  final List<SavingsGoal> allGoals;
  final SavingsSummary summary;

  final Map<String, List<SavingsMovement>> historyCache;
  final Set<String> loadingHistoryIds;

  final bool isLoading;
  final bool hasLoaded;
  final bool isSaving;
  final String? error;

  List<SavingsGoal> get activeGoals {
    return List<SavingsGoal>.unmodifiable(
      allGoals.where((goal) => !goal.isArchived),
    );
  }

  List<SavingsGoal> get archivedGoals {
    return List<SavingsGoal>.unmodifiable(
      allGoals.where((goal) => goal.isArchived),
    );
  }

  int get totalSaved => summary.totalSaved;
  int get totalTarget => summary.totalTarget;
  int get remainingTarget => summary.remainingTarget;

  double get progress => summary.progress;
  double get progressPercent => summary.progressPercent;

  bool get hasError => error != null;
  bool get isBusy => isLoading || isSaving;

  SavingsGoal? goalById(String id) {
    for (final goal in allGoals) {
      if (goal.id == id) return goal;
    }

    return null;
  }

  List<SavingsMovement> historyForGoal(String id) {
    return historyCache[id] ?? const <SavingsMovement>[];
  }

  bool isLoadingHistory(String id) {
    return loadingHistoryIds.contains(id);
  }

  SavingsV2State copyWith({
    List<SavingsGoal>? allGoals,
    SavingsSummary? summary,
    Map<String, List<SavingsMovement>>? historyCache,
    Set<String>? loadingHistoryIds,
    bool? isLoading,
    bool? hasLoaded,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return SavingsV2State(
      allGoals: allGoals == null
          ? this.allGoals
          : List<SavingsGoal>.unmodifiable(allGoals),
      summary: summary ?? this.summary,
      historyCache: historyCache == null
          ? this.historyCache
          : Map.unmodifiable(historyCache),
      loadingHistoryIds: loadingHistoryIds == null
          ? this.loadingHistoryIds
          : Set.unmodifiable(loadingHistoryIds),
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// =====================================================
// PROVIDER
// =====================================================

final savingsV2Provider = NotifierProvider<SavingsV2Notifier, SavingsV2State>(
  SavingsV2Notifier.new,
);

// =====================================================
// NOTIFIER
// =====================================================

class SavingsV2Notifier extends Notifier<SavingsV2State> {
  // Menjalankan operasi secara berurutan.
  // Ini mencegah refresh lama menimpa perubahan baru.

  Future<void> _operationQueue = Future<void>.value();

  SavingsRepository get _repository => ref.read(savingsRepositoryV2Provider);

  @override
  SavingsV2State build() {
    return const SavingsV2State();
  }

  // ===================================================
  // SERIAL OPERATION
  // ===================================================

  Future<T> _serialized<T>(Future<T> Function() operation) async {
    final previous = _operationQueue;
    final completed = Completer<void>();

    _operationQueue = completed.future;

    await previous;

    try {
      return await operation();
    } finally {
      completed.complete();
    }
  }

  // ===================================================
  // ERROR FORMAT
  // ===================================================

  String _errorMessage(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Data tabungan tidak valid.';
    }

    if (error is FormatException) {
      return error.message;
    }

    return 'Gagal memproses tabungan: $error';
  }

  // ===================================================
  // SUMMARY
  // ===================================================

  SavingsSummary _calculateSummary(List<SavingsGoal> goals) {
    var totalSaved = 0;
    var totalTarget = 0;
    var active = 0;
    var completed = 0;
    var archived = 0;

    for (final goal in goals) {
      if (goal.isArchived) {
        archived++;
        continue;
      }

      active++;
      totalSaved += goal.savedAmount;
      totalTarget += goal.targetAmount;

      if (goal.isCompleted) {
        completed++;
      }
    }

    return SavingsSummary(
      totalSaved: totalSaved,
      totalTarget: totalTarget,
      activeGoals: active,
      completedGoals: completed,
      archivedGoals: archived,
    );
  }

  // ===================================================
  // SORT HISTORY
  // ===================================================

  List<SavingsMovement> _sortedHistory(List<SavingsMovement> movements) {
    final sorted = [...movements];

    sorted.sort((a, b) => b.date.compareTo(a.date));

    return List<SavingsMovement>.unmodifiable(sorted);
  }

  // ===================================================
  // READ REPOSITORY - INTERNAL
  // ===================================================

  Future<void> _readLatestGoals() async {
    final goals = await _repository.getAllGoals(includeArchived: true);

    if (!ref.mounted) return;

    final cache = <String, List<SavingsMovement>>{};

    for (final goal in goals) {
      cache[goal.id] = _sortedHistory(goal.movements);
    }

    state = state.copyWith(
      allGoals: goals,
      summary: _calculateSummary(goals),
      historyCache: cache,
      loadingHistoryIds: <String>{},
      hasLoaded: true,
      clearError: true,
    );
  }

  // ===================================================
  // LOAD
  // ===================================================

  Future<void> loadGoals({bool showLoading = true}) {
    return _serialized(() async {
      if (!ref.mounted) return;

      state = state.copyWith(isLoading: showLoading, clearError: true);

      try {
        await _readLatestGoals();
      } catch (error) {
        if (ref.mounted) {
          state = state.copyWith(error: _errorMessage(error));
        }
      } finally {
        if (ref.mounted) {
          state = state.copyWith(isLoading: false);
        }
      }
    });
  }

  // ===================================================
  // REFRESH
  // ===================================================

  Future<void> refresh() {
    return loadGoals(showLoading: false);
  }

  // ===================================================
  // FIND GOAL
  // ===================================================

  SavingsGoal? goalById(String goalId) {
    return state.goalById(goalId);
  }

  // ===================================================
  // HISTORY CACHE
  // ===================================================

  List<SavingsMovement> historyForGoal(String goalId) {
    return state.historyForGoal(goalId);
  }

  bool isLoadingHistory(String goalId) {
    return state.isLoadingHistory(goalId);
  }

  // ===================================================
  // LOAD HISTORY
  // ===================================================

  Future<List<SavingsMovement>> loadMovementHistory(String goalId) {
    return _serialized(() async {
      if (!ref.mounted) {
        return <SavingsMovement>[];
      }

      state = state.copyWith(
        loadingHistoryIds: {...state.loadingHistoryIds, goalId},
        clearError: true,
      );

      try {
        final history = await _repository.getMovementHistory(goalId);

        final sorted = _sortedHistory(history);

        if (ref.mounted) {
          state = state.copyWith(
            historyCache: {...state.historyCache, goalId: sorted},
          );
        }

        return sorted;
      } catch (error) {
        if (ref.mounted) {
          state = state.copyWith(error: _errorMessage(error));
        }

        rethrow;
      } finally {
        if (ref.mounted) {
          final loading = {...state.loadingHistoryIds};

          loading.remove(goalId);

          state = state.copyWith(loadingHistoryIds: loading);
        }
      }
    });
  }

  // ===================================================
  // MUTATION HELPER
  // ===================================================

  Future<T> _performMutation<T>(Future<T> Function() operation) {
    return _serialized(() async {
      if (!ref.mounted) {
        throw StateError('Pengelola tabungan sudah ditutup.');
      }

      state = state.copyWith(isSaving: true, clearError: true);

      try {
        final result = await operation();

        // Refresh langsung dari repository.
        // Tidak memanggil loadGoals() karena operasi
        // sudah berada dalam antrean serial.

        await _readLatestGoals();

        return result;
      } catch (error) {
        if (ref.mounted) {
          state = state.copyWith(error: _errorMessage(error));
        }

        rethrow;
      } finally {
        if (ref.mounted) {
          state = state.copyWith(isSaving: false);
        }
      }
    });
  }

  // ===================================================
  // CREATE GOAL
  // ===================================================

  Future<SavingsGoal> createGoal(SavingsGoal goal) {
    return _performMutation(() => _repository.createGoal(goal));
  }

  // ===================================================
  // SAVE GOAL
  // ===================================================

  Future<SavingsGoal> saveGoal(SavingsGoal goal) {
    return _performMutation(() => _repository.saveGoal(goal));
  }

  // ===================================================
  // UPDATE GOAL
  // ===================================================

  Future<SavingsGoal> updateGoal(SavingsGoal goal) {
    return _performMutation(() => _repository.updateGoal(goal));
  }

  Future<SavingsGoal> editGoal(SavingsGoal goal) {
    return updateGoal(goal);
  }

  // ===================================================
  // DEPOSIT
  // ===================================================

  Future<SavingsGoal> addSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) {
    return _performMutation(
      () => _repository.addSavings(goalId, amount, note: note, date: date),
    );
  }

  // ===================================================
  // WITHDRAW
  // ===================================================

  Future<SavingsGoal> withdrawSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) {
    return _performMutation(
      () => _repository.withdrawSavings(goalId, amount, note: note, date: date),
    );
  }

  // ===================================================
  // ARCHIVE
  // ===================================================

  Future<SavingsGoal> archiveGoal(String goalId) {
    return _performMutation(() => _repository.archiveGoal(goalId));
  }

  // ===================================================
  // RESTORE
  // ===================================================

  Future<SavingsGoal> restoreGoal(String goalId) {
    return _performMutation(() => _repository.restoreGoal(goalId));
  }

  // ===================================================
  // DELETE
  // ===================================================

  Future<bool> deleteGoal(String goalId) {
    return _performMutation(() => _repository.deleteGoal(goalId));
  }

  // ===================================================
  // CLEAR ERROR
  // ===================================================

  void clearError() {
    if (!ref.mounted) return;

    state = state.copyWith(clearError: true);
  }
}
