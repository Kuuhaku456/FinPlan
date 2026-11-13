import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/savings_repository.dart';
import '../models/savings_goal.dart';

import 'savings_controller.dart';
import 'savings_riverpod_v2.dart';

// =====================================================
// FINPLAN - SAVINGS RIVERPOD BRIDGE
// =====================================================
//
// Mode lama:
// UI -> SavingsNotifier -> SavingsController
//
// Mode baru:
// UI -> SavingsNotifier -> SavingsV2Notifier
//                       -> SavingsRepository
//
// Jalankan mode baru menggunakan:
// flutter run --dart-define=FINPLAN_SAVINGS_V2=true
//
// Tanpa flag, mode lama tetap digunakan.
// =====================================================

// =====================================================
// MODE
// =====================================================

final savingsV2ModeProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('FINPLAN_SAVINGS_V2', defaultValue: false);
});

// =====================================================
// LEGACY CONTROLLER
// =====================================================

final legacySavingsControllerProvider = Provider<SavingsController>((ref) {
  throw StateError('SavingsController belum diinisialisasi.');
});

// =====================================================
// VIEW STATE
// =====================================================

class SavingsViewState {
  const SavingsViewState({
    required this.allGoals,
    required this.activeGoals,
    required this.archivedGoals,
    required this.summary,
    required this.isLoading,
    required this.hasLoaded,
    required this.isSaving,
    required this.error,
  });

  final List<SavingsGoal> allGoals;
  final List<SavingsGoal> activeGoals;
  final List<SavingsGoal> archivedGoals;

  final SavingsSummary summary;

  final bool isLoading;
  final bool hasLoaded;
  final bool isSaving;

  final String? error;

  // ===================================================
  // SUMMARY
  // ===================================================

  int get totalSaved => summary.totalSaved;
  int get totalTarget => summary.totalTarget;
  int get remainingTarget => summary.remainingTarget;

  double get progress => summary.progress;
  double get progressPercent => summary.progressPercent;

  bool get hasError => error != null;

  // ===================================================
  // LEGACY STATE
  // ===================================================

  factory SavingsViewState.fromController(SavingsController controller) {
    return SavingsViewState(
      allGoals: controller.allGoals,
      activeGoals: controller.activeGoals,
      archivedGoals: controller.archivedGoals,
      summary: controller.summary,
      isLoading: controller.isLoading,
      hasLoaded: controller.hasLoaded,
      isSaving: controller.isSaving,
      error: controller.error,
    );
  }

  // ===================================================
  // RIVERPOD V2 STATE
  // ===================================================

  factory SavingsViewState.fromV2(SavingsV2State value) {
    return SavingsViewState(
      allGoals: value.allGoals,
      activeGoals: value.activeGoals,
      archivedGoals: value.archivedGoals,
      summary: value.summary,
      isLoading: value.isLoading,
      hasLoaded: value.hasLoaded,
      isSaving: value.isSaving,
      error: value.error,
    );
  }
}

// =====================================================
// MAIN PROVIDER
// =====================================================

final savingsStateProvider =
    NotifierProvider<SavingsNotifier, SavingsViewState>(SavingsNotifier.new);

// =====================================================
// SAVINGS NOTIFIER
// =====================================================

class SavingsNotifier extends Notifier<SavingsViewState> {
  bool get _useV2 {
    return ref.read(savingsV2ModeProvider);
  }

  SavingsController get _legacy {
    return ref.read(legacySavingsControllerProvider);
  }

  SavingsV2Notifier get _v2 {
    return ref.read(savingsV2Provider.notifier);
  }

  // ===================================================
  // BUILD
  // ===================================================

  @override
  SavingsViewState build() {
    final useV2 = ref.watch(savingsV2ModeProvider);

    // ================================================
    // MODE RIVERPOD V2
    // ================================================

    if (useV2) {
      final savings = ref.watch(savingsV2Provider);

      return SavingsViewState.fromV2(savings);
    }

    // ================================================
    // MODE LEGACY
    // ================================================

    final controller = ref.watch(legacySavingsControllerProvider);

    void syncState() {
      if (!ref.mounted) return;

      state = SavingsViewState.fromController(controller);
    }

    controller.addListener(syncState);

    ref.onDispose(() {
      controller.removeListener(syncState);
    });

    return SavingsViewState.fromController(controller);
  }

  // ===================================================
  // LOAD
  // ===================================================

  Future<void> loadGoals({bool showLoading = true}) {
    if (_useV2) {
      return _v2.loadGoals(showLoading: showLoading);
    }

    return _legacy.loadGoals(showLoading: showLoading);
  }

  // ===================================================
  // REFRESH
  // ===================================================

  Future<void> refresh() {
    return _useV2 ? _v2.refresh() : _legacy.refresh();
  }

  // ===================================================
  // GET GOAL
  // ===================================================

  SavingsGoal? goalById(String goalId) {
    return _useV2 ? _v2.goalById(goalId) : _legacy.goalById(goalId);
  }

  // ===================================================
  // HISTORY
  // ===================================================

  List<SavingsMovement> historyForGoal(String goalId) {
    return _useV2 ? _v2.historyForGoal(goalId) : _legacy.historyForGoal(goalId);
  }

  bool isLoadingHistory(String goalId) {
    return _useV2
        ? _v2.isLoadingHistory(goalId)
        : _legacy.isLoadingHistory(goalId);
  }

  Future<List<SavingsMovement>> loadMovementHistory(String goalId) {
    return _useV2
        ? _v2.loadMovementHistory(goalId)
        : _legacy.loadMovementHistory(goalId);
  }

  // ===================================================
  // CREATE GOAL
  // ===================================================

  Future<SavingsGoal> createGoal(SavingsGoal goal) {
    return _useV2 ? _v2.createGoal(goal) : _legacy.createGoal(goal);
  }

  // ===================================================
  // SAVE GOAL
  // ===================================================

  Future<SavingsGoal> saveGoal(SavingsGoal goal) {
    return _useV2 ? _v2.saveGoal(goal) : _legacy.saveGoal(goal);
  }

  // ===================================================
  // UPDATE GOAL
  // ===================================================

  Future<SavingsGoal> updateGoal(SavingsGoal goal) {
    return _useV2 ? _v2.updateGoal(goal) : _legacy.updateGoal(goal);
  }

  // ===================================================
  // ADD SAVINGS
  // ===================================================

  Future<SavingsGoal> addSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) {
    if (_useV2) {
      return _v2.addSavings(goalId, amount, note: note, date: date);
    }

    return _legacy.addSavings(goalId, amount, note: note, date: date);
  }

  // ===================================================
  // WITHDRAW SAVINGS
  // ===================================================

  Future<SavingsGoal> withdrawSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) {
    if (_useV2) {
      return _v2.withdrawSavings(goalId, amount, note: note, date: date);
    }

    return _legacy.withdrawSavings(goalId, amount, note: note, date: date);
  }

  // ===================================================
  // ARCHIVE
  // ===================================================

  Future<SavingsGoal> archiveGoal(String goalId) {
    return _useV2 ? _v2.archiveGoal(goalId) : _legacy.archiveGoal(goalId);
  }

  // ===================================================
  // RESTORE
  // ===================================================

  Future<SavingsGoal> restoreGoal(String goalId) {
    return _useV2 ? _v2.restoreGoal(goalId) : _legacy.restoreGoal(goalId);
  }

  // ===================================================
  // DELETE
  // ===================================================

  Future<bool> deleteGoal(String goalId) {
    return _useV2 ? _v2.deleteGoal(goalId) : _legacy.deleteGoal(goalId);
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
