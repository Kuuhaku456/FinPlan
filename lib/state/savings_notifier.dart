import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/savings_repository.dart';
import '../models/savings_goal.dart';
import 'savings_controller.dart';

// =====================================================
// FINPLAN - SAVINGS RIVERPOD
// =====================================================

// Menghubungkan Riverpod dengan SavingsController lama.
//
// Data kantong tabungan tetap menggunakan repository
// dan penyimpanan lokal yang sudah tersedia.

final legacySavingsControllerProvider =
    Provider<SavingsController>(
  (ref) => throw StateError(
    'SavingsController belum diinisialisasi.',
  ),
);

// =====================================================
// SAVINGS STATE
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

  // =================================================
  // GETTERS
  // =================================================

  int get totalSaved => summary.totalSaved;

  int get totalTarget => summary.totalTarget;

  int get remainingTarget => summary.remainingTarget;

  double get progress => summary.progress;

  // =================================================
  // MEMBACA DATA DARI CONTROLLER LAMA
  // =================================================

  factory SavingsViewState.fromController(
    SavingsController controller,
  ) {
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
}

// =====================================================
// SAVINGS PROVIDER
// =====================================================

final savingsStateProvider =
    NotifierProvider<SavingsNotifier, SavingsViewState>(
  SavingsNotifier.new,
);

// =====================================================
// SAVINGS NOTIFIER
// =====================================================

class SavingsNotifier extends Notifier<SavingsViewState> {
  SavingsController get _controller =>
      ref.read(legacySavingsControllerProvider);

  // =================================================
  // INITIALIZATION
  // =================================================

  @override
  SavingsViewState build() {
    final controller = ref.watch(
      legacySavingsControllerProvider,
    );

    void syncState() {
      state = SavingsViewState.fromController(
        controller,
      );
    }

    controller.addListener(syncState);

    ref.onDispose(() {
      controller.removeListener(syncState);
    });

    return SavingsViewState.fromController(
      controller,
    );
  }

  // =================================================
  // LOAD SAVINGS GOALS
  // =================================================

  Future<void> loadGoals({
    bool showLoading = true,
  }) {
    return _controller.loadGoals(
      showLoading: showLoading,
    );
  }

  // =================================================
  // REFRESH
  // =================================================

  Future<void> refresh() {
    return _controller.refresh();
  }

  // =================================================
  // GET SAVINGS GOAL
  // =================================================

  SavingsGoal? goalById(String goalId) {
    return _controller.goalById(goalId);
  }

  // =================================================
  // SAVINGS MOVEMENT HISTORY
  // =================================================

  List<SavingsMovement> historyForGoal(
    String goalId,
  ) {
    return _controller.historyForGoal(goalId);
  }

  bool isLoadingHistory(String goalId) {
    return _controller.isLoadingHistory(goalId);
  }

  Future<List<SavingsMovement>> loadMovementHistory(
    String goalId,
  ) {
    return _controller.loadMovementHistory(goalId);
  }

  // =================================================
  // CREATE SAVINGS GOAL
  // =================================================

  Future<SavingsGoal> createGoal(
    SavingsGoal goal,
  ) {
    return _controller.createGoal(goal);
  }

  // =================================================
  // SAVE SAVINGS GOAL
  // =================================================

  Future<SavingsGoal> saveGoal(
    SavingsGoal goal,
  ) {
    return _controller.saveGoal(goal);
  }

  // =================================================
  // UPDATE SAVINGS GOAL
  // =================================================

  Future<SavingsGoal> updateGoal(
    SavingsGoal goal,
  ) {
    return _controller.updateGoal(goal);
  }

  // =================================================
  // ADD SAVINGS
  // =================================================

  Future<SavingsGoal> addSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) {
    return _controller.addSavings(
      goalId,
      amount,
      note: note,
      date: date,
    );
  }

  // =================================================
  // WITHDRAW SAVINGS
  // =================================================

  Future<SavingsGoal> withdrawSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) {
    return _controller.withdrawSavings(
      goalId,
      amount,
      note: note,
      date: date,
    );
  }

  // =================================================
  // ARCHIVE SAVINGS GOAL
  // =================================================

  Future<SavingsGoal> archiveGoal(
    String goalId,
  ) {
    return _controller.archiveGoal(goalId);
  }

  // =================================================
  // RESTORE SAVINGS GOAL
  // =================================================

  Future<SavingsGoal> restoreGoal(
    String goalId,
  ) {
    return _controller.restoreGoal(goalId);
  }

  // =================================================
  // DELETE SAVINGS GOAL
  // =================================================

  Future<bool> deleteGoal(
    String goalId,
  ) {
    return _controller.deleteGoal(goalId);
  }

  // =================================================
  // CLEAR ERROR
  // =================================================

  void clearError() {
    _controller.clearError();
  }
}