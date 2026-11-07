import 'package:flutter/material.dart';

import '../../../../core/money.dart';

// =====================================================
// FINPLAN - TRANSACTION SUMMARY CARD
// =====================================================

class TransactionSummaryCard extends StatelessWidget {
  const TransactionSummaryCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
  });

  final int totalIncome;
  final int totalExpense;
  final int transactionCount;

  static const Color _darkGreen = Color(0xFF064E3B);
  static const Color _green = Color(0xFF059669);
  static const Color _red = Color(0xFFEF4444);

  // =====================================================
  // CALCULATIONS
  // =====================================================

  int get netAmount => totalIncome - totalExpense;

  bool get isNegative => netAmount < 0;

  String _formatSignedMoney(int amount) {
    if (amount < 0) {
      return '-${rupiah(amount.abs())}';
    }

    return rupiah(amount);
  }

  // =====================================================
  // MAIN WIDGET
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBalanceCard(context),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _SummaryMiniCard(
                title: 'Pemasukan',
                amount: totalIncome,
                icon: Icons.south_west_rounded,
                color: _green,
                lightBackground: const Color(0xFFE4F7EE),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _SummaryMiniCard(
                title: 'Pengeluaran',
                amount: totalExpense,
                icon: Icons.north_east_rounded,
                color: _red,
                lightBackground: const Color(0xFFFDECEC),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =====================================================
  // BALANCE CARD
  // =====================================================

  Widget _buildBalanceCard(BuildContext context) {
    return Container(
      width: double.infinity,

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

        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Arus Kas Bersih',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),

              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // NET AMOUNT
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatSignedMoney(netAmount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // DESCRIPTION
          Text(
            _getBalanceDescription(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 20),

          // TRANSACTION COUNT
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),

            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(25),
            ),

            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.white,
                  size: 15,
                ),

                const SizedBox(width: 7),

                Text(
                  '$transactionCount transaksi bulan ini',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BALANCE DESCRIPTION
  // =====================================================

  String _getBalanceDescription() {
    if (transactionCount == 0) {
      return 'Belum ada transaksi yang tercatat.';
    }

    if (isNegative) {
      return 'Pengeluaran melebihi pemasukan bulan ini.';
    }

    if (netAmount == 0) {
      return 'Pemasukan dan pengeluaran bulan ini seimbang.';
    }

    return 'Selisih pemasukan dan pengeluaran bulan ini.';
  }
}

// =====================================================
// MINI SUMMARY CARD
// =====================================================

class _SummaryMiniCard extends StatelessWidget {
  const _SummaryMiniCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.lightBackground,
  });

  final String title;
  final int amount;
  final IconData icon;
  final Color color;
  final Color lightBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : lightBackground,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ICON
          Container(
            padding: const EdgeInsets.all(9),

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),

            child: Icon(
              icon,
              size: 22,
              color: color,
            ),
          ),

          const SizedBox(height: 12),

          // TITLE
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 6),

          // AMOUNT
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,

              child: Text(
                rupiah(amount),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}