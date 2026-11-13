import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celeng_id/data/plan_repository.dart';
import 'package:celeng_id/models/finance_plan.dart';
import 'package:celeng_id/state/finance_plan_notifier.dart';
import 'package:celeng_id/state/finance_plan_riverpod_v2.dart';
import 'package:celeng_id/state/plan_controller.dart';

// =====================================================
// FINPLAN - FINANCE PLAN V2 UNIT TESTS
// =====================================================
//
// Fake repository:
// - Tidak membuka SharedPreferences asli
// - Tidak menyentuh data pengguna
// - Tidak memanggil constructor PlanRepository
// =====================================================

class _MemoryPlanRepository extends Fake implements PlanRepository {
  FinancePlan? stored;

  bool failOnLoad = false;
  bool failOnSave = false;
  bool failOnClear = false;

  int saveCount = 0;

  @override
  Future<FinancePlan?> loadPlan() async {
    if (failOnLoad) {
      throw StateError('Gagal membaca data.');
    }

    return stored;
  }

  @override
  Future<void> savePlan(FinancePlan plan) async {
    if (failOnSave) {
      throw StateError('Gagal menyimpan data.');
    }

    stored = plan;
    saveCount++;
  }

  @override
  Future<void> clearPlan() async {
    if (failOnClear) {
      throw StateError('Gagal menghapus data.');
    }

    stored = null;
  }
}

// =====================================================
// TEST SUITE
// =====================================================

void main() {
  late _MemoryPlanRepository repository;
  late ProviderContainer container;
  late FinancePlanV2Notifier notifier;

  setUp(() {
    repository = _MemoryPlanRepository();

    container = ProviderContainer(
      overrides: [
        financePlanRepositoryV2Provider.overrideWithValue(repository),
      ],
    );

    notifier = container.read(financePlanV2Provider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  // ===================================================
  // TEST 1 - INITIAL STATE
  // ===================================================

  test('State awal Finance Plan kosong', () {
    final state = container.read(financePlanV2Provider);

    expect(state.plan, isNull);
    expect(state.hasLoaded, isFalse);
    expect(state.isLoading, isFalse);
    expect(state.isSaving, isFalse);
    expect(state.hasError, isFalse);
  });

  // ===================================================
  // TEST 2 - LOAD EMPTY
  // ===================================================

  test('Memuat repository kosong', () async {
    await notifier.loadPlan();

    final state = container.read(financePlanV2Provider);

    expect(state.plan, isNull);
    expect(state.hasLoaded, isTrue);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
  });

  // ===================================================
  // TEST 3 - LOAD SAVED DATA
  // ===================================================

  test('Memuat rencana yang sudah tersimpan', () async {
    final plan = FinancePlan.defaults();

    repository.stored = plan;

    await notifier.loadPlan();

    final state = container.read(financePlanV2Provider);

    expect(state.plan, same(plan));
    expect(state.totalIncome, plan.totalMonthlyIncome);
    expect(state.totalExpenses, plan.expenses);
    expect(state.hasLoaded, isTrue);
  });

  // ===================================================
  // TEST 4 - SAVE
  // ===================================================

  test('Menyimpan dan memperbarui Finance Plan', () async {
    final plan = FinancePlan.defaults().copyWith(
      name: 'Pengguna FinPlan',
      actualIncome: 7000000,
      savings: 1500000,
      bufferPercent: 10,
    );

    await notifier.savePlan(plan);

    final state = container.read(financePlanV2Provider);

    expect(repository.stored, same(plan));
    expect(state.plan, same(plan));
    expect(state.totalIncome, 7000000);
    expect(state.totalSavings, 1500000);
    expect(state.buffer, plan.buffer);
    expect(state.remaining, plan.plannedDifference);
    expect(state.isSaving, isFalse);
    expect(state.hasLoaded, isTrue);
    expect(repository.saveCount, 1);
  });

  // ===================================================
  // TEST 5 - DETAILS PRESERVED
  // ===================================================

  test('Jadwal makan tidak hilang saat edit gaji', () async {
    final original = FinancePlan.defaults().copyWith(
      foodByWeekday: {
        1: 30000,
        2: 30000,
        3: 35000,
        4: 30000,
        5: 40000,
        6: 25000,
        7: 0,
      },
    );

    await notifier.savePlan(original);

    final edited = original.copyWith(actualIncome: 8000000);

    await notifier.savePlan(edited);

    final current = container.read(financePlanV2Provider).plan;

    expect(current, isNotNull);
    expect(current!.actualIncome, 8000000);
    expect(current.foodByWeekday[1], 30000);
    expect(current.foodByWeekday[7], 0);
    expect(current.foodByWeekday.length, 7);
    expect(repository.saveCount, 2);
  });

  // ===================================================
  // TEST 6 - CLEAR
  // ===================================================

  test('Reset menghapus hanya Finance Plan', () async {
    await notifier.savePlan(FinancePlan.defaults());

    await notifier.clearPlan();

    final state = container.read(financePlanV2Provider);

    expect(state.plan, isNull);
    expect(state.hasLoaded, isTrue);
    expect(state.totalIncome, 0);
    expect(repository.stored, isNull);
  });

  // ===================================================
  // TEST 7 - CONCURRENT OPERATIONS
  // ===================================================

  test('Simpan berurutan tidak saling menimpa', () async {
    final first = FinancePlan.defaults().copyWith(actualIncome: 5000000);

    final second = FinancePlan.defaults().copyWith(actualIncome: 6000000);

    final third = FinancePlan.defaults().copyWith(actualIncome: 7500000);

    await Future.wait([
      notifier.savePlan(first),
      notifier.savePlan(second),
      notifier.savePlan(third),
    ]);

    final state = container.read(financePlanV2Provider);

    expect(state.plan?.actualIncome, 7500000);
    expect(repository.stored?.actualIncome, 7500000);
    expect(repository.saveCount, 3);
    expect(state.isSaving, isFalse);
  });

  // ===================================================
  // TEST 8 - FAILED SAVE
  // ===================================================

  test('Gagal simpan tidak mengganti data lama', () async {
    final original = FinancePlan.defaults();

    await notifier.savePlan(original);

    repository.failOnSave = true;

    final changed = original.copyWith(actualIncome: 9000000);

    await expectLater(notifier.savePlan(changed), throwsStateError);

    final state = container.read(financePlanV2Provider);

    expect(state.plan, same(original));
    expect(repository.stored, same(original));
    expect(state.isSaving, isFalse);
    expect(state.hasError, isTrue);

    notifier.clearError();

    expect(container.read(financePlanV2Provider).error, isNull);
  });

  // ===================================================
  // TEST 9 - ERROR RECOVERY
  // ===================================================

  test('Bisa menyimpan setelah error sebelumnya', () async {
    repository.failOnSave = true;

    await expectLater(
      notifier.savePlan(FinancePlan.defaults()),
      throwsStateError,
    );

    repository.failOnSave = false;

    final updated = FinancePlan.defaults().copyWith(actualIncome: 8500000);

    await notifier.savePlan(updated);

    final state = container.read(financePlanV2Provider);

    expect(state.plan, same(updated));
    expect(state.error, isNull);
    expect(state.isSaving, isFalse);
  });

  // ===================================================
  // TEST 10 - RIVERPOD UI BRIDGE
  // ===================================================

  test('financePlanProvider terhubung dengan V2', () async {
    final original = FinancePlan.defaults();

    repository.stored = original;

    final legacy = PlanController(repository, original, ThemeMode.system);

    final uiContainer = ProviderContainer(
      overrides: [
        financePlanV2ModeProvider.overrideWithValue(true),
        financePlanRepositoryV2Provider.overrideWithValue(repository),
        legacyPlanControllerProvider.overrideWithValue(legacy),
      ],
    );

    addTearDown(() {
      uiContainer.dispose();
      legacy.dispose();
    });

    // Fallback startup tetap menampilkan plan lama.
    expect(uiContainer.read(financePlanProvider), same(original));

    final changed = original.copyWith(actualIncome: 9000000);

    await uiContainer.read(financePlanProvider.notifier).savePlan(changed);

    expect(uiContainer.read(financePlanProvider), same(changed));

    final summary = uiContainer.read(monthlyPlanSummaryProvider);

    expect(summary, isNotNull);
    expect(summary!.income, 9000000);
    expect(summary.needs, changed.expenses);
    expect(summary.savings, changed.savings);

    await uiContainer.read(financePlanProvider.notifier).clearPlan();

    expect(uiContainer.read(financePlanProvider), isNull);

    expect(uiContainer.read(monthlyPlanSummaryProvider), isNull);
  });
}