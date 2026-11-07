import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/finance_plan.dart';
import '../../../state/finance_plan_notifier.dart';

// =====================================================
// PLANNER CATEGORY TYPE
// =====================================================

enum PlannerCategoryType {
  housing,
  food,
  transport,
  bills,
  personal,
  savings,
  custom,
  other,
  buffer,
}

// =====================================================
// PLANNER BUDGET CATEGORY MODEL
// =====================================================

class PlannerBudgetCategory {
  const PlannerBudgetCategory({
    required this.type,
    required this.title,
    required this.amount,
  });

  final PlannerCategoryType type;
  final String title;
  final int amount;
}

// =====================================================
// PLANNER OVERVIEW MODEL
// =====================================================

class PlannerOverview {
  const PlannerOverview({
    required this.income,
    required this.budget,
    required this.remaining,
    required this.needs,
    required this.savings,
    required this.buffer,
    required this.canFundPlan,
    required this.progress,
    required this.allocationPercentage,
    required this.categories,
  });

  // ===============================================
  // FINANCIAL VALUES
  // ===============================================

  final int income;
  final int budget;
  final int remaining;
  final int needs;
  final int savings;
  final int buffer;

  // ===============================================
  // FINANCIAL STATUS
  // ===============================================

  final bool canFundPlan;

  final double progress;

  final double allocationPercentage;

  // ===============================================
  // BUDGET CATEGORIES
  // ===============================================

  final List<PlannerBudgetCategory> categories;

  // ===============================================
  // COMPUTED GETTERS
  // ===============================================

  String get remainingLabel {
    return remaining >= 0
        ? 'Sisa'
        : 'Kekurangan';
  }

  int get remainingAbsolute {
    return remaining.abs();
  }

  // ===============================================
  // CATEGORY PERCENTAGE
  // ===============================================

  double categoryPercentage(int amount) {
    if (budget <= 0) return 0.0;

    return amount / budget * 100;
  }

  // ===============================================
  // CATEGORY PROGRESS
  // ===============================================

  double categoryProgress(int amount) {
    if (budget <= 0) return 0.0;

    return (amount / budget)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

// =====================================================
// PLANNER CALCULATION SERVICE
// =====================================================

PlannerOverview calculatePlannerOverview(
  FinancePlan plan,
) {
  // ===============================================
  // INCOME & BUDGET
  // ===============================================

  final income = plan.totalMonthlyIncome;

  final budget = plan.idealIncome;

  final remaining = plan.plannedDifference;

  // ===============================================
  // BUDGET CATEGORIES
  // ===============================================

  final categories = <PlannerBudgetCategory>[
    PlannerBudgetCategory(
      type: PlannerCategoryType.housing,
      title: 'Tempat Tinggal',
      amount: plan.housing,
    ),

    PlannerBudgetCategory(
      type: PlannerCategoryType.food,
      title: 'Makan',
      amount: plan.food,
    ),

    PlannerBudgetCategory(
      type: PlannerCategoryType.transport,
      title: 'Transportasi',
      amount: plan.transport,
    ),

    PlannerBudgetCategory(
      type: PlannerCategoryType.bills,
      title: 'Tagihan',
      amount: plan.bills,
    ),

    PlannerBudgetCategory(
      type: PlannerCategoryType.personal,
      title: 'Kebutuhan Pribadi',
      amount: plan.personal,
    ),

    PlannerBudgetCategory(
      type: PlannerCategoryType.savings,
      title: 'Tabungan',
      amount: plan.savings,
    ),
  ];

  // ===============================================
  // CUSTOM EXPENSES
  // ===============================================

  for (final expense in plan.customExpenses) {
    if (expense.monthlyAmount <= 0) {
      continue;
    }

    categories.add(
      PlannerBudgetCategory(
        type: PlannerCategoryType.custom,

        title: expense.name.trim().isEmpty
            ? 'Kebutuhan Lain'
            : expense.name,

        amount: expense.monthlyAmount,
      ),
    );
  }

  // ===============================================
  // OTHER EXPENSES
  // ===============================================

  final allocated = categories.fold<int>(
    0,
    (total, category) {
      return total + category.amount;
    },
  );

  final other = plan.minimumIncome - allocated;

  if (other > 0) {
    categories.add(
      PlannerBudgetCategory(
        type: PlannerCategoryType.other,
        title: 'Lainnya',
        amount: other,
      ),
    );
  }

  // ===============================================
  // EMERGENCY BUFFER
  // ===============================================

  if (plan.buffer > 0) {
    categories.add(
      PlannerBudgetCategory(
        type: PlannerCategoryType.buffer,
        title: 'Dana Cadangan',
        amount: plan.buffer,
      ),
    );
  }

  // ===============================================
  // FILTER VISIBLE CATEGORIES
  // ===============================================

  final visibleCategories = categories
      .where(
        (category) => category.amount > 0,
      )
      .toList(growable: false);

  // ===============================================
  // CALCULATE PROGRESS
  // ===============================================

  final progress = income <= 0
      ? 0.0
      : (budget / income)
          .clamp(0.0, 1.0)
          .toDouble();

  final allocationPercentage = income <= 0
      ? 0.0
      : budget / income * 100;

  // ===============================================
  // RETURN PLANNER OVERVIEW
  // ===============================================

  return PlannerOverview(
    income: income,
    budget: budget,
    remaining: remaining,

    needs: plan.expenses,
    savings: plan.savings,
    buffer: plan.buffer,

    canFundPlan: plan.canFundPlan,

    progress: progress,

    allocationPercentage:
        allocationPercentage,

    categories:
        List<PlannerBudgetCategory>.unmodifiable(
      visibleCategories,
    ),
  );
}

// =====================================================
// PLANNER OVERVIEW RIVERPOD PROVIDER
// =====================================================

final plannerOverviewProvider =
    Provider<PlannerOverview?>((ref) {
  final plan = ref.watch(
    financePlanProvider,
  );

  if (plan == null) {
    return null;
  }

  return calculatePlannerOverview(plan);
});