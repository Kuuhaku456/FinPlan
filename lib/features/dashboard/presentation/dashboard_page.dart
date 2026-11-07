import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../models/finance_plan.dart';
import '../../../state/finance_plan_notifier.dart';

// DASHBOARD WIDGETS
import '../../../widgets/transactions_overview_card.dart';
import '../../../widgets/expense_budget_card.dart';
import '../../../widgets/expanse_category_card.dart';
import '../../../widgets/monthly_expense_trend_card.dart';
import '../../../widgets/savings_overview_card.dart';

import 'widgets/allocation_card.dart';

// ==========================================
// FINPLAN COLORS
// ==========================================

const _darkGreen = Color(0xFF064E3B);
const _green = Color(0xFF059669);
const _muted = Color(0xFF84958C);
const _softGreen = Color(0xFFE9F8F0);

// ==========================================
// DASHBOARD PAGE
// ==========================================

class DashboardPage extends ConsumerWidget {
  const DashboardPage({
    super.key,
    required this.plan,
    required this.onOpenPlanner,
    this.onOpenTransactions,
  });

  final FinancePlan plan;

  final VoidCallback onOpenPlanner;

  final VoidCallback? onOpenTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ======================================
    // RIVERPOD FINANCE PLAN
    // ======================================

    final current =
        ref.watch(financePlanProvider) ?? plan;

    final scheme = Theme.of(context).colorScheme;

    final positive =
        current.plannedDifference >= 0;

    final openTransactions =
        onOpenTransactions ?? onOpenPlanner;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        32,
      ),
      children: [
        // ===================================
        // 1. WELCOME HEADER
        // ===================================

        Row(
          children: [
            Container(
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                color: _softGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.waving_hand_rounded,
                color: _darkGreen,
                size: 24,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selamat datang 👋',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    current.name.trim().isEmpty
                        ? 'Keuanganmu'
                        : current.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            IconButton.filledTonal(
              tooltip: 'Buka Planner',
              onPressed: onOpenPlanner,
              icon: const Icon(
                Icons.tune_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ===================================
        // 2. MONTHLY INCOME CARD
        // ===================================

        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _darkGreen,
                _green,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22064E3B),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pemasukan bulanan',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),

                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ],
              ),

              const SizedBox(height: 11),

              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  current.totalMonthlyIncome > 0
                      ? rupiah(
                          current.totalMonthlyIncome,
                        )
                      : 'Belum ada pemasukan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // =============================
              // FINANCIAL PLAN STATUS
              // =============================

              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.13,
                  ),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      positive
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: const Color(0xFFBBF7D0),
                      size: 21,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            positive
                                ? 'Anggaran aman'
                                : 'Perlu penyesuaian',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            '${positive ? 'Sisa' : 'Kurang'} '
                            '${rupiah(current.plannedDifference.abs())}',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 17),

        // ===================================
        // 3. BUDGET SUMMARY
        // ===================================

        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.shopping_bag_outlined,
                label: 'Kebutuhan',
                amount: current.expenses,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _MetricCard(
                icon: Icons.savings_outlined,
                label: 'Rencana Tabungan',
                amount: current.savings,
              ),
            ),
          ],
        ),

        const SizedBox(height: 11),

        // ===================================
        // 4. EMERGENCY BUFFER
        // ===================================

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: scheme.brightness == Brightness.dark
                ? scheme.surface
                : _softGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: _green,
                size: 20,
              ),

              const SizedBox(width: 10),

              const Expanded(
                child: Text(
                  'Dana Cadangan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              Text(
                rupiah(current.buffer),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 23),

        // ===================================
        // 5. TRANSACTION OVERVIEW
        // ===================================

        TransactionsOverviewCard(
          onOpenTransactions: openTransactions,
        ),

        const SizedBox(height: 18),

        // ===================================
        // 6. EXPENSE BUDGET ANALYSIS
        // ===================================

        ExpenseBudgetCard(
          plan: current,
          onOpenTransactions: openTransactions,
          onOpenPlanner: onOpenPlanner,
        ),

        const SizedBox(height: 18),

        // ===================================
        // 7. EXPENSE CATEGORY ANALYSIS
        // ===================================

        ExpenseCategoryCard(
          onOpenTransactions: openTransactions,
        ),

        const SizedBox(height: 18),

        // ===================================
        // 8. MONTHLY EXPENSE TREND
        // ===================================

        MonthlyExpenseTrendCard(
          onOpenTransactions: openTransactions,
        ),

        const SizedBox(height: 18),

        // ===================================
        // 9. SAVINGS OVERVIEW
        // ===================================

        SavingsOverviewCard(
          onOpenSavings: onOpenPlanner,
          buttonLabel: 'Buka Planner',
        ),

        const SizedBox(height: 18),

        // ===================================
        // 10. SALARY ALLOCATION CHART
        // ===================================

        AllocationCard(
          plan: current,
        ),

        const SizedBox(height: 18),

        // ===================================
        // 11. OPEN PLANNER BUTTON
        // ===================================

        FilledButton.icon(
          onPressed: onOpenPlanner,
          style: FilledButton.styleFrom(
            backgroundColor: _darkGreen,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          icon: const Icon(
            Icons.edit_calendar_outlined,
          ),
          label: const Text(
            'Atur Anggaran',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),

        const SizedBox(height: 13),

        // ===================================
        // 12. INFORMATION
        // ===================================

        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: _muted,
              size: 14,
            ),

            SizedBox(width: 6),

            Flexible(
              child: Text(
                'Anggaran adalah rencana; '
                'Kantong Tabungan adalah catatan saldo',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ==========================================
// METRIC CARD COMPONENT
// ==========================================

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.amount,
  });

  final IconData icon;
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: scheme.brightness == Brightness.dark
              ? Colors.white12
              : const Color(0xFFE5EFE8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =================================
          // ICON
          // =================================

          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: _softGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: _darkGreen,
              size: 20,
            ),
          ),

          const SizedBox(height: 12),

          // =================================
          // LABEL
          // =================================

          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 5),

          // =================================
          // AMOUNT
          // =================================

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(amount),
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}