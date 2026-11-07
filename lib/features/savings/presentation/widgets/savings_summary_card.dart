import 'package:flutter/material.dart';

import '../../../../core/money.dart';
import '../../../../data/savings_repository.dart';

// =====================================================
// FINPLAN - SAVINGS SUMMARY CARD
// =====================================================

class SavingsSummaryCard extends StatelessWidget {
  const SavingsSummaryCard({
    super.key,
    required this.summary,
  });

  final SavingsSummary summary;

  // =====================================================
  // COLORS
  // =====================================================

  static const Color _darkGreen = Color(0xFF064E3B);
  static const Color _green = Color(0xFF059669);
  static const Color _mint = Color(0xFFA7F3D0);

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),

        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [
            _darkGreen,
            _green,
          ],
        ),

        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // =================================================
          // HEADER
          // =================================================

          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white70,
                size: 20,
              ),

              SizedBox(width: 8),

              Text(
                'Total Tabungan',

                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          // =================================================
          // TOTAL SAVED
          // =================================================

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,

            child: Text(
              rupiah(summary.totalSaved),

              style: const TextStyle(
                color: Colors.white,
                fontSize: 31,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 7),

          // =================================================
          // TOTAL TARGET
          // =================================================

          Text(
            'Target ${rupiah(summary.totalTarget)}',

            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 23),

          // =================================================
          // PROGRESS HEADER
          // =================================================

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progress Keseluruhan',

                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),

              Text(
                '${summary.progressPercent.toStringAsFixed(1)}%',

                style: const TextStyle(
                  color: _mint,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          // =================================================
          // PROGRESS BAR
          // =================================================

          ClipRRect(
            borderRadius: BorderRadius.circular(20),

            child: LinearProgressIndicator(
              value: summary.progress
                  .clamp(0.0, 1.0)
                  .toDouble(),

              minHeight: 10,

              backgroundColor: Colors.white24,

              color: _mint,
            ),
          ),

          const SizedBox(height: 23),

          const Divider(
            color: Colors.white24,
          ),

          const SizedBox(height: 12),

          // =================================================
          // SUMMARY METRICS
          // =================================================

          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  icon: Icons.savings_outlined,
                  value: '${summary.activeGoals}',
                  label: 'Kantong Aktif',
                ),
              ),

              Container(
                width: 1,
                height: 38,
                color: Colors.white24,
              ),

              Expanded(
                child: _buildMetric(
                  icon: Icons.emoji_events_outlined,
                  value: '${summary.completedGoals}',
                  label: 'Target Tercapai',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SUMMARY METRIC
  // =====================================================

  Widget _buildMetric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              size: 19,
              color: _mint,
            ),

            const SizedBox(width: 7),

            Text(
              value,

              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        Text(
          label,

          textAlign: TextAlign.center,

          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}