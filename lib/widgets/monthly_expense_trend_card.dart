
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../state/transaction_controller.dart';
import '../state/transaction_notifier.dart';

// ============================================================
// MONTHLY EXPENSE TREND CARD
// ============================================================

class MonthlyExpenseTrendCard extends ConsumerWidget {
  const MonthlyExpenseTrendCard({
    super.key,
    required this.onOpenTransactions,
  });

  final VoidCallback onOpenTransactions;

  static const _shortMonths = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  String _label(DateTime date) {
    return '${_shortMonths[date.month - 1]} ${date.year % 100}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(
      monthlyTransactionTrendsProvider,
    );

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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

            // =================================================
            // HEADER
            // =================================================

            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tren Pengeluaran',
                        style:
                            theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      Text(
                        'Perbandingan 6 bulan',
                        style:
                            theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                TextButton(
                  onPressed: onOpenTransactions,
                  child: const Text('Transaksi'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // =================================================
            // RIVERPOD ASYNC DATA
            // =================================================

            trend.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 24,
                ),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

              error: (error, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gagal memuat tren pengeluaran.',
                    style: TextStyle(
                      color: scheme.error,
                    ),
                  ),

                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(
                        monthlyTransactionTrendsProvider,
                      );
                    },
                    icon: const Icon(
                      Icons.refresh_rounded,
                    ),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),

              data: (months) => _TrendContent(
                months: months,
                monthLabel: _label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TREND CONTENT
// ============================================================

class _TrendContent extends StatelessWidget {
  const _TrendContent({
    required this.months,
    required this.monthLabel,
  });

  final List<MonthlyTransactionTrend> months;

  final String Function(DateTime) monthLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (months.isEmpty) {
      return const Text('Belum ada data tren.');
    }

    // ========================================================
    // HITUNG PENGELUARAN TERTINGGI
    // ========================================================

    final maxExpense = months.fold<int>(
      0,
      (max, month) => math.max(
        max,
        month.expense,
      ),
    );

    final latest = months.last;

    final previous = months.length > 1
        ? months[months.length - 2]
        : null;

    final difference = previous == null
        ? 0
        : latest.expense - previous.expense;

    final isIncrease = difference > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // =====================================================
        // TOTAL PENGELUARAN BULAN TERPILIH
        // =====================================================

        Text(
          'Pengeluaran ${monthLabel(latest.month)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          rupiah(latest.expense),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: scheme.primary,
          ),
        ),

        // =====================================================
        // PERBANDINGAN BULAN SEBELUMNYA
        // =====================================================

        if (previous != null) ...[
          const SizedBox(height: 4),

          Text(
            difference == 0
                ? 'Sama dengan bulan sebelumnya'
                : '${isIncrease ? 'Naik' : 'Turun'} '
                    '${rupiah(difference.abs())} '
                    'dari ${monthLabel(previous.month)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: difference == 0
                  ? scheme.onSurfaceVariant
                  : isIncrease
                      ? scheme.error
                      : scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],

        const SizedBox(height: 16),

        // =====================================================
        // GRAFIK PENGELUARAN 6 BULAN
        // =====================================================

        for (final month in months) ...[
          Row(
            children: [
              SizedBox(
                width: 57,
                child: Text(
                  monthLabel(month.month),
                  style: theme.textTheme.bodySmall,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: maxExpense > 0
                        ? month.expense / maxExpense
                        : 0,
                    minHeight: 12,
                    color: month.month.year ==
                                latest.month.year &&
                            month.month.month ==
                                latest.month.month
                        ? scheme.primary
                        : scheme.primary.withValues(
                            alpha: 0.50,
                          ),
                    backgroundColor:
                        scheme.surfaceContainerHigh,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              SizedBox(
                width: 92,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    rupiah(month.expense),
                    style:
                        theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 11),
        ],

        // =====================================================
        // INFORMASI GRAFIK
        // =====================================================

        Text(
          'Panjang batang dibandingkan bulan dengan '
          'pengeluaran tertinggi. Data mencakup seluruh '
          'transaksi pada setiap bulan.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
