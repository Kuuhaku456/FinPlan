import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/plan_editor_provider.dart';
import 'plan_editor_fields.dart';

// =====================================================
// SAVINGS STEP
// =====================================================

class SavingsStep extends ConsumerWidget {
  const SavingsStep({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    // =================================================
    // RIVERPOD STATE
    // =================================================

    final draft = ref.watch(
      planEditorProvider,
    );

    final notifier = ref.read(
      planEditorProvider.notifier,
    );

    final plan = draft.toFinancePlan();

    final scheme = Theme.of(context).colorScheme;

    // =================================================
    // UI
    // =================================================

    return Column(
      children: [
        // =============================================
        // TARGET TABUNGAN
        // =============================================

        PlanEditorSectionCard(
          title: 'Target Tabungan',
          icon: Icons.savings_outlined,
          children: [
            PlanEditorMoneyField(
              key: const ValueKey('savings'),
              label: 'Tabungan Bulanan',
              value: draft.savings,
              onChanged: notifier.updateSavings,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // =============================================
        // DANA CADANGAN
        // =============================================

        PlanEditorSectionCard(
          title: 'Dana Cadangan',
          icon: Icons.shield_outlined,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Persentase Cadangan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                // =====================================
                // BADGE PERSENTASE
                // =====================================

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${draft.bufferPercent}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // =========================================
            // SLIDER DANA CADANGAN
            // =========================================

            Slider(
              value: draft.bufferPercent
                  .clamp(0, 30)
                  .toDouble(),
              min: 0,
              max: 30,
              divisions: 30,
              label: '${draft.bufferPercent}%',
              onChanged: (value) {
                notifier.updateBufferPercent(
                  value.round(),
                );
              },
            ),

            Text(
              'Dana cadangan dihitung dari total '
              'kebutuhan bulanan dan target tabungan.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // =============================================
        // RINGKASAN TABUNGAN DAN CADANGAN
        // =============================================

        Row(
          children: [
            PlanEditorMetricCard(
              label: 'Tabungan',
              amount: plan.savings,
              icon: Icons.savings_rounded,
              color: scheme.primary,
            ),

            const SizedBox(width: 10),

            PlanEditorMetricCard(
              label: 'Cadangan',
              amount: plan.buffer,
              icon: Icons.shield_outlined,
              color: Colors.blue.shade600,
            ),
          ],
        ),
      ],
    );
  }
}