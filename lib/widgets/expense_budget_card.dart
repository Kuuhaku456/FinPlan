import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../models/finance_plan.dart';
import '../state/transaction_notifier.dart';

/// Anggaran berasal dari FinancePlan.
/// Realisasi pengeluaran berasal dari seluruh transaksi bulan yang dipilih.
@immutable
class ExpenseBudgetMetrics {
  const ExpenseBudgetMetrics({
    required this.budget,
    required this.spent,
  });

  final int budget;
  final int spent;

  bool get hasBudget => budget > 0;

  bool get isOverBudget => hasBudget && spent > budget;

  int get remaining => budget - spent;

  double get usedRatio => hasBudget ? spent / budget : 0;

  double get progress => usedRatio.clamp(0.0, 1.0).toDouble();

  String get usedPercentage =>
      '${(usedRatio * 100).toStringAsFixed(1)}%';

  /// Menghitung perkiraan jatah pengeluaran harian
  /// berdasarkan sisa anggaran bulan berjalan.
  int? dailyAllowance(
    DateTime selectedMonth,
    DateTime today,
  ) {
    if (!hasBudget ||
        selectedMonth.year != today.year ||
        selectedMonth.month != today.month) {
      return null;
    }

    final daysInMonth = DateTime(
      today.year,
      today.month + 1,
      0,
    ).day;

    final daysRemaining = daysInMonth - today.day + 1;

    if (daysRemaining <= 0) return null;

    return (remaining > 0 ? remaining : 0) ~/ daysRemaining;
  }
}

class ExpenseBudgetCard extends ConsumerWidget {
  const ExpenseBudgetCard({
    super.key,
    required this.plan,
    required this.onOpenTransactions,
    required this.onOpenPlanner,
  });

  final FinancePlan plan;
  final VoidCallback onOpenTransactions;
  final VoidCallback onOpenPlanner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionStateProvider);

    final metrics = ExpenseBudgetMetrics(
      budget: plan.expenses,
      spent: transactions.totalExpense,
    );

    final allowance = metrics.dailyAllowance(
      transactions.selectedMonth,
      DateTime.now(),
    );

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final over = metrics.isOverBudget;
    final accent = over ? colors.error : colors.primary;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // HEADER
            // =========================

            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.insights_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Text(
                    'Analisis Pengeluaran',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                if (transactions.isLoading)
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              'Perbandingan realisasi dengan anggaran kebutuhan bulanan',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),

            // =========================
            // ERROR HANDLING
            // =========================

            if (transactions.error != null) ...[
              const SizedBox(height: 12),

              Text(
                transactions.error!,
                style: TextStyle(
                  color: colors.error,
                ),
              ),

              TextButton.icon(
                onPressed: () {
                  ref
                      .read(transactionStateProvider.notifier)
                      .loadTransactions();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Muat ulang transaksi'),
              ),
            ],

            const SizedBox(height: 17),

            // =========================
            // BUDGET & EXPENSE SUMMARY
            // =========================

            Row(
              children: [
                Expanded(
                  child: _AmountBox(
                    label: 'Anggaran Kebutuhan',
                    amount: metrics.budget,
                    color: colors.primary,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _AmountBox(
                    label: 'Sudah Dikeluarkan',
                    amount: metrics.spent,
                    color: accent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // =========================
            // PROGRESS BAR
            // =========================

            if (metrics.hasBudget) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Anggaran terpakai',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),

                  Text(
                    metrics.usedPercentage,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: metrics.progress,
                  minHeight: 10,
                  color: accent,
                  backgroundColor: colors.surfaceContainerHigh,
                ),
              ),
            ] else
              Text(
                'Anggaran kebutuhan belum diatur.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                ),
              ),

            const SizedBox(height: 14),

            // =========================
            // REMAINING BUDGET
            // =========================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: over
                    ? colors.errorContainer
                    : colors.primaryContainer,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(
                    over
                        ? Icons.warning_amber_rounded
                        : Icons.task_alt_rounded,
                    color: over
                        ? colors.onErrorContainer
                        : colors.onPrimaryContainer,
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          !metrics.hasBudget
                              ? 'Atur anggaran terlebih dahulu'
                              : over
                                  ? 'Melebihi anggaran'
                                  : 'Sisa anggaran',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        Text(
                          metrics.hasBudget
                              ? rupiah(metrics.remaining.abs())
                              : 'Belum tersedia',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // =========================
            // DAILY ALLOWANCE
            // =========================

            if (allowance != null) ...[
              const SizedBox(height: 10),

              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: colors.onSurfaceVariant,
                    size: 16,
                  ),

                  const SizedBox(width: 7),

                  Expanded(
                    child: Text(
                      'Perkiraan jatah per hari sampai akhir bulan:',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),

                  Text(
                    rupiah(allowance),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // =========================
            // ACTION BUTTONS
            // =========================

            LayoutBuilder(
              builder: (context, constraints) {
                final budgetButton = OutlinedButton.icon(
                  onPressed: onOpenPlanner,
                  icon: const Icon(
                    Icons.tune_rounded,
                    size: 17,
                  ),
                  label: const Text('Atur Anggaran'),
                );

                final transactionButton = FilledButton.icon(
                  onPressed: onOpenTransactions,
                  icon: const Icon(
                    Icons.receipt_long_rounded,
                    size: 17,
                  ),
                  label: const Text('Transaksi'),
                );

                // Layout vertikal untuk layar kecil
                if (constraints.maxWidth < 340) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      budgetButton,

                      const SizedBox(height: 7),

                      transactionButton,
                    ],
                  );
                }

                // Layout horizontal untuk layar normal
                return Row(
                  children: [
                    Expanded(
                      child: budgetButton,
                    ),

                    const SizedBox(width: 9),

                    Expanded(
                      child: transactionButton,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 8),

            // =========================
            // INFORMATION
            // =========================

            Text(
              'Menghitung semua transaksi bertipe Pengeluaran pada bulan '
              'yang sedang dipilih di tab Transaksi, termasuk setoran '
              'tabungan jika dicatat sebagai pengeluaran.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// AMOUNT BOX COMPONENT
// =============================================

class _AmountBox extends StatelessWidget {
  const _AmountBox({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: 6),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(amount),
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}