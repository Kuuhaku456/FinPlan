import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models/finance_plan.dart';
import '../state/job_offer_controller.dart';
import '../widgets/plan_editor.dart';

// =====================================================
// FINPLAN - PLANNER PAGE
// =====================================================

class PlannerPage extends StatelessWidget {
  const PlannerPage({
    super.key,
    required this.plan,
    required this.onSave,
    this.jobOfferController,
  });

  final FinancePlan plan;

  final Future<void> Function(FinancePlan) onSave;

  // Dipertahankan untuk kompatibilitas dengan main.dart.
  final JobOfferController? jobOfferController;

  static const Color primaryGreen =
      Color(0xFF064E3B);

  static const Color accentGreen =
      Color(0xFF059669);

  static const Color lightGreen =
      Color(0xFFE7F7EE);

  // ===================================================
  // OPEN PLAN EDITOR
  // ===================================================

  Future<void> _openRecommendations(
    BuildContext context,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Atur Rencana',
              ),
            ),

            body: SafeArea(
              child: PlanEditor(
                initial: plan,
                onSave: onSave,
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================================================
  // OPEN ALLOCATION
  // ===================================================

  Future<void> _openAllocation(
    BuildContext context,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Pembagian Gaji',
              ),
            ),

            body: SafeArea(
              child: AllocationPage(
                plan: plan,
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================================================
  // MAIN PAGE
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final income = plan.totalMonthlyIncome;
    final budget = plan.idealIncome;
    final remaining = plan.plannedDifference;

    final isHealthy = plan.canFundPlan;

    final percentage = income <= 0
        ? 0.0
        : budget / income * 100;

    final progress = income <= 0
        ? 0.0
        : (budget / income)
            .clamp(0.0, 1.0)
            .toDouble();

    return ListView(
      physics: const BouncingScrollPhysics(),

      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        35,
      ),

      children: [
        // ==============================================
        // HEADER
        // ==============================================

        Text(
          'Rencana Keuangan',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'Kelola penghasilan dan kebutuhanmu.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 23),

        // ==============================================
        // MAIN SUMMARY CARD
        // ==============================================

        Container(
          padding: const EdgeInsets.all(22),

          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,

              colors: [
                primaryGreen,
                Color(0xFF08785B),
              ],
            ),

            borderRadius: BorderRadius.circular(25),

            boxShadow: [
              BoxShadow(
                color: primaryGreen.withValues(
                  alpha: 0.12,
                ),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // ========================================
              // CARD HEADER
              // ========================================

              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,

                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.15,
                      ),

                      borderRadius:
                          BorderRadius.circular(13),
                    ),

                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Text(
                      'Ringkasan Bulanan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const Icon(
                    Icons.auto_graph_rounded,
                    color: Color(0xFFBBF7D0),
                    size: 23,
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // ========================================
              // INCOME
              // ========================================

              const Text(
                'Total Pemasukan',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 6),

              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,

                child: Text(
                  rupiah(income),

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Container(
                height: 1,
                color: Colors.white.withValues(
                  alpha: 0.2,
                ),
              ),

              const SizedBox(height: 18),

              // ========================================
              // BUDGET AND BALANCE
              // ========================================

              Row(
                children: [
                  Expanded(
                    child: _SummaryValue(
                      label: 'Total Anggaran',
                      value: rupiah(budget),
                      icon: Icons.pie_chart_outline_rounded,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: _SummaryValue(
                      label: remaining >= 0
                          ? 'Sisa Uang'
                          : 'Kekurangan',

                      value: rupiah(
                        remaining.abs(),
                      ),

                      icon: remaining >= 0
                          ? Icons.savings_outlined
                          : Icons.warning_amber_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 23),

              // ========================================
              // PROGRESS
              // ========================================

              ClipRRect(
                borderRadius: BorderRadius.circular(12),

                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,

                  backgroundColor:
                      Colors.white.withValues(
                    alpha: 0.2,
                  ),

                  valueColor:
                      AlwaysStoppedAnimation<Color>(
                    isHealthy
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFFDE68A),
                  ),
                ),
              ),

              const SizedBox(height: 9),

              Text(
                income <= 0
                    ? 'Tambahkan pemasukan untuk memulai.'
                    : '${percentage.toStringAsFixed(1)}% '
                        'dari total pemasukan',

                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // ==============================================
        // FINANCIAL STATUS
        // ==============================================

        _FinancialStatusCard(
          income: income,
          remaining: remaining,
          isHealthy: isHealthy,
        ),

        const SizedBox(height: 29),

        // ==============================================
        // ACTIONS HEADER
        // ==============================================

        Text(
          'Kelola Rencana',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 14),

        // ==============================================
        // EDIT PLAN
        // ==============================================

        _PlannerActionCard(
          icon: Icons.tune_rounded,

          title: 'Atur Rencana',

          subtitle:
              'Sesuaikan pemasukan dan kebutuhan',

          iconColor: primaryGreen,

          iconBackground: lightGreen,

          onTap: () {
            _openRecommendations(context);
          },
        ),

        const SizedBox(height: 12),

        // ==============================================
        // SALARY ALLOCATION
        // ==============================================

        _PlannerActionCard(
          icon: Icons.donut_large_rounded,

          title: 'Pembagian Gaji',

          subtitle:
              'Lihat alokasi anggaran bulanan',

          iconColor: const Color(0xFF0D9488),

          iconBackground:
              const Color(0xFFCCFBF1),

          onTap: () {
            _openAllocation(context);
          },
        ),

        const SizedBox(height: 28),

        // ==============================================
        // QUICK OVERVIEW
        // ==============================================

        Text(
          'Anggaran Utama',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 13),

        Row(
          children: [
            Expanded(
              child: _MiniBudgetCard(
                icon: Icons.restaurant_rounded,
                title: 'Makanan',
                amount: plan.food,
                color: const Color(0xFFF59E0B),
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _MiniBudgetCard(
                icon: Icons.train_rounded,
                title: 'Transportasi',
                amount: plan.transport,
                color: const Color(0xFF0D9488),
              ),
            ),
          ],
        ),

        const SizedBox(height: 11),

        Row(
          children: [
            Expanded(
              child: _MiniBudgetCard(
                icon: Icons.savings_rounded,
                title: 'Tabungan',
                amount: plan.savings,
                color: accentGreen,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _MiniBudgetCard(
                icon: Icons.shield_outlined,
                title: 'Cadangan',
                amount: plan.buffer,
                color: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),

        const SizedBox(height: 25),

        // ==============================================
        // FINANCIAL TIP
        // ==============================================

        Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(17),
          ),

          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: scheme.onPrimaryContainer,
                size: 21,
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Text(
                  'Sisihkan tabungan secara rutin '
                  'dan sesuaikan kebutuhan dengan '
                  'penghasilan yang tersedia.',

                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================
// SUMMARY VALUE
// =====================================================

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Colors.white70,
              size: 15,
            ),

            const SizedBox(width: 6),

            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,

          child: Text(
            value,

            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// FINANCIAL STATUS
// =====================================================

class _FinancialStatusCard extends StatelessWidget {
  const _FinancialStatusCard({
    required this.income,
    required this.remaining,
    required this.isHealthy,
  });

  final int income;
  final int remaining;
  final bool isHealthy;

  @override
  Widget build(BuildContext context) {
    final title = income <= 0
        ? 'Belum Ada Pemasukan'
        : isHealthy
            ? 'Anggaran Terkendali'
            : 'Anggaran Perlu Disesuaikan';

    final subtitle = income <= 0
        ? 'Isi penghasilan melalui Atur Rencana.'
        : isHealthy
            ? 'Rencana sesuai dengan penghasilan.'
            : 'Pengeluaran melebihi pemasukan.';

    final background = isHealthy
        ? const Color(0xFFE7F7EE)
        : const Color(0xFFFFF2E9);

    final textColor = isHealthy
        ? const Color(0xFF064E3B)
        : const Color(0xFF9A520E);

    return Container(
      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,

            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.7,
              ),

              borderRadius: BorderRadius.circular(13),
            ),

            child: Icon(
              isHealthy
                  ? Icons.check_circle_rounded
                  : Icons.info_rounded,

              color: textColor,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,

                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// PLANNER ACTION CARD
// =====================================================

class _PlannerActionCard extends StatelessWidget {
  const _PlannerActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  final Color iconColor;
  final Color iconBackground;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),

      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,

        child: Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),

            border: Border.all(
              color: scheme.outlineVariant.withValues(
                alpha: 0.6,
              ),
            ),
          ),

          child: Row(
            children: [
              Container(
                width: 53,
                height: 53,

                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius:
                      BorderRadius.circular(16),
                ),

                child: Icon(
                  icon,
                  color: iconColor,
                  size: 25,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      title,

                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.arrow_forward_ios_rounded,
                color: scheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// MINI BUDGET CARD
// =====================================================

class _MiniBudgetCard extends StatelessWidget {
  const _MiniBudgetCard({
    required this.icon,
    required this.title,
    required this.amount,
    required this.color,
  });

  final IconData icon;
  final String title;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),

        border: Border.all(
          color: scheme.outlineVariant.withValues(
            alpha: 0.5,
          ),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Container(
            width: 39,
            height: 39,

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),

            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),

          const SizedBox(height: 13),

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 5),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,

            child: Text(
              rupiah(amount),

              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// ALLOCATION PAGE
// =====================================================

class AllocationPage extends StatelessWidget {
  const AllocationPage({
    super.key,
    required this.plan,
  });

  final FinancePlan plan;

  static const Color primaryGreen =
      Color(0xFF064E3B);

  // ===================================================
  // BUILD CATEGORIES
  // ===================================================

  List<_BudgetCategory> _categories() {
    final items = <_BudgetCategory>[
      _BudgetCategory(
        title: 'Tempat Tinggal',
        amount: plan.housing,
        icon: Icons.home_outlined,
        color: const Color(0xFF059669),
      ),

      _BudgetCategory(
        title: 'Makanan',
        amount: plan.food,
        icon: Icons.restaurant_rounded,
        color: const Color(0xFF10B981),
      ),

      _BudgetCategory(
        title: 'Transportasi',
        amount: plan.transport,
        icon: Icons.directions_transit_rounded,
        color: const Color(0xFF0D9488),
      ),

      _BudgetCategory(
        title: 'Tagihan',
        amount: plan.bills,
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF14B8A6),
      ),

      _BudgetCategory(
        title: 'Kebutuhan Pribadi',
        amount: plan.personal,
        icon: Icons.shopping_bag_outlined,
        color: const Color(0xFFF59E0B),
      ),

      _BudgetCategory(
        title: 'Tabungan',
        amount: plan.savings,
        icon: Icons.savings_outlined,
        color: const Color(0xFF65A30D),
      ),
    ];

    // Kebutuhan tambahan pengguna.
    for (final expense in plan.customExpenses) {
      final monthlyAmount = expense.monthlyAmount;

      if (monthlyAmount > 0) {
        items.add(
          _BudgetCategory(
            title: expense.name.trim().isEmpty
                ? 'Kebutuhan Tambahan'
                : expense.name,

            amount: monthlyAmount,

            icon: Icons.widgets_outlined,

            color: const Color(0xFF0891B2),
          ),
        );
      }
    }

    // Dana cadangan.
    if (plan.buffer > 0) {
      items.add(
        _BudgetCategory(
          title: 'Dana Cadangan',
          amount: plan.buffer,
          icon: Icons.shield_outlined,
          color: const Color(0xFF7C3AED),
        ),
      );
    }

    return items
        .where((item) => item.amount > 0)
        .toList();
  }

  // ===================================================
  // MAIN ALLOCATION PAGE
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final income = plan.totalMonthlyIncome;
    final budget = plan.idealIncome;
    final remaining = plan.plannedDifference;

    final categories = _categories();

    final percentage = income <= 0
        ? 0.0
        : budget / income * 100;

    final progress = income <= 0
        ? 0.0
        : (budget / income)
            .clamp(0.0, 1.0)
            .toDouble();

    return ListView(
      physics: const BouncingScrollPhysics(),

      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        35,
      ),

      children: [
        // ==============================================
        // HEADER
        // ==============================================

        Text(
          'Pembagian Gaji',

          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'Rincian penggunaan uang setiap bulan.',

          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 23),

        // ==============================================
        // TOTAL BUDGET
        // ==============================================

        Container(
          padding: const EdgeInsets.all(22),

          decoration: BoxDecoration(
            color: primaryGreen,
            borderRadius: BorderRadius.circular(24),
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const Text(
                'Total Alokasi Anggaran',

                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 7),

              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,

                child: Text(
                  rupiah(budget),

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(height: 19),

              ClipRRect(
                borderRadius: BorderRadius.circular(12),

                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,

                  backgroundColor: Colors.white24,

                  valueColor:
                      AlwaysStoppedAnimation<Color>(
                    plan.canFundPlan
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFFDE68A),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                income <= 0
                    ? 'Pemasukan belum diisi'
                    : '${percentage.toStringAsFixed(1)}% '
                        'dari pemasukan',

                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 21),

              Row(
                children: [
                  Expanded(
                    child: _AllocationSummary(
                      title: 'Pemasukan',
                      amount: income,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _AllocationSummary(
                      title: remaining >= 0
                          ? 'Sisa'
                          : 'Kekurangan',

                      amount: remaining.abs(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ==============================================
        // CATEGORY HEADER
        // ==============================================

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
              '${categories.length} kategori',

              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // ==============================================
        // CATEGORY LIST
        // ==============================================

        if (categories.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),

            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),

            child: Column(
              children: [
                Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 42,
                  color: scheme.onSurfaceVariant,
                ),

                const SizedBox(height: 12),

                const Text(
                  'Belum Ada Anggaran',

                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Isi kebutuhan melalui menu '
                  'Atur Rencana terlebih dahulu.',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(
                bottom: 11,
              ),

              child: _BudgetCategoryCard(
                category: category,
                totalBudget: budget,
              ),
            ),
          ),

        const SizedBox(height: 15),

        // ==============================================
        // FINAL STATUS
        // ==============================================

        Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: plan.canFundPlan
                ? const Color(0xFFE7F7EE)
                : const Color(0xFFFFF2E9),

            borderRadius: BorderRadius.circular(18),
          ),

          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Icon(
                plan.canFundPlan
                    ? Icons.check_circle_rounded
                    : Icons.info_rounded,

                color: plan.canFundPlan
                    ? primaryGreen
                    : const Color(0xFFB45309),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  income <= 0
                      ? 'Tambahkan pemasukan agar '
                          'anggaran dapat dibandingkan.'
                      : plan.canFundPlan
                          ? 'Anggaran sesuai dengan '
                              'penghasilan yang tersedia.'
                          : 'Total anggaran melebihi '
                              'pemasukan. Coba sesuaikan '
                              'beberapa kategori.',

                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF37564C),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================
// ALLOCATION SUMMARY
// =====================================================

class _AllocationSummary extends StatelessWidget {
  const _AllocationSummary({
    required this.title,
    required this.amount,
  });

  final String title;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),

        const SizedBox(height: 6),

        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,

          child: Text(
            rupiah(amount),

            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// BUDGET CATEGORY MODEL
// =====================================================

class _BudgetCategory {
  const _BudgetCategory({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String title;
  final int amount;
  final IconData icon;
  final Color color;
}

// =====================================================
// BUDGET CATEGORY CARD
// =====================================================

class _BudgetCategoryCard extends StatelessWidget {
  const _BudgetCategoryCard({
    required this.category,
    required this.totalBudget,
  });

  final _BudgetCategory category;
  final int totalBudget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final percentage = totalBudget <= 0
        ? 0.0
        : category.amount / totalBudget * 100;

    final progress = totalBudget <= 0
        ? 0.0
        : (category.amount / totalBudget)
            .clamp(0.0, 1.0)
            .toDouble();

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(19),

        border: Border.all(
          color: scheme.outlineVariant.withValues(
            alpha: 0.55,
          ),
        ),
      ),

      child: Column(
        children: [
          Row(
            children: [
              // ========================================
              // CATEGORY ICON
              // ========================================

              Container(
                width: 45,
                height: 45,

                decoration: BoxDecoration(
                  color: category.color.withValues(
                    alpha: 0.12,
                  ),

                  borderRadius:
                      BorderRadius.circular(13),
                ),

                child: Icon(
                  category.icon,
                  color: category.color,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              // ========================================
              // CATEGORY NAME
              // ========================================

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      category.title,

                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      '${percentage.toStringAsFixed(1)}%',

                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ========================================
              // CATEGORY AMOUNT
              // ========================================

              Flexible(
                child: Text(
                  rupiah(category.amount),

                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,

                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ============================================
          // CATEGORY PROGRESS
          // ============================================

          ClipRRect(
            borderRadius: BorderRadius.circular(10),

            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,

              backgroundColor:
                  category.color.withValues(
                alpha: 0.12,
              ),

              valueColor:
                  AlwaysStoppedAnimation<Color>(
                category.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}