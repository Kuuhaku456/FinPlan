import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/finance_plan.dart';
import 'plan_controller.dart';

/// Bridge sementara ke PlanController lama.
///
/// Selama migrasi, seluruh perubahan rencana (termasuk dari onboarding
/// dan tombol Reset) tetap tercermin pada halaman yang memakai Riverpod.
/// Repository dan data pengguna tidak diubah atau dihapus.
final legacyPlanControllerProvider = Provider<PlanController>(
  (ref) => throw StateError('PlanController belum diinisialisasi.'),
);

final financePlanProvider =
    NotifierProvider<FinancePlanNotifier, FinancePlan?>(
  FinancePlanNotifier.new,
);

class FinancePlanNotifier extends Notifier<FinancePlan?> {
  @override
  FinancePlan? build() {
    final legacyController = ref.watch(legacyPlanControllerProvider);

    void syncFromLegacyController() {
      final next = legacyController.plan;
      if (!identical(state, next)) {
        state = next;
      }
    }

    legacyController.addListener(syncFromLegacyController);
    ref.onDispose(
      () => legacyController.removeListener(syncFromLegacyController),
    );

    return legacyController.plan;
  }

  /// Semua penyimpanan melewati repository lama untuk menjaga format data.
  /// Listener di atas akan mengirim state terbaru setelah save berhasil.
  Future<void> savePlan(FinancePlan value) {
    return ref.read(legacyPlanControllerProvider).savePlan(value);
  }

  Future<void> clearPlan() {
    return ref.read(legacyPlanControllerProvider).clearPlan();
  }
}

/// Ringkasan yang bisa dipakai Dashboard dan Kalkulator Gaji tanpa
/// menghitung ulang seluruh kebutuhan setiap kali sebuah widget dibangun.
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
