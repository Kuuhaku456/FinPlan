import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/plan_editor_provider.dart';
import 'plan_editor_fields.dart';

// =====================================================
// FOOD BUDGET STEP
// =====================================================

/// Langkah 2: Anggaran makan Senin sampai Minggu.
/// Semua nominal dikelola PlanEditorNotifier.
class FoodBudgetStep extends ConsumerWidget {
  const FoodBudgetStep({
    super.key,
  });

  static const _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    // =================================================
    // RIVERPOD STATE
    // =================================================

    final foodByDay = ref.watch(
      planEditorProvider.select(
        (draft) => draft.foodByDay,
      ),
    );

    final weeklyFood = ref.watch(
      planEditorProvider.select(
        (draft) =>
            draft.toFinancePlan().weeklyFoodTotal,
      ),
    );

    final monthlyFood = ref.watch(
      planEditorProvider.select(
        (draft) => draft.toFinancePlan().food,
      ),
    );

    final notifier = ref.read(
      planEditorProvider.notifier,
    );

    final scheme = Theme.of(context).colorScheme;

    // =================================================
    // UI
    // =================================================

    return Column(
      children: [
        // =============================================
        // BIAYA MAKAN HARIAN
        // =============================================

        PlanEditorSectionCard(
          title: 'Biaya Makan Harian',
          icon: Icons.restaurant_rounded,
          children: [
            // =========================================
            // TOMBOL SAMAKAN ANGGARAN
            // =========================================

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      notifier.copyMondayFood(
                        allDays: false,
                      );
                    },
                    child: const Text(
                      'Samakan Sen–Jum',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      notifier.copyMondayFood(
                        allDays: true,
                      );
                    },
                    child: const Text(
                      'Samakan Semua',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // =========================================
            // INPUT SENIN - MINGGU
            // =========================================

            for (var day = 1; day <= 7; day++)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: PlanEditorMoneyField(
                  key: ValueKey('food_day_$day'),
                  label: _days[day - 1],
                  value: foodByDay[day] ?? 0,
                  onChanged: (amount) {
                    notifier.updateFoodDay(
                      day,
                      amount,
                    );
                  },
                ),
              ),

            Text(
              'Isi Rp0 pada hari ketika kamu tidak '
              'perlu mengeluarkan biaya makan. '
              'Setiap hari bisa memiliki anggaran '
              'berbeda.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // =============================================
        // RINGKASAN ANGGARAN
        // =============================================

        Row(
          children: [
            PlanEditorMetricCard(
              label: 'Per Minggu',
              amount: weeklyFood,
              icon: Icons.calendar_view_week_outlined,
              color: Colors.orange.shade700,
            ),

            const SizedBox(width: 10),

            PlanEditorMetricCard(
              label: 'Per Bulan',
              amount: monthlyFood,
              icon: Icons.calendar_month_outlined,
              color: scheme.primary,
            ),
          ],
        ),
      ],
    );
  }
}