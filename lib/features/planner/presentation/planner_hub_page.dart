import 'package:flutter/material.dart';

import '../../../core/money.dart';
import '../../../models/finance_plan.dart';
import '../../../widgets/savings_overview_card.dart';

// ============================================================
// PLANNER HUB PAGE
// ============================================================

class PlannerHubPage extends StatelessWidget {
  const PlannerHubPage({
    super.key,
    required this.plan,
    required this.onOpenBudget,
    required this.onOpenSalary,
    required this.onOpenJobs,
    required this.onOpenSavings,
    required this.onOpenSisaUang,
  });

  final FinancePlan plan;

  final VoidCallback onOpenBudget;
  final VoidCallback onOpenSalary;
  final VoidCallback onOpenJobs;
  final VoidCallback onOpenSavings;
  final VoidCallback onOpenSisaUang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // ========================================================
    // DAFTAR MENU PLANNER
    // ========================================================

    final items = <_PlannerMenuItem>[
      _PlannerMenuItem(
        icon: Icons.pie_chart_outline_rounded,
        title: 'Anggaran',
        description: 'Pembagian gaji',
        onTap: onOpenBudget,
      ),
      _PlannerMenuItem(
        icon: Icons.calculate_rounded,
        title: 'Kalkulator Gaji',
        description: 'Hitung pendapatan',
        onTap: onOpenSalary,
      ),
      _PlannerMenuItem(
        icon: Icons.work_outline_rounded,
        title: 'Tawaran Kerja',
        description: 'Bandingkan pilihan',
        onTap: onOpenJobs,
      ),
      _PlannerMenuItem(
        icon: Icons.savings_rounded,
        title: 'Kantong Tabungan',
        description: 'Kejar targetmu',
        onTap: onOpenSavings,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale =
            MediaQuery.textScalerOf(context).scale(16) / 16;

        final columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 480
                ? 2
                : (constraints.maxWidth < 345 || scale > 1.3)
                    ? 1
                    : 2;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            32,
          ),
          children: [
            // =================================================
            // HEADER
            // =================================================

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Atur Keuanganmu',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // =================================================
            // KARTU PENGHASILAN BULANAN
            // =================================================

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF064E3B),
                    Color(0xFF059669),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Penghasilan Bulanan',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white70,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      rupiah(plan.totalMonthlyIncome),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Icon(
                        Icons.flag_outlined,
                        color: Color(0xFFBBF7D0),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Target ideal: ${rupiah(plan.idealIncome)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // =================================================
            // SIMULASI SISA UANG
            // =================================================

            Material(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onOpenSisaUang,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.hourglass_bottom_rounded,
                          color: scheme.onPrimary,
                          size: 29,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Uang Sampai Gajian',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Simulasi sisa uangmu',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Icon(
                        Icons.arrow_forward_rounded,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // =================================================
            // RINGKASAN KANTONG TABUNGAN
            // =================================================

            SavingsOverviewCard(
              onOpenSavings: onOpenSavings,
            ),

            const SizedBox(height: 25),

            // =================================================
            // JELAJAHI FITUR
            // =================================================

            Text(
              'Jelajahi Fitur',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 14),

            // =================================================
            // GRID MENU
            // =================================================

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: columns == 1
                    ? (130 * scale)
                        .clamp(130.0, 195.0)
                        .toDouble()
                    : (175 * scale)
                        .clamp(175.0, 290.0)
                        .toDouble(),
              ),
              itemBuilder: (context, index) {
                final item = items[index];

                return _PlannerMenuTile(
                  item: item,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// MODEL MENU PLANNER
// ============================================================

class _PlannerMenuItem {
  const _PlannerMenuItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
}

// ============================================================
// TILE MENU PLANNER
// ============================================================

class _PlannerMenuTile extends StatelessWidget {
  const _PlannerMenuTile({
    required this.item,
  });

  final _PlannerMenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 156;

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(
                alpha: 0.5,
              ),
            ),
          ),
          child: InkWell(
            onTap: item.onTap,
            child: Padding(
              padding: EdgeInsets.all(
                compact ? 11 : 14,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: compact ? 43 : 48,
                        height: compact ? 43 : 48,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          item.icon,
                          size: compact ? 24 : 27,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        color: scheme.primary,
                        size: 18,
                      ),
                    ],
                  ),

                  const Spacer(),

                  Text(
                    item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: compact ? 12.5 : 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}