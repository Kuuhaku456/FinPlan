import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celeng_id/data/savings_repository.dart';
import 'package:celeng_id/models/savings_goal.dart';
import 'package:celeng_id/state/savings_controller.dart';
import 'package:celeng_id/state/savings_notifier.dart';

// ======================================================
// FINPLAN - SAVINGS LIFECYCLE INTEGRATION TEST
// ======================================================
//
// Menguji alur Kantong Tabungan melalui:
// SavingsNotifier -> SavingsController -> SavingsGoal
//
// Repository pengujian menggunakan memori.
// Data tabungan asli pengguna tidak disentuh.
// ======================================================

// Repository sementara khusus testing.
class _MemorySavingsRepository extends SavingsRepository {
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
    return _goals.values
        .where((goal) => includeArchived || !goal.isArchived)
        .toList();
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
  Future<SavingsGoal> addSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) async {
    final current = _requireGoal(goalId);

    final updated = current.addSavings(amount, note: note, date: date);

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
    final current = _requireGoal(goalId);

    final updated = current.withdrawSavings(amount, note: note, date: date);

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
  Future<List<SavingsMovement>> getMovementHistory(String goalId) async {
    final history = [..._requireGoal(goalId).movements];

    history.sort((a, b) => b.date.compareTo(a.date));

    return history;
  }
}

// Contoh kantong tabungan.
SavingsGoal _createGoal({
  String id = 'goal-nikah',
  String name = 'Dana Pernikahan',
  int targetAmount = 10000000,
  int savedAmount = 0,
}) {
  return SavingsGoal(
    id: id,
    name: name,
    emoji: '💍',
    description: 'Persiapan pernikahan',
    targetAmount: targetAmount,
    savedAmount: savedAmount,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemorySavingsRepository repository;
  late SavingsController controller;
  late ProviderContainer container;

  setUp(() {
    repository = _MemorySavingsRepository();

    controller = SavingsController(repository);

    container = ProviderContainer(
      overrides: [
        legacySavingsControllerProvider.overrideWithValue(controller),
      ],
    );

    // Aktifkan provider agar mendengarkan controller.
    container.read(savingsStateProvider);
  });

  tearDown(() {
    container.dispose();
    controller.dispose();
  });

  // ====================================================
  // TEST 1: MEMBUAT KANTONG BARU
  // ====================================================

  test('Membuat kantong tabungan memperbarui state', () async {
    final notifier = container.read(savingsStateProvider.notifier);

    await notifier.loadGoals();

    expect(container.read(savingsStateProvider).activeGoals, isEmpty);

    await notifier.createGoal(_createGoal());

    final state = container.read(savingsStateProvider);

    expect(state.activeGoals.length, 1);
    expect(state.totalSaved, 0);
    expect(state.totalTarget, 10000000);
    expect(state.remainingTarget, 10000000);
    expect(state.summary.activeGoals, 1);

    expect(state.activeGoals.first.name, 'Dana Pernikahan');
  });

  // ====================================================
  // TEST 2: SETORAN DAN PENARIKAN
  // ====================================================

  test('Setoran dan penarikan memperbarui saldo serta riwayat', () async {
    final notifier = container.read(savingsStateProvider.notifier);

    await notifier.createGoal(_createGoal());

    // Setoran pertama.
    await notifier.addSavings(
      'goal-nikah',
      2000000,
      note: 'Tabungan bulan pertama',
      date: DateTime(2026, 11, 9, 10),
    );

    var state = container.read(savingsStateProvider);

    expect(state.totalSaved, 2000000);
    expect(state.remainingTarget, 8000000);
    expect(state.activeGoals.first.progressPercent, 20);

    // Setoran kedua.
    await notifier.addSavings(
      'goal-nikah',
      1000000,
      note: 'Tambahan tabungan',
      date: DateTime(2026, 11, 10, 10),
    );

    state = container.read(savingsStateProvider);

    expect(state.totalSaved, 3000000);
    expect(state.activeGoals.first.progressPercent, 30);

    // Penarikan.
    await notifier.withdrawSavings(
      'goal-nikah',
      500000,
      note: 'Kebutuhan persiapan',
      date: DateTime(2026, 11, 11, 10),
    );

    state = container.read(savingsStateProvider);

    expect(state.totalSaved, 2500000);
    expect(state.remainingTarget, 7500000);
    expect(state.activeGoals.first.progressPercent, 25);

    // Periksa riwayat.
    final history = notifier.historyForGoal('goal-nikah');

    expect(history.length, 3);

    // Riwayat terbaru berupa penarikan.
    expect(history.first.type, SavingsMovementType.withdrawal);
    expect(history.first.amount, 500000);
    expect(history.first.signedAmount, -500000);

    // Riwayat paling lama berupa setoran pertama.
    expect(history.last.type, SavingsMovementType.deposit);
    expect(history.last.amount, 2000000);
    expect(history.last.signedAmount, 2000000);
  });

  // ====================================================
  // TEST 3: PENARIKAN MELEBIHI SALDO
  // ====================================================

  test('Penarikan melebihi saldo ditolak tanpa mengubah data', () async {
    final notifier = container.read(savingsStateProvider.notifier);

    await notifier.createGoal(_createGoal(savedAmount: 1000000));

    await expectLater(
      notifier.withdrawSavings('goal-nikah', 2000000),
      throwsA(isA<StateError>()),
    );

    final state = container.read(savingsStateProvider);

    expect(state.totalSaved, 1000000);
    expect(state.activeGoals.first.savedAmount, 1000000);
    expect(state.activeGoals.first.movements, isEmpty);
  });

  // ====================================================
  // TEST 4: ARSIP DAN RESTORE
  // ====================================================

  test('Arsip dan restore mempertahankan saldo tabungan', () async {
    final notifier = container.read(savingsStateProvider.notifier);

    await notifier.createGoal(_createGoal(savedAmount: 3000000));

    // Arsipkan kantong.
    await notifier.archiveGoal('goal-nikah');

    var state = container.read(savingsStateProvider);

    expect(state.activeGoals, isEmpty);
    expect(state.archivedGoals.length, 1);
    expect(state.totalSaved, 0);
    expect(state.summary.archivedGoals, 1);

    // Kantong arsip tidak boleh menerima setoran.
    await expectLater(
      notifier.addSavings('goal-nikah', 100000),
      throwsA(isA<StateError>()),
    );

    // Pulihkan kantong.
    await notifier.restoreGoal('goal-nikah');

    state = container.read(savingsStateProvider);

    expect(state.activeGoals.length, 1);
    expect(state.archivedGoals, isEmpty);
    expect(state.totalSaved, 3000000);
    expect(state.activeGoals.first.isArchived, isFalse);
  });

  // ====================================================
  // TEST 5: TARGET TERCAPAI
  // ====================================================

  test('Progres maksimal 100 persen meskipun saldo melebihi target', () {
    final goal = _createGoal(targetAmount: 1000000, savedAmount: 1500000);

    expect(goal.progress, 1.0);
    expect(goal.progressPercent, 100);
    expect(goal.remainingAmount, 0);
    expect(goal.isCompleted, isTrue);
  });

  // ====================================================
  // TEST 6: VALIDASI NOMINAL
  // ====================================================

  test('Nominal setoran dan penarikan harus positif', () {
    final goal = _createGoal(savedAmount: 500000);

    expect(() => goal.addSavings(0), throwsArgumentError);

    expect(() => goal.addSavings(-10000), throwsArgumentError);

    expect(() => goal.withdrawSavings(0), throwsArgumentError);

    expect(() => goal.withdrawSavings(-10000), throwsArgumentError);

    // Objek asli tidak berubah setelah operasi ditolak.
    expect(goal.savedAmount, 500000);
    expect(goal.movements, isEmpty);
  });

  // ====================================================
  // TEST 7: BACKUP DAN RESTORE JSON
  // ====================================================

  test('Data kantong dan riwayat tetap utuh setelah JSON restore', () {
    final original = _createGoal(
      savedAmount: 1000000,
    ).addSavings(250000, note: 'Setoran tambahan', date: DateTime(2026, 11, 9));

    // Simpan sebagai JSON.
    final json = original.toJsonString();

    // Baca kembali.
    final restored = SavingsGoal.fromJsonString(json);

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.emoji, original.emoji);
    expect(restored.targetAmount, 10000000);
    expect(restored.savedAmount, 1250000);

    expect(restored.movements.length, 1);
    expect(restored.movements.first.amount, 250000);
    expect(restored.movements.first.note, 'Setoran tambahan');

    expect(restored.progress, original.progress);
  });
}
