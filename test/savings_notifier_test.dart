import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/data/savings_repository.dart';
import '../lib/models/savings_goal.dart';
import '../lib/state/savings_controller.dart';
import '../lib/state/savings_notifier.dart';

// ============================================================
// FAKE REPOSITORY
// ============================================================
//
// Penyimpanan sementara di memori untuk keperluan testing.
// Tidak menggunakan SharedPreferences atau database asli.
//

class _MemorySavingsRepository extends SavingsRepository {
  final Map<String, SavingsGoal> _goals = {};

  // ==========================================================
  // HELPER
  // ==========================================================

  SavingsGoal _requireGoal(String goalId) {
    final goal = _goals[goalId];

    if (goal == null) {
      throw StateError(
        'Kantong tabungan tidak ditemukan.',
      );
    }

    return goal;
  }

  // ==========================================================
  // MEMUAT SEMUA KANTONG
  // ==========================================================

  @override
  Future<List<SavingsGoal>> getAllGoals({
    bool includeArchived = true,
  }) async {
    final goals = _goals.values.where((goal) {
      return includeArchived || !goal.isArchived;
    }).toList();

    goals.sort(
      (a, b) => b.updatedAt.compareTo(a.updatedAt),
    );

    return List<SavingsGoal>.unmodifiable(goals);
  }

  // ==========================================================
  // MEMBUAT KANTONG
  // ==========================================================

  @override
  Future<SavingsGoal> createGoal(
    SavingsGoal goal,
  ) async {
    if (_goals.containsKey(goal.id)) {
      throw StateError(
        'Kantong dengan ID tersebut sudah ada.',
      );
    }

    _goals[goal.id] = goal;

    return goal;
  }

  // ==========================================================
  // SIMPAN KANTONG
  // ==========================================================

  @override
  Future<SavingsGoal> saveGoal(
    SavingsGoal goal,
  ) async {
    if (!_goals.containsKey(goal.id)) {
      return createGoal(goal);
    }

    return updateGoal(goal);
  }

  // ==========================================================
  // EDIT INFORMASI KANTONG
  // ==========================================================

  @override
  Future<SavingsGoal> updateGoal(
    SavingsGoal editedGoal,
  ) async {
    final existing = _requireGoal(editedGoal.id);

    // Saldo, status arsip, dan riwayat lama dipertahankan.
    final updated = existing.copyWith(
      name: editedGoal.name,
      emoji: editedGoal.emoji,
      description: editedGoal.description,
      targetAmount: editedGoal.targetAmount,
      deadline: editedGoal.deadline,
      updatedAt: DateTime.now(),
    );

    _goals[updated.id] = updated;

    return updated;
  }

  // ==========================================================
  // TAMBAH UANG TABUNGAN
  // ==========================================================

  @override
  Future<SavingsGoal> addSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) async {
    final existing = _requireGoal(goalId);

    final updated = existing.addSavings(
      amount,
      note: note,
      date: date,
    );

    _goals[goalId] = updated;

    return updated;
  }

  // ==========================================================
  // AMBIL UANG TABUNGAN
  // ==========================================================

  @override
  Future<SavingsGoal> withdrawSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) async {
    final existing = _requireGoal(goalId);

    final updated = existing.withdrawSavings(
      amount,
      note: note,
      date: date,
    );

    _goals[goalId] = updated;

    return updated;
  }

  // ==========================================================
  // ARSIPKAN KANTONG
  // ==========================================================

  @override
  Future<SavingsGoal> archiveGoal(
    String goalId,
  ) async {
    final existing = _requireGoal(goalId);

    final archived = existing.archive();

    _goals[goalId] = archived;

    return archived;
  }

  // ==========================================================
  // PULIHKAN KANTONG
  // ==========================================================

  @override
  Future<SavingsGoal> restoreGoal(
    String goalId,
  ) async {
    final existing = _requireGoal(goalId);

    final restored = existing.restore();

    _goals[goalId] = restored;

    return restored;
  }

  // ==========================================================
  // HAPUS KANTONG
  // ==========================================================

  @override
  Future<bool> deleteGoal(
    String goalId,
  ) async {
    return _goals.remove(goalId) != null;
  }

  // ==========================================================
  // RIWAYAT TABUNGAN
  // ==========================================================

  @override
  Future<List<SavingsMovement>> getMovementHistory(
    String goalId,
  ) async {
    final goal = _requireGoal(goalId);

    final movements = <SavingsMovement>[
      ...goal.movements,
    ];

    movements.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return List<SavingsMovement>.unmodifiable(
      movements,
    );
  }
}

// ============================================================
// TEST HARNESS
// ============================================================
//
// Menyiapkan repository, controller, dan Riverpod container.
// Setiap test mendapatkan penyimpanan terpisah.
//

class _SavingsTestHarness {
  _SavingsTestHarness() {
    controller = SavingsController(repository);

    container = ProviderContainer(
      overrides: [
        legacySavingsControllerProvider.overrideWithValue(
          controller,
        ),
      ],
    );

    // Aktifkan provider dan listener ke SavingsController.
    container.read(savingsStateProvider);
  }

  final _MemorySavingsRepository repository =
      _MemorySavingsRepository();

  late final SavingsController controller;

  late final ProviderContainer container;

  SavingsNotifier get notifier {
    return container.read(
      savingsStateProvider.notifier,
    );
  }

  SavingsViewState get state {
    return container.read(
      savingsStateProvider,
    );
  }

  void dispose() {
    container.dispose();
    controller.dispose();
  }
}

// ============================================================
// HELPER MEMBUAT TEST HARNESS
// ============================================================

_SavingsTestHarness createHarness() {
  final harness = _SavingsTestHarness();

  addTearDown(harness.dispose);

  return harness;
}

// ============================================================
// HELPER MEMBUAT KANTONG
// ============================================================

SavingsGoal createTestGoal({
  String name = 'Dana Pernikahan',
  int targetAmount = 10000000,
  int initialAmount = 0,
}) {
  return SavingsGoal.create(
    name: name,
    targetAmount: targetAmount,
    initialAmount: initialAmount,
    emoji: '💍',
    description: 'Tabungan untuk masa depan.',
  );
}

// ============================================================
// UNIT TEST SAVINGS NOTIFIER
// ============================================================

void main() {
  group('SavingsNotifier - FinPlan', () {
    // ========================================================
    // TEST 1: STATE AWAL
    // ========================================================

    test('state awal kosong dan loadGoals berhasil', () async {
      final harness = createHarness();

      expect(harness.state.allGoals, isEmpty);
      expect(harness.state.activeGoals, isEmpty);
      expect(harness.state.totalSaved, 0);
      expect(harness.state.totalTarget, 0);
      expect(harness.state.hasLoaded, isFalse);

      await harness.notifier.loadGoals();

      expect(harness.state.hasLoaded, isTrue);
      expect(harness.state.isLoading, isFalse);
      expect(harness.state.error, isNull);
    });

    // ========================================================
    // TEST 2: MEMBUAT KANTONG BARU
    // ========================================================

    test('berhasil membuat kantong tabungan', () async {
      final harness = createHarness();

      final goal = createTestGoal(
        name: 'Dana Pernikahan',
        targetAmount: 10000000,
      );

      await harness.notifier.createGoal(goal);

      final state = harness.state;

      expect(state.activeGoals, hasLength(1));
      expect(state.allGoals, hasLength(1));

      expect(
        state.activeGoals.first.name,
        'Dana Pernikahan',
      );

      expect(state.totalSaved, 0);
      expect(state.totalTarget, 10000000);

      expect(state.summary.activeGoals, 1);
      expect(state.summary.archivedGoals, 0);

      expect(
        harness.notifier.goalById(goal.id)?.id,
        goal.id,
      );
    });

    // ========================================================
    // TEST 3: SALDO AWAL
    // ========================================================

    test('saldo awal ikut dihitung dalam ringkasan', () async {
      final harness = createHarness();

      final goal = createTestGoal(
        name: 'Dana Darurat',
        targetAmount: 5000000,
        initialAmount: 1000000,
      );

      await harness.notifier.createGoal(goal);

      final savedGoal = harness.notifier.goalById(goal.id);

      expect(savedGoal, isNotNull);
      expect(savedGoal!.savedAmount, 1000000);

      expect(harness.state.totalSaved, 1000000);
      expect(harness.state.totalTarget, 5000000);

      expect(harness.state.progress, 0.2);
      expect(harness.state.remainingTarget, 4000000);
    });

    // ========================================================
    // TEST 4: TAMBAH TABUNGAN
    // ========================================================

    test('berhasil menambahkan uang tabungan', () async {
      final harness = createHarness();

      final goal = createTestGoal();

      await harness.notifier.createGoal(goal);

      await harness.notifier.addSavings(
        goal.id,
        500000,
        note: 'Setoran dari gaji',
        date: DateTime(2026, 11, 1),
      );

      final updatedGoal = harness.notifier.goalById(
        goal.id,
      );

      expect(updatedGoal, isNotNull);
      expect(updatedGoal!.savedAmount, 500000);

      expect(harness.state.totalSaved, 500000);
      expect(harness.state.remainingTarget, 9500000);

      expect(updatedGoal.movements, hasLength(1));

      expect(
        updatedGoal.movements.first.type,
        SavingsMovementType.deposit,
      );

      expect(
        updatedGoal.movements.first.note,
        'Setoran dari gaji',
      );
    });

    // ========================================================
    // TEST 5: AMBIL TABUNGAN
    // ========================================================

    test('berhasil mengambil uang tabungan', () async {
      final harness = createHarness();

      final goal = createTestGoal(
        initialAmount: 1000000,
      );

      await harness.notifier.createGoal(goal);

      await harness.notifier.withdrawSavings(
        goal.id,
        300000,
        note: 'Kebutuhan mendadak',
        date: DateTime(2026, 11, 2),
      );

      final updatedGoal = harness.notifier.goalById(
        goal.id,
      );

      expect(updatedGoal, isNotNull);
      expect(updatedGoal!.savedAmount, 700000);

      expect(harness.state.totalSaved, 700000);

      expect(updatedGoal.movements, hasLength(1));

      expect(
        updatedGoal.movements.first.type,
        SavingsMovementType.withdrawal,
      );

      expect(
        updatedGoal.movements.first.amount,
        300000,
      );
    });

    // ========================================================
    // TEST 6: TOLAK SALDO TIDAK CUKUP
    // ========================================================

    test(
      'menolak pengambilan yang melebihi saldo',
      () async {
        final harness = createHarness();

        final goal = createTestGoal(
          initialAmount: 100000,
        );

        await harness.notifier.createGoal(goal);

        await expectLater(
          harness.notifier.withdrawSavings(
            goal.id,
            200000,
          ),
          throwsA(isA<StateError>()),
        );

        final savedGoal = harness.notifier.goalById(
          goal.id,
        );

        // Tidak boleh ada perubahan saldo.
        expect(savedGoal!.savedAmount, 100000);

        // Tidak boleh membuat riwayat penarikan gagal.
        expect(savedGoal.movements, isEmpty);

        expect(
          harness.state.error,
          contains('melebihi saldo'),
        );

        harness.notifier.clearError();

        expect(harness.state.error, isNull);
      },
    );

    // ========================================================
    // TEST 7: EDIT INFORMASI KANTONG
    // ========================================================

    test(
      'edit kantong mempertahankan saldo dan riwayat',
      () async {
        final harness = createHarness();

        final goal = createTestGoal(
          initialAmount: 500000,
        );

        await harness.notifier.createGoal(goal);

        await harness.notifier.addSavings(
          goal.id,
          250000,
          note: 'Bonus pekerjaan',
        );

        final editedGoal = goal.copyWith(
          name: 'Tabungan Menikah',
          description: 'Target persiapan pernikahan.',
          targetAmount: 15000000,
          emoji: '❤️',
          // Nilai berikut sengaja berbeda untuk menguji
          // bahwa operasi edit tidak mengganti saldo.
          savedAmount: 0,
          movements: const [],
        );

        await harness.notifier.updateGoal(
          editedGoal,
        );

        final updated = harness.notifier.goalById(
          goal.id,
        );

        expect(updated, isNotNull);

        expect(updated!.name, 'Tabungan Menikah');
        expect(updated.targetAmount, 15000000);
        expect(updated.emoji, '❤️');

        // Saldo lama tetap tersedia.
        expect(updated.savedAmount, 750000);

        // Riwayat tidak hilang.
        expect(updated.movements, hasLength(1));

        expect(
          updated.movements.first.note,
          'Bonus pekerjaan',
        );

        expect(harness.state.totalSaved, 750000);
        expect(harness.state.totalTarget, 15000000);
      },
    );

    // ========================================================
    // TEST 8: ARSIP KANTONG
    // ========================================================

    test('kantong dapat diarsipkan', () async {
      final harness = createHarness();

      final goal = createTestGoal(
        initialAmount: 1000000,
      );

      await harness.notifier.createGoal(goal);

      await harness.notifier.archiveGoal(
        goal.id,
      );

      expect(harness.state.activeGoals, isEmpty);
      expect(harness.state.archivedGoals, hasLength(1));

      expect(
        harness.notifier.goalById(goal.id)?.isArchived,
        isTrue,
      );

      // Kantong arsip tidak masuk total aktif.
      expect(harness.state.totalSaved, 0);
      expect(harness.state.totalTarget, 0);

      expect(harness.state.summary.archivedGoals, 1);

      // Tidak boleh menabung pada kantong arsip.
      await expectLater(
        harness.notifier.addSavings(
          goal.id,
          100000,
        ),
        throwsA(isA<StateError>()),
      );
    });

    // ========================================================
    // TEST 9: RESTORE KANTONG
    // ========================================================

    test('kantong arsip bisa dipulihkan', () async {
      final harness = createHarness();

      final goal = createTestGoal(
        initialAmount: 2000000,
      );

      await harness.notifier.createGoal(goal);

      await harness.notifier.archiveGoal(goal.id);

      expect(harness.state.activeGoals, isEmpty);

      await harness.notifier.restoreGoal(goal.id);

      expect(harness.state.activeGoals, hasLength(1));
      expect(harness.state.archivedGoals, isEmpty);

      expect(
        harness.notifier.goalById(goal.id)?.isArchived,
        isFalse,
      );

      // Saldo tetap utuh setelah restore.
      expect(harness.state.totalSaved, 2000000);

      expect(harness.state.summary.archivedGoals, 0);
    });

    // ========================================================
    // TEST 10: HAPUS KANTONG
    // ========================================================

    test('berhasil menghapus kantong', () async {
      final harness = createHarness();

      final goal = createTestGoal(
        initialAmount: 500000,
      );

      await harness.notifier.createGoal(goal);

      expect(harness.state.allGoals, hasLength(1));

      final deleted = await harness.notifier.deleteGoal(
        goal.id,
      );

      expect(deleted, isTrue);

      expect(harness.state.allGoals, isEmpty);
      expect(harness.state.activeGoals, isEmpty);

      expect(harness.state.totalSaved, 0);
      expect(harness.state.totalTarget, 0);

      expect(harness.notifier.goalById(goal.id), isNull);

      // Menghapus ID yang sudah tidak ada mengembalikan false.
      final deletedAgain =
          await harness.notifier.deleteGoal(goal.id);

      expect(deletedAgain, isFalse);
    });

    // ========================================================
    // TEST 11: RIWAYAT TRANSAKSI TABUNGAN
    // ========================================================

    test(
      'riwayat tabungan diurutkan dari terbaru',
      () async {
        final harness = createHarness();

        final goal = createTestGoal();

        await harness.notifier.createGoal(goal);

        await harness.notifier.addSavings(
          goal.id,
          500000,
          note: 'Setoran pertama',
          date: DateTime(2026, 11, 1),
        );

        await harness.notifier.addSavings(
          goal.id,
          300000,
          note: 'Setoran kedua',
          date: DateTime(2026, 11, 2),
        );

        await harness.notifier.withdrawSavings(
          goal.id,
          100000,
          note: 'Pengambilan',
          date: DateTime(2026, 11, 3),
        );

        final history =
            await harness.notifier.loadMovementHistory(
          goal.id,
        );

        expect(history, hasLength(3));

        // Riwayat terbaru ditampilkan dahulu.
        expect(history[0].note, 'Pengambilan');
        expect(history[1].note, 'Setoran kedua');
        expect(history[2].note, 'Setoran pertama');

        expect(
          history[0].type,
          SavingsMovementType.withdrawal,
        );

        expect(
          history[1].type,
          SavingsMovementType.deposit,
        );

        expect(history[0].signedAmount, -100000);
        expect(history[1].signedAmount, 300000);

        // Cache riwayat notifier juga diperbarui.
        final cachedHistory =
            harness.notifier.historyForGoal(
          goal.id,
        );

        expect(cachedHistory, hasLength(3));
        expect(cachedHistory.first.note, 'Pengambilan');

        // Perhitungan saldo akhir.
        expect(harness.state.totalSaved, 700000);
      },
    );

    // ========================================================
    // TEST 12: BEBERAPA KANTONG
    // ========================================================

    test(
      'ringkasan menghitung seluruh kantong aktif',
      () async {
        final harness = createHarness();

        final wedding = createTestGoal(
          name: 'Pernikahan',
          targetAmount: 10000000,
          initialAmount: 3000000,
        );

        final emergency = createTestGoal(
          name: 'Dana Darurat',
          targetAmount: 5000000,
          initialAmount: 2000000,
        );

        await harness.notifier.createGoal(wedding);
        await harness.notifier.createGoal(emergency);

        expect(harness.state.activeGoals, hasLength(2));

        expect(harness.state.totalSaved, 5000000);
        expect(harness.state.totalTarget, 15000000);
        expect(harness.state.remainingTarget, 10000000);

        expect(harness.state.summary.activeGoals, 2);
        expect(harness.state.summary.completedGoals, 0);

        await harness.notifier.archiveGoal(emergency.id);

        // Ringkasan hanya menghitung kantong aktif.
        expect(harness.state.totalSaved, 3000000);
        expect(harness.state.totalTarget, 10000000);

        expect(harness.state.summary.activeGoals, 1);
        expect(harness.state.summary.archivedGoals, 1);
      },
    );

    // ========================================================
    // TEST 13: PROVIDER TERPISAH
    // ========================================================

    test(
      'dua sesi pengujian tidak berbagi data',
      () async {
        final first = createHarness();
        final second = createHarness();

        final goal = createTestGoal();

        await first.notifier.createGoal(goal);

        await second.notifier.loadGoals();

        expect(first.state.activeGoals, hasLength(1));

        expect(second.state.activeGoals, isEmpty);

        expect(second.state.totalSaved, 0);
      },
    );
  });
}