import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/finance_plan.dart';
import '../../../state/finance_plan_notifier.dart';

// =====================================================
// ALLOCATION MODEL
// =====================================================

@immutable
class AllocationSlice {
  const AllocationSlice({
    required this.name,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String name;
  final int amount;
  final Color color;
  final IconData icon;
}

// =====================================================
// DASHBOARD ALLOCATION MODEL
// =====================================================

@immutable
class DashboardAllocation {
  const DashboardAllocation({
    required this.slices,
    required this.chartTotal,
    required this.topIndices,
  });

  final List<AllocationSlice> slices;
  final int chartTotal;
  final List<int> topIndices;

  String percentage(int amount) {
    if (chartTotal <= 0) return '0%';

    return '${(amount / chartTotal * 100).toStringAsFixed(1)}%';
  }
}

// =====================================================
// ALLOCATION COLORS
// =====================================================

const _allocationColors = <Color>[
  Color(0xFF059669),
  Color(0xFF34D399),
  Color(0xFF0D9488),
  Color(0xFF84CC16),
  Color(0xFF0F766E),
  Color(0xFF86BBA8),
  Color(0xFF14B8A6),
  Color(0xFF65A30D),
  Color(0xFF6B9E8D),
];

// =====================================================
// DASHBOARD CALCULATION
// =====================================================

DashboardAllocation calculateDashboardAllocation(
  FinancePlan plan,
) {
  final slices = <AllocationSlice>[];

  void add(
    String name,
    int amount,
    IconData icon,
  ) {
    if (amount <= 0) return;

    slices.add(
      AllocationSlice(
        name: name,
        amount: amount,
        color: _allocationColors[
          slices.length % _allocationColors.length
        ],
        icon: icon,
      ),
    );
  }

  // Kebutuhan utama
  add(
    'Tempat Tinggal',
    plan.housing,
    Icons.home_outlined,
  );

  add(
    'Makanan',
    plan.food,
    Icons.restaurant_outlined,
  );

  add(
    'Transportasi',
    plan.transport,
    Icons.train_outlined,
  );

  add(
    'Tagihan',
    plan.bills,
    Icons.receipt_long_outlined,
  );

  add(
    'Kebutuhan Pribadi',
    plan.personal,
    Icons.shopping_bag_outlined,
  );

  // Kebutuhan tambahan pengguna
  for (final expense in plan.customExpenses) {
    add(
      expense.name.trim().isEmpty
          ? 'Kebutuhan Lainnya'
          : expense.name,
      expense.monthlyAmount,
      Icons.category_outlined,
    );
  }

  // Tabungan dan cadangan
  add(
    'Tabungan',
    plan.savings,
    Icons.savings_outlined,
  );

  add(
    'Dana Cadangan',
    plan.buffer,
    Icons.shield_outlined,
  );

  // Dana yang belum dialokasikan
  if (plan.plannedDifference > 0) {
    slices.add(
      AllocationSlice(
        name: 'Belum Dialokasikan',
        amount: plan.plannedDifference,
        color: const Color(0xFFCBD5D1),
        icon: Icons.account_balance_wallet_outlined,
      ),
    );
  }

  // Urutkan kategori berdasarkan nominal terbesar
  final ranked = List<int>.generate(
    slices.length,
    (index) => index,
  );

  ranked.sort(
    (a, b) => slices[b].amount.compareTo(
      slices[a].amount,
    ),
  );

  return DashboardAllocation(
    slices: List<AllocationSlice>.unmodifiable(slices),
    chartTotal: math.max(
      plan.totalMonthlyIncome,
      plan.idealIncome,
    ),
    topIndices: List<int>.unmodifiable(
      ranked.take(3),
    ),
  );
}

// =====================================================
// DASHBOARD ALLOCATION PROVIDER
// =====================================================

final dashboardAllocationProvider =
    Provider<DashboardAllocation?>((ref) {
  final plan = ref.watch(financePlanProvider);

  if (plan == null) return null;

  return calculateDashboardAllocation(plan);
});

// =====================================================
// SELECTED CATEGORY PROVIDER
// =====================================================

final dashboardSelectedCategoryProvider =
    NotifierProvider<
      DashboardSelectedCategoryNotifier,
      int?
    >(
      DashboardSelectedCategoryNotifier.new,
    );

// =====================================================
// SELECTED CATEGORY NOTIFIER
// =====================================================

class DashboardSelectedCategoryNotifier
    extends Notifier<int?> {
  @override
  int? build() {
    // Reset kategori ketika FinancePlan berubah.
    ref.watch(financePlanProvider);

    return null;
  }

  void toggle(int index) {
    final allocation = ref.read(
      dashboardAllocationProvider,
    );

    if (allocation == null ||
        index < 0 ||
        index >= allocation.slices.length) {
      return;
    }

    state = state == index ? null : index;
  }

  void clear() {
    state = null;
  }
}