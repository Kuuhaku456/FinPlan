
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../models/finance_transaction.dart';
import '../state/transaction_notifier.dart';

// ============================================================
// TRANSACTIONS OVERVIEW CARD
// ============================================================

class TransactionsOverviewCard extends ConsumerWidget {
  const TransactionsOverviewCard({
    super.key,
    required this.onOpenTransactions,
  });

  final VoidCallback onOpenTransactions;

  // ==========================================================
  // NAMA BULAN
  // ==========================================================

  static const _months = <String>[
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionStateProvider);

    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final month = state.selectedMonth;

    final monthLabel =
        '${_months[month.month - 1]} ${month.year}';

    final netIsPositive = state.netAmount >= 0;

    final incomeColor = scheme.primary;
    final expenseColor = scheme.error;

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
                    Icons.receipt_long_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaksi Tercatat',
                        style:
                            theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        monthLabel,
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
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // =================================================
            // LOADING INDICATOR
            // =================================================

            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(
                  minHeight: 3,
                ),
              ),

            // =================================================
            // ERROR HANDLING
            // =================================================

            if (state.error != null) ...[
              Text(
                state.error!,
                style: TextStyle(
                  color: scheme.error,
                ),
              ),

              const SizedBox(height: 8),

              OutlinedButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () => ref
                        .read(transactionStateProvider.notifier)
                        .loadTransactions(),
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text('Coba Lagi'),
              ),

              const SizedBox(height: 8),
            ],

            // =================================================
            // TOTAL PEMASUKAN DAN PENGELUARAN
            // =================================================

            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    title: 'Pemasukan',
                    amount: state.totalIncome,
                    icon: Icons.south_west_rounded,
                    color: incomeColor,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _SummaryTile(
                    title: 'Pengeluaran',
                    amount: state.totalExpense,
                    icon: Icons.north_east_rounded,
                    color: expenseColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // =================================================
            // SELISIH TRANSAKSI
            // =================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: netIsPositive
                    ? scheme.primaryContainer
                    : scheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    netIsPositive
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: netIsPositive
                        ? scheme.onPrimaryContainer
                        : scheme.onErrorContainer,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      'Selisih transaksi bulan ini',
                      style:
                          theme.textTheme.bodySmall?.copyWith(
                        color: netIsPositive
                            ? scheme.onPrimaryContainer
                            : scheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        rupiah(state.netAmount),
                        style:
                            theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: netIsPositive
                              ? scheme.onPrimaryContainer
                              : scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // =================================================
            // AKTIVITAS TERBARU
            // =================================================

            Text(
              'Aktivitas Terbaru',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 7),

            // Jika belum ada transaksi
            if (state.transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                ),
                child: Text(
                  state.isLoading
                      ? 'Sedang mengambil transaksi...'
                      : 'Belum ada transaksi pada bulan ini.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )

            // Jika sudah ada transaksi
            else
              for (final transaction
                  in state.transactions.take(3))
                _RecentTransactionRow(
                  transaction: transaction,
                ),

            const SizedBox(height: 6),

            // =================================================
            // INFORMASI TAMBAHAN
            // =================================================

            Text(
              'Selisih ini bukan saldo rekening. '
              'Anggaran ada di bagian Rencana.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SUMMARY TILE
// ============================================================

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String title;
  final int amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),

              const SizedBox(width: 4),

              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

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

// ============================================================
// RECENT TRANSACTION ROW
// ============================================================

class _RecentTransactionRow extends StatelessWidget {
  const _RecentTransactionRow({
    required this.transaction,
  });

  final FinanceTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final income =
        transaction.type == TransactionType.income;

    final color = income
        ? scheme.primary
        : scheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        children: [

          // =================================================
          // ICON
          // =================================================

          CircleAvatar(
            radius: 17,
            backgroundColor: scheme.surfaceContainerHigh,
            child: Icon(
              income
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              color: color,
              size: 17,
            ),
          ),

          const SizedBox(width: 10),

          // =================================================
          // DESCRIPTION & ACCOUNT
          // =================================================

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                Text(
                  '${transaction.date.day}/${transaction.date.month} '
                  '• ${transaction.accountName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // =================================================
          // AMOUNT
          // =================================================

          Text(
            '${income ? '+' : '-'}${rupiah(transaction.amount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
