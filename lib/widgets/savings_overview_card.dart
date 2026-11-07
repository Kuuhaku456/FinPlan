import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../models/savings_goal.dart';
import '../state/savings_notifier.dart';

/// Ringkasan tabungan aktual, bukan alokasi bulanan FinancePlan.
class SavingsOverviewCard extends ConsumerWidget {
  const SavingsOverviewCard({
    super.key,
    required this.onOpenSavings,
    this.buttonLabel = 'Lihat Semua',
  });

  final VoidCallback onOpenSavings;
  final String buttonLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savingsStateProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    final accentBackground = isDark
        ? scheme.primaryContainer
        : const Color(0xFFE9F8F0);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentBackground,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.savings_rounded,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Kantong Tabungan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenSavings,
                  child: Text(buttonLabel),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // BELUM SELESAI MEMUAT
            if (!state.hasLoaded && state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 17),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )

            // DATA BELUM DIMUAT ATAU GAGAL
            else if (!state.hasLoaded)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.error ?? 'Data tabungan belum dimuat.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(savingsStateProvider.notifier)
                          .loadGoals();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Muat Tabungan'),
                  ),
                ],
              )

            // BELUM MEMILIKI KANTONG AKTIF
            else if (state.activeGoals.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum ada kantong tabungan aktif.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Buat target pertamamu, lalu catat setoran secara berkala.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onOpenSavings,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Buka Kantong Tabungan'),
                  ),
                ],
              )

            // ADA KANTONG AKTIF
            else ...[
              Text(
                'Total Terkumpul',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                rupiah(state.totalSaved),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Dari target ${rupiah(state.totalTarget)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 13),

              // PROGRESS KESELURUHAN
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 9,
                  backgroundColor: accentBackground,
                  color: scheme.primary,
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${state.summary.activeGoals} kantong aktif',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${(state.progress * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // TAMPILKAN MAKSIMAL DUA KANTONG
              for (final goal in state.activeGoals.take(2)) ...[
                _GoalProgressRow(goal: goal),
                const SizedBox(height: 10),
              ],

              if (state.activeGoals.length > 2)
                Text(
                  '+${state.activeGoals.length - 2} kantong lainnya',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],

            // PESAN ERROR SETELAH DATA PERNAH DIMUAT
            if (state.hasLoaded && state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: TextStyle(
                  color: scheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ITEM PROGRESS KANTONG
// ============================================================

class _GoalProgressRow extends StatelessWidget {
  const _GoalProgressRow({
    required this.goal,
  });

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${goal.emoji} ${goal.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${goal.progressPercent.toStringAsFixed(0)}%',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: goal.progress,
            minHeight: 5,
            color: scheme.primary,
            backgroundColor: scheme.primaryContainer,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          '${rupiah(goal.savedAmount)} / ${rupiah(goal.targetAmount)}',
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}