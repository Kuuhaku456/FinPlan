import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celeng_id/data/savings_repository.dart';
import 'package:celeng_id/models/savings_goal.dart';
import 'package:celeng_id/state/savings_notifier.dart';
import 'package:celeng_id/state/savings_riverpod_v2.dart';

// =====================================================
// FINPLAN - SAVINGS V2 UNIT TEST
// =====================================================

// Fake tidak memanggil constructor SavingsRepository.
// SharedPreferences asli tidak digunakan.

class MemorySavingsRepository extends Fake implements SavingsRepository {
  final Map<String, SavingsGoal> _goals = {};

  SavingsGoal _requireGoal(String id) {
    final goal = _goals[id];

    if (goal == null) {
      throw StateError('Kantong tabungan tidak ditemukan.');
    }

    return goal;
  }

  @override
  Future<List<SavingsGoal>> getAllGoals({bool includeArchived = true}) async {
    final result = _goals.values.where((goal) {
      return includeArchived || !goal.isArchived;
    }).toList();

    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return List<SavingsGoal>.unmodifiable(result);
  }

  @override
  Future<SavingsGoal> createGoal(SavingsGoal goal) async {
    if (_goals.containsKey(goal.id)) {
      throw StateError('Kantong sudah ada.');
    }

    _goals[goal.id] = goal;
    return goal;
  }

  @override
  Future<SavingsGoal> saveGoal(SavingsGoal goal) async {
    if (!_goals.containsKey(goal.id)) {
      return createGoal(goal);
    }

    return updateGoal(goal);
  }

  @override
  Future<SavingsGoal> updateGoal(SavingsGoal goal) async {
    final old = _requireGoal(goal.id);

    // Saldo dan riwayat tidak boleh berubah
    // ketika hanya mengedit informasi kantong.
    final updated = old.copyWith(
      name: goal.name,
      emoji: goal.emoji,
      description: goal.description,
      targetAmount: goal.targetAmount,
      deadline: goal.deadline,
      updatedAt: DateTime.now(),
    );

    _goals[goal.id] = updated;

    return updated;
  }

  @override
  Future<SavingsGoal> addSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) async {
    final updated = _requireGoal(goalId)
        .addSavings(amount, note: note, date: date);

    _goals[goalId] = updated;
    return updated;
  }

  @override
  Future<SavingsGoal> withdrawSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) async {
    final updated = _requireGoal(goalId)
        .withdrawSavings(amount, note: note, date: date);

    _goals[goalId] = updated;
    return updated;
  }

  @override
  Future<SavingsGoal> archiveGoal(String goalId) async {
    final updated = _requireGoal(goalId).archive();

    _goals[goalId] = updated;

    return updated;
  }

  @override
  Future<SavingsGoal> restoreGoal(String goalId) async {
    final updated = _requireGoal(goalId).restore();

    _goals[goalId] = updated;

    return updated;
  }

  @override
  Future<bool> deleteGoal(String goalId) async {
    return _goals.remove(goalId) != null;
  }

  @override
  Future<List<SavingsMovement>> getMovementHistory(String goalId) async {
    final movements = [..._requireGoal(goalId).movements];

    movements.sort((a, b) => b.date.compareTo(a.date));

    return movements;
  }
}

// =====================================================
// TEST HELPER
// =====================================================

SavingsGoal createTestGoal({
  String id = 'goal-001',
  String name = 'Dana Masa Depan',
  int target = 2000000,
}) {
  return SavingsGoal(id: id, name: name, emoji: '🎯', targetAmount: target);
}

// =====================================================
// TEST SUITE
// =====================================================

void main() {
  late ProviderContainer container;
  late MemorySavingsRepository repository;
  late SavingsV2Notifier notifier;

  setUp(() {
    repository = MemorySavingsRepository();

    container = ProviderContainer(
      overrides: [
        savingsRepositoryV2Provider.overrideWithValue(repository),
        savingsV2ModeProvider.overrideWithValue(true),
      ],
    );

    notifier = container.read(savingsV2Provider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  // ===================================================
  // TEST 1
  // ===================================================

  test('State awal kosong', () {
    final state = container.read(savingsV2Provider);

    expect(state.allGoals, isEmpty);
    expect(state.totalSaved, 0);
    expect(state.totalTarget, 0);
    expect(state.isLoading, false);
    expect(state.hasLoaded, false);
  });

  // ===================================================
  // TEST 2
  // ===================================================

  test('Berhasil memuat kantong kosong', () async {
    await notifier.loadGoals();

    final state = container.read(savingsV2Provider);

    expect(state.hasLoaded, true);
    expect(state.allGoals, isEmpty);
    expect(state.error, isNull);
  });

  // ===================================================
  // TEST 3
  // ===================================================

  test('Membuat kantong memperbarui summary', () async {
    final goal = createTestGoal();

    await notifier.createGoal(goal);

    final state = container.read(savingsV2Provider);

    expect(state.allGoals, hasLength(1));
    expect(state.activeGoals, hasLength(1));
    expect(state.totalTarget, 2000000);
    expect(state.totalSaved, 0);
    expect(state.summary.activeGoals, 1);
  });

  // ===================================================
  // TEST 4
  // ===================================================

  test('Setor dan tarik tabungan', () async {
    final goal = createTestGoal();

    await notifier.createGoal(goal);

    await notifier.addSavings(
      goal.id,
      200000,
      note: 'Tabungan gaji',
      date: DateTime(2026, 11, 10),
    );

    await notifier.withdrawSavings(
      goal.id,
      50000,
      note: 'Kebutuhan mendesak',
      date: DateTime(2026, 11, 11),
    );

    final state = container.read(savingsV2Provider);

    expect(state.totalSaved, 150000);
    expect(state.goalById(goal.id)?.savedAmount, 150000);

    final history = state.historyForGoal(goal.id);

    expect(history, hasLength(2));
    expect(history.first.amount, 50000);
    expect(history.first.type, SavingsMovementType.withdrawal);
  });

  // ===================================================
  // TEST 5
  // ===================================================

  test('Edit target tidak menghapus saldo', () async {
    final goal = createTestGoal();

    await notifier.createGoal(goal);
    await notifier.addSavings(goal.id, 300000);

    final edited = goal.copyWith(
      name: 'Dana Pernikahan',
      targetAmount: 5000000,
    );

    await notifier.updateGoal(edited);

    final current = notifier.goalById(goal.id);

    expect(current?.name, 'Dana Pernikahan');
    expect(current?.targetAmount, 5000000);
    expect(current?.savedAmount, 300000);
    expect(current?.movements, hasLength(1));
  });

  // ===================================================
  // TEST 6
  // ===================================================

  test('Arsip dan pulihkan kantong', () async {
    final goal = createTestGoal();

    await notifier.createGoal(goal);

    await notifier.archiveGoal(goal.id);

    var state = container.read(savingsV2Provider);

    expect(state.activeGoals, isEmpty);
    expect(state.archivedGoals, hasLength(1));
    expect(state.summary.archivedGoals, 1);

    await notifier.restoreGoal(goal.id);

    state = container.read(savingsV2Provider);

    expect(state.activeGoals, hasLength(1));
    expect(state.archivedGoals, isEmpty);
  });

  // ===================================================
  // TEST 7
  // ===================================================

  test('Hapus kantong memperbarui summary', () async {
    final goal = createTestGoal();

    await notifier.createGoal(goal);

    final success = await notifier.deleteGoal(goal.id);

    expect(success, true);
    expect(container.read(savingsV2Provider).allGoals, isEmpty);
  });

  // ===================================================
  // TEST 8
  // ===================================================

  test('Penarikan melebihi saldo ditolak', () async {
    final goal = createTestGoal();

    await notifier.createGoal(goal);
    await notifier.addSavings(goal.id, 100000);

    await expectLater(
      notifier.withdrawSavings(goal.id, 200000),
      throwsStateError,
    );

    final state = container.read(savingsV2Provider);

    expect(state.totalSaved, 100000);
    expect(state.isSaving, false);
    expect(state.error, isNotNull);

    notifier.clearError();

    expect(container.read(savingsV2Provider).error, isNull);
  });

  // ===================================================
  // TEST 9
  // ===================================================

  test('Riwayat dapat dimuat dari repository', () async {
    final goal = createTestGoal();

    await notifier.createGoal(goal);
    await notifier.addSavings(goal.id, 100000, date: DateTime(2026, 11, 5));

    final history = await notifier.loadMovementHistory(goal.id);

    expect(history, hasLength(1));
    expect(history.first.amount, 100000);
    expect(notifier.isLoadingHistory(goal.id), false);
  });

  // ===================================================
  // TEST 10
  // ===================================================

  test('Provider UI memakai Riverpod V2', () async {
    final uiNotifier = container.read(savingsStateProvider.notifier);

    final goal = createTestGoal();

    await uiNotifier.createGoal(goal);

    var uiState = container.read(savingsStateProvider);

    expect(uiState.activeGoals, hasLength(1));
    expect(uiState.totalTarget, 2000000);

    await uiNotifier.addSavings(goal.id, 250000);

    uiState = container.read(savingsStateProvider);

    expect(uiState.totalSaved, 250000);
    expect(uiNotifier.goalById(goal.id)?.savedAmount, 250000);
  });

  // ===================================================
  // TEST 11
  // ===================================================

  test('Setoran berurutan tidak kehilangan data', () async {
    final goal = createTestGoal();

    await notifier.createGoal(goal);

    await Future.wait([
      notifier.addSavings(goal.id, 100000),
      notifier.addSavings(goal.id, 150000),
      notifier.addSavings(goal.id, 200000),
    ]);

    final state = container.read(savingsV2Provider);

    expect(state.totalSaved, 450000);
    expect(state.goalById(goal.id)?.movements, hasLength(3));
  });
}
