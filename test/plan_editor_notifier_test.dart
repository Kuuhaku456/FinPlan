import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celeng_id/features/planner/providers/plan_editor_provider.dart';
import 'package:celeng_id/models/finance_plan.dart';

// =====================================================
// TEST HELPER
// =====================================================

/// Membuat sesi PlanEditor khusus pengujian.
///
/// Tidak membutuhkan SharedPreferences atau SQLite.
ProviderContainer createEditor({
  FinancePlan? initial,
  bool onboarding = false,
}) {
  final plan = initial ?? FinancePlan.defaults().copyWith(name: 'Filipus');

  final container = ProviderContainer(
    overrides: [
      planEditorConfigProvider.overrideWithValue(
        PlanEditorConfig(initial: plan, onboarding: onboarding),
      ),
    ],
  );

  addTearDown(container.dispose);

  return container;
}

// =====================================================
// NAVIGATION HELPER
// =====================================================

void moveToSummary(PlanEditorNotifier notifier) {
  for (var step = 0; step < 5; step++) {
    expect(notifier.nextStep(), isNull);
  }
}

// =====================================================
// TESTS
// =====================================================

void main() {
  group('PlanEditorNotifier', () {
    // =================================================
    // TEST 1 - INITIAL DATA
    // =================================================

    test('membaca data awal tanpa mengubah nominal rencana', () {
      final plan = FinancePlan.defaults().copyWith(
        name: 'Filipus',
        additionalIncomes: const [
          IncomeSource(name: 'Freelance', amount: 300000),
        ],
      );

      final container = createEditor(initial: plan);

      final draft = container.read(planEditorProvider);

      expect(draft.step, 0);
      expect(draft.name, 'Filipus');
      expect(draft.salary, plan.actualIncome);
      expect(draft.housing, plan.housing);

      expect(draft.additionalIncomes, hasLength(1));

      expect(draft.toFinancePlan().totalMonthlyIncome, plan.totalMonthlyIncome);
    });

    // =================================================
    // TEST 2 - NAVIGATION & VALIDATION
    // =================================================

    test('menolak nama kosong dan bisa maju serta kembali', () {
      final container = createEditor(initial: FinancePlan.defaults());

      final notifier = container.read(planEditorProvider.notifier);

      expect(notifier.nextStep(), 'Nama panggilan wajib diisi.');

      expect(container.read(planEditorProvider).step, 0);

      notifier.updateName('Filipus');

      expect(notifier.nextStep(), isNull);

      expect(container.read(planEditorProvider).step, 1);

      notifier.goBack();

      expect(container.read(planEditorProvider).step, 0);

      expect(container.read(planEditorProvider).name, 'Filipus');
    });

    // =================================================
    // TEST 3 - FOOD BUDGET
    // =================================================

    test('anggaran makan bisa disalin Senin-Jumat atau semua hari', () {
      final container = createEditor();

      final notifier = container.read(planEditorProvider.notifier);

      notifier.updateFoodDay(1, 35000);
      notifier.updateFoodDay(6, 25000);

      notifier.copyMondayFood(allDays: false);

      var draft = container.read(planEditorProvider);

      expect(draft.foodByDay[2], 35000);
      expect(draft.foodByDay[5], 35000);
      expect(draft.foodByDay[6], 25000);

      notifier.copyMondayFood(allDays: true);

      draft = container.read(planEditorProvider);

      expect(draft.foodByDay[6], 35000);
      expect(draft.foodByDay[7], 35000);

      expect(draft.toFinancePlan().weeklyFoodTotal, 245000);
    });

    // =================================================
    // TEST 4 - TRANSPORTATION
    // =================================================

    test('rute pergi dan pulang dihitung serta bisa dihapus', () {
      final container = createEditor();

      final notifier = container.read(planEditorProvider.notifier);

      // Perjalanan pergi: KRL

      notifier.addLeg(1, TravelDirection.outbound);

      final first = container
          .read(planEditorProvider)
          .routeFor(1)
          .outbound
          .first;

      notifier.updateLeg(1, TravelDirection.outbound, first.id, cost: 5000);

      // Perjalanan pergi: Gojek

      notifier.addLeg(1, TravelDirection.outbound);

      final second = container
          .read(planEditorProvider)
          .routeFor(1)
          .outbound
          .last;

      notifier.updateLeg(
        1,
        TravelDirection.outbound,
        second.id,
        mode: 'Gojek / Grab',
        cost: 10000,
      );

      // Perjalanan pulang: KRL

      notifier.addLeg(1, TravelDirection.inbound);

      final back = container.read(planEditorProvider).routeFor(1).inbound.first;

      notifier.updateLeg(1, TravelDirection.inbound, back.id, cost: 5000);

      // Total = 5000 + 10000 + 5000

      expect(container.read(planEditorProvider).dailyTransportTotal(1), 20000);

      expect(
        container.read(planEditorProvider).toFinancePlan().transportByWeekday,
        hasLength(1),
      );

      // Hapus Gojek

      notifier.removeLeg(1, TravelDirection.outbound, second.id);

      expect(container.read(planEditorProvider).dailyTransportTotal(1), 10000);
    });

    // =================================================
    // TEST 5 - CUSTOM TRANSPORT VALIDATION
    // =================================================

    test('transportasi custom wajib memiliki nama', () {
      final container = createEditor();

      final notifier = container.read(planEditorProvider.notifier);

      // Profil -> Makan
      expect(notifier.nextStep(), isNull);

      // Makan -> Transportasi
      expect(notifier.nextStep(), isNull);

      notifier.addLeg(1, TravelDirection.outbound);

      final id = container
          .read(planEditorProvider)
          .routeFor(1)
          .outbound
          .first
          .id;

      notifier.updateLeg(1, TravelDirection.outbound, id, mode: '');

      expect(notifier.nextStep(), 'Nama moda transportasi wajib diisi.');

      expect(container.read(planEditorProvider).step, 2);

      notifier.updateLeg(1, TravelDirection.outbound, id, mode: 'Shuttle');

      expect(notifier.nextStep(), isNull);

      expect(container.read(planEditorProvider).step, 3);
    });

    // =================================================
    // TEST 6 - ADDITIONAL INCOME & EXPENSES
    // =================================================

    test('pemasukan dan kebutuhan custom menggunakan frekuensi', () {
      final container = createEditor();

      final notifier = container.read(planEditorProvider.notifier);

      // Tambahkan pemasukan freelance

      notifier.addIncome();

      final incomeId = container
          .read(planEditorProvider)
          .additionalIncomes
          .first
          .id;

      notifier.updateIncome(
        incomeId,
        name: 'Freelance',
        amount: 300000,
        frequency: BudgetFrequency.weekly,
      );

      // Tambahkan biaya pendidikan

      notifier.addExpense();

      final expenseId = container
          .read(planEditorProvider)
          .customExpenses
          .first
          .id;

      notifier.updateExpense(
        expenseId,
        name: 'Pendidikan',
        amount: 1200000,
        frequency: BudgetFrequency.yearly,
      );

      final plan = container.read(planEditorProvider).toFinancePlan();

      expect(
        plan.additionalIncomes.single.monthlyAmount,
        monthlyEstimate(300000, BudgetFrequency.weekly),
      );

      expect(plan.monthlyCustomExpenses, 100000);

      // Hapus data tambahan

      notifier.removeIncome(incomeId);
      notifier.removeExpense(expenseId);

      final afterRemoval = container.read(planEditorProvider);

      expect(afterRemoval.additionalIncomes, isEmpty);

      expect(afterRemoval.customExpenses, isEmpty);
    });

    // =================================================
    // TEST 7 - CUSTOM EXPENSE VALIDATION
    // =================================================

    test('kebutuhan tambahan wajib memiliki nama', () {
      final container = createEditor();

      final notifier = container.read(planEditorProvider.notifier);

      // Masuk ke langkah 4.
      for (var i = 0; i < 3; i++) {
        expect(notifier.nextStep(), isNull);
      }

      notifier.addExpense();

      expect(notifier.nextStep(), 'Nama kebutuhan tambahan wajib diisi.');

      final id = container.read(planEditorProvider).customExpenses.first.id;

      notifier.updateExpense(id, name: 'Pendidikan');

      expect(notifier.nextStep(), isNull);

      expect(container.read(planEditorProvider).step, 4);
    });

    // =================================================
    // TEST 8 - SAVINGS & BUFFER
    // =================================================

    test('tabungan dan persentase cadangan diperbarui', () {
      final container = createEditor();

      final notifier = container.read(planEditorProvider.notifier);

      notifier.updateSavings(1000000);
      notifier.updateBufferPercent(15);

      final draft = container.read(planEditorProvider);

      final plan = draft.toFinancePlan();

      expect(draft.savings, 1000000);
      expect(draft.bufferPercent, 15);

      expect(plan.buffer, (plan.minimumIncome * 15 + 99) ~/ 100);

      // Nilai maksimum cadangan adalah 30%.

      notifier.updateBufferPercent(100);

      expect(container.read(planEditorProvider).bufferPercent, 30);
    });

    // =================================================
    // TEST 9 - SAVE PLAN
    // =================================================

    test('simpan mengaktifkan loading dan menyerahkan FinancePlan', () async {
      final container = createEditor();

      final notifier = container.read(planEditorProvider.notifier);

      moveToSummary(notifier);

      final completer = Completer<void>();

      FinancePlan? savedPlan;

      final saving = notifier.save((plan) {
        savedPlan = plan;
        return completer.future;
      });

      expect(container.read(planEditorProvider).isSaving, isTrue);

      expect(savedPlan?.name, 'Filipus');

      completer.complete();

      await saving;

      expect(container.read(planEditorProvider).isSaving, isFalse);
    });

    // =================================================
    // TEST 10 - STATE ISOLATION
    // =================================================

    test('dua sesi editor tidak berbagi state', () {
      final first = createEditor();
      final second = createEditor();

      first.read(planEditorProvider.notifier).updateSalary(7500000);

      expect(first.read(planEditorProvider).salary, 7500000);

      expect(second.read(planEditorProvider).salary, 6000000);
    });
  });
}
