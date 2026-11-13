import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celeng_id/data/plan_repository.dart';
import 'package:celeng_id/models/finance_plan.dart';
import 'package:celeng_id/state/finance_plan_notifier.dart';
import 'package:celeng_id/state/plan_controller.dart';

// =====================================================
// FAKE REPOSITORY UNTUK UNIT TEST
// =====================================================

// Menggunakan implements agar constructor PlanRepository
// tidak dijalankan saat unit test.
//
// Dengan begitu, pengujian tidak memerlukan
// SharedPreferencesAsync dari perangkat asli.

class _MemoryPlanRepository implements PlanRepository {
  FinancePlan? stored;

  String theme = 'system';

  // =================================================
  // MEMBACA DATA RENCANA
  // =================================================

  @override
  Future<FinancePlan?> loadPlan() async {
    return stored;
  }

  // =================================================
  // MENYIMPAN DATA RENCANA
  // =================================================

  @override
  Future<void> savePlan(FinancePlan plan) async {
    stored = plan;
  }

  // =================================================
  // MENGHAPUS DATA RENCANA
  // =================================================

  @override
  Future<void> clearPlan() async {
    stored = null;
  }

  // =================================================
  // PENGATURAN TEMA SIMULASI
  // =================================================

  @override
  Future<bool> loadDarkMode() async {
    return theme == 'dark';
  }

  @override
  Future<String> loadThemePreference() async {
    return theme;
  }

  @override
  Future<void> saveThemePreference(String value) async {
    theme = value;
  }

  @override
  Future<void> saveDarkMode(bool enabled) async {
    theme = enabled ? 'dark' : 'light';
  }
}

// =====================================================
// FINPLAN - FINANCIAL PLANNER UNIT TEST
// =====================================================

void main() {
  test('Rencana keuangan tersimpan dan sinkron dengan Riverpod', () async {
    // ===============================================
    // TEST SETUP
    // ===============================================

    final repository = _MemoryPlanRepository();

    final original = FinancePlan.defaults();

    final legacy = PlanController(repository, original, ThemeMode.system);

    final container = ProviderContainer(
      overrides: [legacyPlanControllerProvider.overrideWithValue(legacy)],
    );

    // Membersihkan resource setelah pengujian.
    addTearDown(() {
      container.dispose();
      legacy.dispose();
    });

    // ===============================================
    // TEST 1 - MEMBACA DATA AWAL
    // ===============================================

    expect(container.read(financePlanProvider), same(original));

    // ===============================================
    // TEST 2 - MEMPERBARUI GAJI
    // ===============================================

    final changed = original.copyWith(
      actualIncome: original.actualIncome + 100000,
    );

    await container.read(financePlanProvider.notifier).savePlan(changed);

    expect(repository.stored, same(changed));

    expect(container.read(financePlanProvider), same(changed));

    // ===============================================
    // TEST 3 - RINGKASAN BULANAN
    // ===============================================

    final summary = container.read(monthlyPlanSummaryProvider);

    expect(summary, isNotNull);

    expect(summary!.income, changed.totalMonthlyIncome);

    expect(summary.needs, changed.expenses);

    expect(summary.remainingAfterPlan, changed.plannedDifference);

    // ===============================================
    // TEST 4 - RESET RENCANA KEUANGAN
    // ===============================================

    await container.read(financePlanProvider.notifier).clearPlan();

    expect(container.read(financePlanProvider), isNull);

    expect(container.read(monthlyPlanSummaryProvider), isNull);
  });
}
