import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../models/finance_plan.dart';
import '../../../state/finance_plan_notifier.dart';

import '../providers/planner_overview_provider.dart';

// =====================================================
// COLORS
// =====================================================

const _green = Color(0xFF059669);

// =====================================================
// ALLOCATION PAGE
// =====================================================

class AllocationPage extends ConsumerWidget {
  const AllocationPage({
    super.key,
    required this.plan,
  });

  final FinancePlan plan;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    // ===============================================
    // RIVERPOD STATE
    // ===============================================

    final current =
        ref.watch(financePlanProvider) ?? plan;

    final overview =
        ref.watch(plannerOverviewProvider) ??
        calculatePlannerOverview(current);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final categories = overview.categories;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        32,
      ),
      children: [
        // ============================================
        // HEADER
        // ============================================

        Text(
          'Alokasi Keuangan',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 16),

        // ============================================
        // ALLOCATION SUMMARY CARD
        // ============================================

        Container(
          padding: const EdgeInsets.all(22),

          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: scheme.outlineVariant.withValues(
                alpha: 0.5,
              ),
            ),
          ),

          child: Column(
            children: [
              // ======================================
              // CIRCULAR PROGRESS
              // ======================================

              SizedBox(
                width: 176,
                height: 176,

                child: Stack(
                  alignment: Alignment.center,

                  children: [
                    SizedBox(
                      width: 176,
                      height: 176,

                      child: CircularProgressIndicator(
                        value: overview.progress,
                        strokeWidth: 17,
                        strokeCap: StrokeCap.round,

                        backgroundColor:
                            scheme.surfaceContainerHighest,

                        valueColor:
                            AlwaysStoppedAnimation<Color>(
                          overview.canFundPlan
                              ? _green
                              : scheme.error,
                        ),
                      ),
                    ),

                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${overview.allocationPercentage.toStringAsFixed(0)}%',
                          style: theme
                              .textTheme.headlineMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Terencana',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 23),

              // ======================================
              // TOTAL BUDGET
              // ======================================

              Text(
                'Total Anggaran',
                style: theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: 5),

              Text(
                rupiah(overview.budget),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 18),

              const Divider(),

              const SizedBox(height: 12),

              // ======================================
              // INCOME AND REMAINING
              // ======================================

              Row(
                children: [
                  Expanded(
                    child: _AllocationSummary(
                      icon: Icons.wallet_outlined,
                      label: 'Penghasilan',
                      value: rupiah(overview.income),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _AllocationSummary(
                      icon: overview.remaining >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,

                      label: overview.remainingLabel,

                      value: rupiah(
                        overview.remainingAbsolute,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        // ============================================
        // BUDGET STATUS
        // ============================================

        Container(
          padding: const EdgeInsets.all(15),

          decoration: BoxDecoration(
            color: overview.canFundPlan
                ? scheme.primaryContainer
                : scheme.errorContainer,

            borderRadius: BorderRadius.circular(16),
          ),

          child: Row(
            children: [
              Icon(
                overview.canFundPlan
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,

                color: overview.canFundPlan
                    ? scheme.onPrimaryContainer
                    : scheme.onErrorContainer,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  overview.income <= 0
                      ? 'Tambahkan penghasilan untuk mulai menghitung.'
                      : overview.canFundPlan
                          ? 'Anggaran masih sesuai dengan penghasilan.'
                          : 'Total anggaran melebihi penghasilan.',

                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,

                    color: overview.canFundPlan
                        ? scheme.onPrimaryContainer
                        : scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ============================================
        // CATEGORY HEADER
        // ============================================

        Row(
          children: [
            Expanded(
              child: Text(
                'Rincian Anggaran',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            Text(
              '${categories.length} Kategori',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),

        const SizedBox(height: 14),

        // ============================================
        // EMPTY STATE
        // ============================================

        if (categories.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Belum ada anggaran.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),

        // ============================================
        // BUDGET CATEGORIES
        // ============================================

        for (final category in categories)
          _BudgetCategoryTile(
            category: category,
            overview: overview,
          ),
      ],
    );
  }
}

// =====================================================
// ALLOCATION SUMMARY WIDGET
// =====================================================

class _AllocationSummary extends StatelessWidget {
  const _AllocationSummary({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 23,
        ),

        const SizedBox(height: 6),

        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),

        const SizedBox(height: 5),

        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,

          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// =====================================================
// BUDGET CATEGORY TILE
// =====================================================

class _BudgetCategoryTile extends StatelessWidget {
  const _BudgetCategoryTile({
    required this.category,
    required this.overview,
  });

  final PlannerBudgetCategory category;
  final PlannerOverview overview;

  // ===================================================
  // CATEGORY ICON
  // ===================================================

  IconData get _icon {
    return switch (category.type) {
      PlannerCategoryType.housing =>
        Icons.home_outlined,

      PlannerCategoryType.food =>
        Icons.restaurant_outlined,

      PlannerCategoryType.transport =>
        Icons.directions_transit_rounded,

      PlannerCategoryType.bills =>
        Icons.receipt_long_outlined,

      PlannerCategoryType.personal =>
        Icons.shopping_bag_outlined,

      PlannerCategoryType.savings =>
        Icons.savings_outlined,

      PlannerCategoryType.custom =>
        Icons.category_outlined,

      PlannerCategoryType.other =>
        Icons.more_horiz_rounded,

      PlannerCategoryType.buffer =>
        Icons.shield_outlined,
    };
  }

  // ===================================================
  // CATEGORY COLOR
  // ===================================================

  Color get _color {
    return switch (category.type) {
      PlannerCategoryType.housing =>
        const Color(0xFF3B82F6),

      PlannerCategoryType.food =>
        const Color(0xFFF59E0B),

      PlannerCategoryType.transport =>
        const Color(0xFF8B5CF6),

      PlannerCategoryType.bills =>
        const Color(0xFFEF4444),

      PlannerCategoryType.personal =>
        const Color(0xFFEC4899),

      PlannerCategoryType.savings =>
        _green,

      PlannerCategoryType.custom =>
        const Color(0xFF0EA5E9),

      PlannerCategoryType.other =>
        const Color(0xFF64748B),

      PlannerCategoryType.buffer =>
        const Color(0xFF14B8A6),
    };
  }

  // ===================================================
  // BUILD CATEGORY TILE
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final percent = overview.categoryPercentage(
      category.amount,
    );

    final progress = overview.categoryProgress(
      category.amount,
    );

    return Card(
      elevation: 0,

      margin: const EdgeInsets.only(
        bottom: 11,
      ),

      color: theme.colorScheme.surfaceContainerLow,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            Row(
              children: [
                // ===================================
                // CATEGORY ICON
                // ===================================

                Container(
                  width: 45,
                  height: 45,

                  decoration: BoxDecoration(
                    color: _color.withValues(
                      alpha: 0.13,
                    ),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),

                  child: Icon(
                    _icon,
                    color: _color,
                    size: 23,
                  ),
                ),

                const SizedBox(width: 12),

                // ===================================
                // CATEGORY INFORMATION
                // ===================================

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        category.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: theme.textTheme.titleSmall
                            ?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        '${percent.toStringAsFixed(1)}% dari anggaran',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // ===================================
                // CATEGORY AMOUNT
                // ===================================

                Text(
                  rupiah(category.amount),

                  style: theme.textTheme.labelLarge
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // =======================================
            // CATEGORY PROGRESS BAR
            // =======================================

            ClipRRect(
              borderRadius: BorderRadius.circular(20),

              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,

                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,

                valueColor:
                    AlwaysStoppedAnimation<Color>(
                  _color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}