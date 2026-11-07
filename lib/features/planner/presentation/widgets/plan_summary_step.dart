import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../providers/plan_editor_provider.dart';
import 'plan_editor_fields.dart';

// =====================================================
// COLORS
// =====================================================

const _darkGreen = Color(0xFF064E3B);
const _green = Color(0xFF059669);
const _mint = Color(0xFFD1FAE5);

// =====================================================
// PLAN SUMMARY STEP
// =====================================================

class PlanSummaryStep extends ConsumerWidget {
  const PlanSummaryStep({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    // =================================================
    // RIVERPOD STATE
    // =================================================

    final draft = ref.watch(
      planEditorProvider,
    );

    final plan = draft.toFinancePlan();

    final scheme = Theme.of(context).colorScheme;

    final income = plan.totalMonthlyIncome;
    final budget = plan.idealIncome;

    final utilization = income <= 0
        ? 0.0
        : (budget / income)
            .clamp(0.0, 1.0)
            .toDouble();

    // =================================================
    // UI
    // =================================================

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // =============================================
        // KARTU RINGKASAN UTAMA
        // =============================================

        Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                _darkGreen,
                _green,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, ${plan.name}! 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Rekomendasi Penghasilan',
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
                  rupiah(budget),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ========================================
              // PROGRESS ANGGARAN
              // ========================================

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: utilization,
                  minHeight: 9,
                  backgroundColor: Colors.white24,
                  color: _mint,
                ),
              ),

              const SizedBox(height: 11),

              Text(
                plan.canFundPlan
                    ? '✅ Anggaran sesuai penghasilan'
                    : '⚠️ Anggaran perlu disesuaikan',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // =============================================
        // RINGKASAN PEMASUKAN DAN SELISIH
        // =============================================

        Row(
          children: [
            PlanEditorMetricCard(
              label: 'Pemasukan',
              amount: income,
              icon: Icons.trending_up_rounded,
              color: scheme.primary,
            ),

            const SizedBox(width: 10),

            PlanEditorMetricCard(
              label: 'Selisih',
              amount: plan.plannedDifference,
              icon: Icons.balance_rounded,
              color: plan.canFundPlan
                  ? scheme.primary
                  : scheme.error,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // =============================================
        // ALOKASI BULANAN
        // =============================================

        PlanEditorSectionCard(
          title: 'Alokasi Bulanan',
          icon: Icons.pie_chart_outline_rounded,
          children: [
            _SummaryRow(
              'Tempat Tinggal',
              plan.housing,
            ),

            _SummaryRow(
              'Makan',
              plan.food,
            ),

            _SummaryRow(
              'Transportasi',
              plan.transport,
            ),

            _SummaryRow(
              'Tagihan',
              plan.bills,
            ),

            _SummaryRow(
              'Pribadi',
              plan.personal,
            ),

            _SummaryRow(
              'Kebutuhan Custom',
              plan.monthlyCustomExpenses,
            ),

            const Divider(),

            _SummaryRow(
              'Total Kebutuhan',
              plan.expenses,
            ),

            _SummaryRow(
              'Tabungan',
              plan.savings,
            ),

            _SummaryRow(
              'Dana Cadangan',
              plan.buffer,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // =============================================
        // STATUS RENCANA
        // =============================================

        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: plan.canFundPlan
                ? scheme.primaryContainer
                : scheme.errorContainer,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              Icon(
                plan.canFundPlan
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: plan.canFundPlan
                    ? scheme.onPrimaryContainer
                    : scheme.onErrorContainer,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  plan.canFundPlan
                      ? 'Rencana siap digunakan.'
                      : 'Rencana tetap bisa disimpan '
                          'dan disesuaikan nanti.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: plan.canFundPlan
                        ? scheme.onPrimaryContainer
                        : scheme.onErrorContainer,
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
// SUMMARY ROW
// =====================================================

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
    this.label,
    this.amount,
  );

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
          ),

          const SizedBox(width: 12),

          Text(
            rupiah(amount),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}