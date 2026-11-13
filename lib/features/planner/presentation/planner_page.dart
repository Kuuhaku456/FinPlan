import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../models/finance_plan.dart';
import 'allocation_page.dart';
import '../../../state/finance_plan_notifier.dart';
import '../../../widgets/plan_editor.dart';

import '../providers/planner_overview_provider.dart';

// =====================================================
// FINPLAN COLORS
// =====================================================

const _darkGreen = Color(0xFF064E3B);
const _green = Color(0xFF059669);
const _mint = Color(0xFFD1FAE5);
const _orange = Color(0xFFF59E0B);
const _blue = Color(0xFF3B82F6);
const _purple = Color(0xFF8B5CF6);

// =====================================================
// PLANNER PAGE
// =====================================================

class PlannerPage extends ConsumerWidget {
  const PlannerPage({super.key, required this.plan, required this.onSave});

  final FinancePlan plan;
  final Future<void> Function(FinancePlan) onSave;

  // ===================================================
  // OPEN FINANCIAL PLAN EDITOR
  // ===================================================

  void _openRecommendations(BuildContext context, FinancePlan current) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(title: const Text('Atur Rencana')),
            body: SafeArea(
              child: PlanEditor(initial: current, onSave: onSave),
            ),
          );
        },
      ),
    );
  }

  // ===================================================
  // OPEN SALARY ALLOCATION
  // ===================================================

  void _openAllocation(BuildContext context, FinancePlan current) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pembagian Gaji')),
            body: SafeArea(child: AllocationPage(plan: current)),
          );
        },
      ),
    );
  }

  // ===================================================
  // BUILD PLANNER
  // ===================================================

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ===============================================
    // RIVERPOD STATE
    // ===============================================

    final current = ref.watch(financePlanProvider) ?? plan;

    final overview =
        ref.watch(plannerOverviewProvider) ?? calculatePlannerOverview(current);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        // ============================================
        // HEADER
        // ============================================

        Text(
          'Rencana Keuangan',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 16),

        // ============================================
        // MAIN FINANCIAL SUMMARY
        // ============================================
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [_darkGreen, _green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white70,
                    size: 21,
                  ),

                  const SizedBox(width: 8),

                  const Text(
                    'Penghasilan Bulanan',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),

                  const Spacer(),

                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_graph_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 13),

              Text(
                rupiah(overview.income),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 24),

              // ======================================
              // BUDGET AND REMAINING
              // ======================================
              Row(
                children: [
                  Expanded(
                    child: _SummaryValue(
                      label: 'Anggaran',
                      value: rupiah(overview.budget),
                      icon: Icons.pie_chart_outline,
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 43,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: _SummaryValue(
                      label: overview.remainingLabel,
                      value: rupiah(overview.remainingAbsolute),
                      icon: overview.remaining >= 0
                          ? Icons.savings_outlined
                          : Icons.warning_amber_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 23),

              // ======================================
              // FINANCIAL PROGRESS
              // ======================================
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: overview.progress,
                  minHeight: 9,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),

              const SizedBox(height: 10),

              // ======================================
              // FINANCIAL STATUS
              // ======================================
              Row(
                children: [
                  Icon(
                    overview.canFundPlan
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: Colors.white,
                    size: 17,
                  ),

                  const SizedBox(width: 7),

                  Expanded(
                    child: Text(
                      overview.income <= 0
                          ? 'Tambahkan penghasilan'
                          : overview.canFundPlan
                          ? 'Anggaran sesuai penghasilan'
                          : 'Anggaran perlu disesuaikan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ============================================
        // PLANNER MENU HEADER
        // ============================================
        Row(
          children: [
            Text(
              'Kelola Keuangan',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const Spacer(),

            Icon(Icons.grid_view_rounded, size: 22, color: scheme.primary),
          ],
        ),

        const SizedBox(height: 14),

        // ============================================
        // PLANNER MENU
        // ============================================
        Row(
          children: [
            Expanded(
              child: _PlannerMenuCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Atur Rencana',
                color: _green,
                background: _mint,
                onTap: () {
                  _openRecommendations(context, current);
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _PlannerMenuCard(
                icon: Icons.donut_large_rounded,
                title: 'Pembagian Gaji',
                color: _purple,
                background: const Color(0xFFEDE9FE),
                onTap: () {
                  _openAllocation(context, current);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ============================================
        // BUDGET SUMMARY HEADER
        // ============================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ringkasan Anggaran',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            TextButton(
              onPressed: () {
                _openAllocation(context, current);
              },
              child: const Text('Lihat Semua'),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // ============================================
        // FOOD AND TRANSPORT
        // ============================================
        Row(
          children: [
            Expanded(
              child: _MiniBudgetCard(
                icon: Icons.restaurant_rounded,
                label: 'Makan',
                amount: current.food,
                color: _orange,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _MiniBudgetCard(
                icon: Icons.train_rounded,
                label: 'Transport',
                amount: current.transport,
                color: _blue,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ============================================
        // SAVINGS AND BUFFER
        // ============================================
        Row(
          children: [
            Expanded(
              child: _MiniBudgetCard(
                icon: Icons.savings_rounded,
                label: 'Tabungan',
                amount: overview.savings,
                color: _green,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _MiniBudgetCard(
                icon: Icons.shield_outlined,
                label: 'Cadangan',
                amount: overview.buffer,
                color: _purple,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ============================================
        // FINANCIAL TIP
        // ============================================
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                color: scheme.onPrimaryContainer,
                size: 23,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  'Rencana yang baik dimulai '
                  'dari kebutuhan utama.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),

            const SizedBox(width: 5),

            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// =====================================================
// PLANNER MENU CARD
// =====================================================

class _PlannerMenuCard extends StatelessWidget {
  const _PlannerMenuCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
      borderRadius: BorderRadius.circular(22),

      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,

        child: Container(
          constraints: const BoxConstraints(minHeight: 142),
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? color.withValues(alpha: 0.2) : background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 27),
              ),

              const Spacer(),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
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
    required this.label,
    required this.amount,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

      child: Padding(
        padding: const EdgeInsets.all(15),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),

            const SizedBox(height: 13),

            Text(label, style: theme.textTheme.bodySmall),

            const SizedBox(height: 5),

            Text(
              rupiah(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
