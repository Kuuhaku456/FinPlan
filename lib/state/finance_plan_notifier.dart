import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/finance_plan.dart';

import 'finance_plan_riverpod_v2.dart';
import 'plan_controller.dart';

// =====================================================
// FINPLAN - FINANCE PLAN RIVERPOD BRIDGE
// =====================================================
//
// Mode lama:
// UI -> FinancePlanNotifier -> PlanController
//
// Mode V2:
// UI -> FinancePlanNotifier
//    -> FinancePlanV2Notifier
//    -> PlanRepository
//
// Aktifkan dengan:
//
// flutter run --dart-define=FINPLAN_PLAN_V2=true
//
// Tanpa flag, aplikasi tetap menggunakan mode lama.
// =====================================================

// =====================================================
// FEATURE FLAG
// =====================================================

final financePlanV2ModeProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('FINPLAN_PLAN_V2', defaultValue: false);
});

// =====================================================
// LEGACY PROVIDER
// =====================================================

// Tetap digunakan oleh pengaturan tema selama
// migrasi ke Riverpod belum sepenuhnya selesai.

final legacyPlanControllerProvider = Provider<PlanController>((ref) {
  throw StateError('PlanController belum diinisialisasi.');
});

// =====================================================
// MAIN FINANCE PLAN PROVIDER
// =====================================================

final financePlanProvider = NotifierProvider<FinancePlanNotifier, FinancePlan?>(
  FinancePlanNotifier.new,
);

// =====================================================
// MAIN NOTIFIER
// =====================================================

class FinancePlanNotifier extends Notifier<FinancePlan?> {
  bool _initialLoadScheduled = false;

  bool get _useV2 {
    return ref.read(financePlanV2ModeProvider);
  }

  // ===================================================
  // LEGACY FALLBACK
  // ===================================================

  FinancePlan? _initialLegacyPlan() {
    try {
      return ref.read(legacyPlanControllerProvider).plan;
    } on StateError {
      return null;
    }
  }

  // ===================================================
  // BUILD STATE
  // ===================================================

  @override
  FinancePlan? build() {
    final useV2 = ref.watch(financePlanV2ModeProvider);

    // ================================================
    // RIVERPOD V2
    // ================================================

    if (useV2) {
      final v2 = ref.watch(financePlanV2Provider);

      // Muat data repository satu kali ketika
      // provider mulai digunakan.
      //
      // Tidak perlu mengedit main.dart.

      if (!_initialLoadScheduled) {
        _initialLoadScheduled = true;

        Future<void>.microtask(() async {
          if (!ref.mounted) return;

          try {
            await ref.read(financePlanV2Provider.notifier).loadPlan();
          } catch (_) {
            // Jika load gagal, data startup lama
            // tetap digunakan sebagai fallback.
          }
        });
      }

      // Setelah V2 dimuat, data V2 adalah sumber
      // utama untuk Dashboard, Planner, dan Onboarding.
      if (v2.hasLoaded) {
        return v2.plan;
      }

      // Mencegah halaman onboarding muncul
      // sebentar saat data masih dibaca ulang.
      return _initialLegacyPlan();
    }

    // ================================================
    // LEGACY MODE
    // ================================================

    final controller = ref.watch(legacyPlanControllerProvider);

    void syncFromLegacyController() {
      if (!ref.mounted) return;

      final next = controller.plan;

      if (!identical(state, next)) {
        state = next;
      }
    }

    controller.addListener(syncFromLegacyController);

    ref.onDispose(() {
      controller.removeListener(syncFromLegacyController);
    });

    return controller.plan;
  }

  // ===================================================
  // SAVE FINANCE PLAN
  // ===================================================

  Future<void> savePlan(FinancePlan value) {
    if (_useV2) {
      return ref.read(financePlanV2Provider.notifier).savePlan(value);
    }

    return ref.read(legacyPlanControllerProvider).savePlan(value);
  }

  // ===================================================
  // CLEAR FINANCE PLAN
  // ===================================================

  Future<void> clearPlan() {
    if (_useV2) {
      return ref.read(financePlanV2Provider.notifier).clearPlan();
    }

    return ref.read(legacyPlanControllerProvider).clearPlan();
  }

  // ===================================================
  // REFRESH
  // ===================================================

  Future<void> refresh() {
    if (_useV2) {
      return ref.read(financePlanV2Provider.notifier).refresh();
    }

    // Legacy controller sudah menyimpan plan
    // aktif di dalam memori.
    return Future<void>.value();
  }
}

// =====================================================
// MONTHLY PLAN SUMMARY
// =====================================================

// Model ini tetap kompatibel dengan Dashboard,
// Planner, dan Kalkulator Gaji sebelumnya.

class MonthlyPlanSummary {
  const MonthlyPlanSummary({
    required this.income,
    required this.needs,
    required this.savings,
    required this.buffer,
    required this.remainingAfterNeeds,
    required this.remainingAfterPlan,
  });

  final int income;
  final int needs;
  final int savings;
  final int buffer;
  final int remainingAfterNeeds;
  final int remainingAfterPlan;
}

// =====================================================
// MONTHLY SUMMARY PROVIDER
// =====================================================

final monthlyPlanSummaryProvider = Provider<MonthlyPlanSummary?>((ref) {
  final plan = ref.watch(financePlanProvider);

  if (plan == null) return null;

  return MonthlyPlanSummary(
    income: plan.totalMonthlyIncome,
    needs: plan.expenses,
    savings: plan.savings,
    buffer: plan.buffer,
    remainingAfterNeeds: plan.totalMonthlyIncome - plan.expenses,
    remainingAfterPlan: plan.plannedDifference,
  );
});
