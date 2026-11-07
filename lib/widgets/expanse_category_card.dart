import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../data/transaction_repository.dart';
import '../models/transaction_category.dart';
import '../state/transaction_notifier.dart';

// ==========================================
// FINPLAN - EXPENSE CATEGORY CARD
// ==========================================
//
// Menampilkan:
// - Total pengeluaran bulanan
// - Donut chart kategori
// - Persentase pengeluaran
// - Nominal setiap kategori
// - Jumlah transaksi
//
// Data diambil langsung dari SQLite melalui
// monthlyExpenseCategoriesProvider.
//
// ==========================================

const _categoryColors = <Color>[
  Color(0xFF059669),
  Color(0xFF2563EB),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFFEA580C),
  Color(0xFFDC2626),
  Color(0xFF0891B2),
  Color(0xFFE11D48),
  Color(0xFF65A30D),
  Color(0xFF0D9488),
  Color(0xFF9333EA),
  Color(0xFF64748B),
];

// ==========================================
// CATEGORY COLOR HELPER
// ==========================================

Color _categoryColor(
  TransactionCategory category,
) {
  return _categoryColors[
    category.index % _categoryColors.length
  ];
}

// ==========================================
// MAIN WIDGET
// ==========================================

class ExpenseCategoryCard extends ConsumerWidget {
  const ExpenseCategoryCard({
    super.key,
    required this.onOpenTransactions,
  });

  final VoidCallback onOpenTransactions;

  static const _months = [
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

  String _monthLabel(DateTime date) {
    return '${_months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final selectedMonth = ref.watch(
      transactionStateProvider.select(
        (state) => state.selectedMonth,
      ),
    );

    final categoryData = ref.watch(
      monthlyExpenseCategoriesProvider,
    );

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
            // =================================
            // HEADER
            // =================================

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
                    Icons.donut_large_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kategori Pengeluaran',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        _monthLabel(selectedMonth),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(
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

            const SizedBox(height: 18),

            // =================================
            // CATEGORY CONTENT
            // =================================

            categoryData.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 35,
                ),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

              error: (error, stackTrace) {
                return _ErrorContent(
                  onRetry: () {
                    ref.invalidate(
                      monthlyExpenseCategoriesProvider,
                    );
                  },
                );
              },

              data: (categories) {
                return _CategoryContent(
                  categories: categories,
                  onOpenTransactions:
                      onOpenTransactions,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// CATEGORY CONTENT
// ==========================================

class _CategoryContent extends StatelessWidget {
  const _CategoryContent({
    required this.categories,
    required this.onOpenTransactions,
  });

  final List<ExpenseCategorySummary> categories;
  final VoidCallback onOpenTransactions;

  String _percentage(
    int amount,
    int total,
  ) {
    if (total <= 0) return '0%';

    final percent = amount / total * 100;

    return '${percent.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final visibleCategories = categories
        .where(
          (category) => category.totalAmount > 0,
        )
        .toList();

    // =====================================
    // EMPTY STATE
    // =====================================

    if (visibleCategories.isEmpty) {
      return _EmptyContent(
        onOpenTransactions: onOpenTransactions,
      );
    }

    // =====================================
    // CALCULATE TOTAL
    // =====================================

    final totalExpense = visibleCategories.fold<int>(
      0,
      (total, category) {
        return total + category.totalAmount;
      },
    );

    final totalTransactions =
        visibleCategories.fold<int>(
      0,
      (total, category) {
        return total + category.transactionCount;
      },
    );

    // =====================================
    // PREPARE CHART SEGMENTS
    // =====================================

    final segments = visibleCategories.map(
      (category) {
        return _ChartSegment(
          amount: category.totalAmount,
          color: _categoryColor(
            category.category,
          ),
        );
      },
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // =================================
        // TOTAL EXPENSE
        // =================================

        Text(
          'Total Pengeluaran',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 5),

        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            rupiah(totalExpense),
            style: theme.textTheme.headlineSmall
                ?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        const SizedBox(height: 5),

        Text(
          '$totalTransactions transaksi • '
          '${visibleCategories.length} kategori',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 24),

        // =================================
        // DONUT CHART
        // =================================

        Center(
          child: SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Semantics(
                  label:
                      'Diagram pembagian pengeluaran '
                      'berdasarkan kategori',
                  child: CustomPaint(
                    size: const Size(190, 190),
                    painter: _DonutChartPainter(
                      segments: segments,
                      total: totalExpense,
                      background:
                          scheme.surfaceContainerHigh,
                    ),
                  ),
                ),

                SizedBox(
                  width: 114,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        color: scheme.primary,
                        size: 22,
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 11,
                        ),
                      ),

                      const SizedBox(height: 3),

                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          rupiah(totalExpense),
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 25),

        Divider(
          color: scheme.outlineVariant,
        ),

        const SizedBox(height: 14),

        // =================================
        // CATEGORY LIST HEADER
        // =================================

        Text(
          'Rincian Pengeluaran',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 15),

        // =================================
        // CATEGORY ROWS
        // =================================

        for (final category in visibleCategories) ...[
          _CategoryRow(
            category: category,
            color: _categoryColor(
              category.category,
            ),
            percentage: _percentage(
              category.totalAmount,
              totalExpense,
            ),
            progress: totalExpense > 0
                ? category.totalAmount / totalExpense
                : 0,
          ),

          const SizedBox(height: 13),
        ],

        const SizedBox(height: 3),

        // =================================
        // INFORMATION
        // =================================

        Text(
          'Persentase dihitung berdasarkan seluruh '
          'transaksi Pengeluaran pada bulan yang '
          'dipilih, bukan hanya transaksi yang '
          'sedang ditampilkan pada daftar.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// CATEGORY ROW
// ==========================================

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.color,
    required this.percentage,
    required this.progress,
  });

  final ExpenseCategorySummary category;
  final Color color;
  final String percentage;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // =============================
            // CATEGORY ICON
            // =============================

            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                category.categoryEmoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),

            const SizedBox(width: 11),

            // =============================
            // CATEGORY NAME
            // =============================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    category.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    '${category.transactionCount} transaksi',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // =============================
            // CATEGORY AMOUNT
            // =============================

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rupiah(category.totalAmount),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  percentage,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 9),

        // =============================
        // CATEGORY PROGRESS BAR
        // =============================

        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 7,
            color: color,
            backgroundColor:
                scheme.surfaceContainerHigh,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// CHART SEGMENT MODEL
// ==========================================

class _ChartSegment {
  const _ChartSegment({
    required this.amount,
    required this.color,
  });

  final int amount;
  final Color color;
}

// ==========================================
// DONUT CHART PAINTER
// ==========================================

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({
    required this.segments,
    required this.total,
    required this.background,
  });

  final List<_ChartSegment> segments;
  final int total;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final diameter = math.min(
      size.width,
      size.height,
    );

    final strokeWidth = diameter * 0.14;

    final radius =
        (diameter - strokeWidth) / 2;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    // =====================================
    // BACKGROUND RING
    // =====================================

    final backgroundPaint = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      backgroundPaint,
    );

    if (total <= 0 || segments.isEmpty) {
      return;
    }

    // =====================================
    // CATEGORY SEGMENTS
    // =====================================

    var startAngle = -math.pi / 2;

    for (final segment in segments) {
      if (segment.amount <= 0) continue;

      final ratio = segment.amount / total;

      final sweepAngle =
          2 * math.pi * ratio;

      // Celah kecil antarkategori.
      final gap = segments.length == 1 ||
              sweepAngle < 0.025
          ? 0.0
          : 0.02;

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        rect,
        startAngle + gap / 2,
        math.max(0, sweepAngle - gap),
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(
    covariant _DonutChartPainter oldDelegate,
  ) {
    return oldDelegate.total != total ||
        oldDelegate.background != background ||
        oldDelegate.segments != segments;
  }
}

// ==========================================
// EMPTY CONTENT
// ==========================================

class _EmptyContent extends StatelessWidget {
  const _EmptyContent({
    required this.onOpenTransactions,
  });

  final VoidCallback onOpenTransactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            size: 48,
            color: scheme.onSurfaceVariant,
          ),

          const SizedBox(height: 13),

          Text(
            'Belum Ada Pengeluaran',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Tambahkan transaksi pengeluaran untuk '
            'melihat analisis berdasarkan kategori.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 17),

          OutlinedButton.icon(
            onPressed: onOpenTransactions,
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              'Tambah Transaksi',
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ERROR CONTENT
// ==========================================

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: scheme.error,
            ),

            const SizedBox(width: 9),

            const Expanded(
              child: Text(
                'Gagal memuat kategori pengeluaran.',
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(
            Icons.refresh_rounded,
          ),
          label: const Text('Coba Lagi'),
        ),
      ],
    );
  }
}