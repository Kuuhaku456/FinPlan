import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/finance_plan.dart';
import 'finance_plan_notifier.dart';

// ============================================
// FINPLAN - SALARY CALCULATOR STATE MANAGEMENT
// ============================================

enum OfferPaymentMode {
  monthly,
  daily,
  hourly,
  session,
}

enum SalaryTier {
  s,
  a,
  b,
  c,
  d,
}

extension SalaryTierInfo on SalaryTier {
  String get label => switch (this) {
        SalaryTier.s => 'Sangat worth it',
        SalaryTier.a => 'Worth it',
        SalaryTier.b => 'Cukup worth it',
        SalaryTier.c => 'Pikirkan lagi',
        SalaryTier.d => 'Kurang worth it',
      };

  String get letter => name.toUpperCase();
}

// ============================================
// 1. INPUT STATE
// ============================================

class SalaryCalculatorDraft {
  SalaryCalculatorDraft({
    required Map<String, num> values,
    this.paymentMode = OfferPaymentMode.monthly,
    this.usePlannerNeeds = true,
    this.includePlannerOtherIncome = true,
    this.sameReturnTrip = false,
    this.careerRating = 3,
    this.workEnvironmentRating = 3,
    this.currentStep = 0,
    this.showResults = false,
  }) : values = Map<String, num>.unmodifiable(values);

  final Map<String, num> values;

  final OfferPaymentMode paymentMode;

  final bool usePlannerNeeds;
  final bool includePlannerOtherIncome;
  final bool sameReturnTrip;

  final int careerRating;
  final int workEnvironmentRating;

  final int currentStep;
  final bool showResults;

  num number(String field) => values[field] ?? 0;

  int money(String field) => number(field).round();

  SalaryCalculatorDraft copyWith({
    Map<String, num>? values,
    OfferPaymentMode? paymentMode,
    bool? usePlannerNeeds,
    bool? includePlannerOtherIncome,
    bool? sameReturnTrip,
    int? careerRating,
    int? workEnvironmentRating,
    int? currentStep,
    bool? showResults,
  }) {
    return SalaryCalculatorDraft(
      values: values ?? this.values,
      paymentMode: paymentMode ?? this.paymentMode,
      usePlannerNeeds: usePlannerNeeds ?? this.usePlannerNeeds,
      includePlannerOtherIncome:
          includePlannerOtherIncome ??
          this.includePlannerOtherIncome,
      sameReturnTrip: sameReturnTrip ?? this.sameReturnTrip,
      careerRating: careerRating ?? this.careerRating,
      workEnvironmentRating:
          workEnvironmentRating ??
          this.workEnvironmentRating,
      currentStep: currentStep ?? this.currentStep,
      showResults: showResults ?? this.showResults,
    );
  }
}

// ============================================
// 2. DEFAULT INPUT
// ============================================

Map<String, num> _initialFields(int salary) => {
      'rate': salary,
      'units': 22,

      'allowance': 0,
      'bonus': 0,
      'overtime': 0,
      'otherIncome': 0,
      'deductions': 0,

      'workDays': 22,
      'officeDays': 22,
      'workHours': 8,
      'daysPerWeek': 5,

      'goCost': 0,
      'returnCost': 0,

      'goMinutes': 0,
      'returnMinutes': 0,

      'goDistance': 0,
      'returnDistance': 0,

      'extraMeals': 0,
      'otherWorkCosts': 0,

      'targetRemaining': 0,
      'comfortableCommute': 120,

      'plannerTransportOutsideWork': 0,

      'manualHousing': 0,
      'manualFood': 0,
      'manualTransportOutsideWork': 0,
      'manualBills': 0,
      'manualPersonal': 0,
      'manualOther': 0,
      'manualSavings': 0,
      'manualBufferPercent': 10,
    };

// ============================================
// 3. NOTIFIER PROVIDER
// ============================================

final salaryCalculatorProvider =
    NotifierProvider.autoDispose<
        SalaryCalculatorNotifier,
        SalaryCalculatorDraft>(
  SalaryCalculatorNotifier.new,
);

class SalaryCalculatorNotifier
    extends Notifier<SalaryCalculatorDraft> {

  @override
  SalaryCalculatorDraft build() {
    final plan = ref.read(financePlanProvider);

    return SalaryCalculatorDraft(
      values: _initialFields(
        plan?.actualIncome ?? 0,
      ),
      usePlannerNeeds: plan != null,
    );
  }

  // Mengubah sebuah input.
  void setValue(String field, num value) {
    if (!state.values.containsKey(field)) return;

    final safeValue =
        value.isFinite && value >= 0 ? value : 0;

    final next = Map<String, num>.of(state.values)
      ..[field] = safeValue;

    // Jika perjalanan pulang disamakan dengan pergi.
    if (state.sameReturnTrip) {
      const pairs = {
        'goCost': 'returnCost',
        'goMinutes': 'returnMinutes',
        'goDistance': 'returnDistance',
      };

      final returnField = pairs[field];

      if (returnField != null) {
        next[returnField] = safeValue;
      }
    }

    state = state.copyWith(values: next);
  }

  // Jenis pembayaran gaji.
  void setPaymentMode(OfferPaymentMode mode) {
    state = state.copyWith(
      paymentMode: mode,
    );
  }

  // Gunakan kebutuhan dari Planner.
  void setUsePlannerNeeds(bool value) {
    state = state.copyWith(
      usePlannerNeeds: value,
    );
  }

  // Sertakan pemasukan tambahan dari Planner.
  void setIncludePlannerOtherIncome(bool value) {
    state = state.copyWith(
      includePlannerOtherIncome: value,
    );
  }

  // Samakan perjalanan pulang dan pergi.
  void setSameReturnTrip(bool value) {
    final next = Map<String, num>.of(state.values);

    if (value) {
      next['returnCost'] = next['goCost'] ?? 0;
      next['returnMinutes'] = next['goMinutes'] ?? 0;
      next['returnDistance'] = next['goDistance'] ?? 0;
    }

    state = state.copyWith(
      sameReturnTrip: value,
      values: next,
    );
  }

  // Penilaian prospek karier.
  void setCareerRating(int rating) {
    state = state.copyWith(
      careerRating: rating.clamp(1, 5).toInt(),
    );
  }

  // Penilaian kenyamanan lingkungan kerja.
  void setWorkEnvironmentRating(int rating) {
    state = state.copyWith(
      workEnvironmentRating:
          rating.clamp(1, 5).toInt(),
    );
  }

  // Navigasi langkah pengisian.
  void setStep(int step) {
    state = state.copyWith(
      currentStep: step.clamp(0, 5).toInt(),
    );
  }

  // Menampilkan hasil analisis.
  void setShowResults(bool value) {
    state = state.copyWith(
      showResults: value,
    );
  }

  // Mengembalikan input ke kondisi awal.
  void reset() {
    final plan = ref.read(financePlanProvider);

    state = SalaryCalculatorDraft(
      values: _initialFields(
        plan?.actualIncome ?? 0,
      ),
      usePlannerNeeds: plan != null,
    );
  }
}

// ============================================
// 4. USER MONTHLY NEEDS
// ============================================

class SalaryNeeds {
  const SalaryNeeds({
    required this.ready,
    required this.fromPlanner,
    required this.housing,
    required this.food,
    required this.transportOutsideWork,
    required this.bills,
    required this.personal,
    required this.other,
    required this.savings,
    required this.bufferPercent,
    required this.otherIncome,
  });

  final bool ready;
  final bool fromPlanner;

  final int housing;
  final int food;
  final int transportOutsideWork;
  final int bills;
  final int personal;
  final int other;

  final int savings;
  final int bufferPercent;
  final int otherIncome;

  int get livingCosts =>
      housing +
      food +
      transportOutsideWork +
      bills +
      personal +
      other;

  factory SalaryNeeds.from(
    SalaryCalculatorDraft draft,
    FinancePlan? plan,
  ) {
    // ========================================
    // KEBUTUHAN DARI FINPLAN PLANNER
    // ========================================

    if (draft.usePlannerNeeds && plan != null) {
      return SalaryNeeds(
        ready: true,
        fromPlanner: true,

        housing: plan.housing,
        food: plan.food,

        // Biaya transportasi pekerjaan baru
        // dihitung dari data kalkulator gaji.
        // Transportasi di sini hanya untuk
        // kebutuhan di luar pekerjaan.
        transportOutsideWork:
            draft.money('plannerTransportOutsideWork'),

        bills: plan.bills,
        personal: plan.personal,
        other: plan.monthlyCustomExpenses,

        savings: plan.savings,

        bufferPercent:
            plan.bufferPercent.clamp(0, 100).toInt(),

        otherIncome:
            draft.includePlannerOtherIncome
                ? plan.monthlyAdditionalIncome
                : 0,
      );
    }

    // ========================================
    // KEBUTUHAN MANUAL
    // ========================================

    final housing = draft.money('manualHousing');
    final food = draft.money('manualFood');

    final transport =
        draft.money('manualTransportOutsideWork');

    final bills = draft.money('manualBills');
    final personal = draft.money('manualPersonal');
    final other = draft.money('manualOther');

    final savings = draft.money('manualSavings');

    final total =
        housing +
        food +
        transport +
        bills +
        personal +
        other +
        savings;

    return SalaryNeeds(
      ready: total > 0,
      fromPlanner: false,

      housing: housing,
      food: food,
      transportOutsideWork: transport,
      bills: bills,
      personal: personal,
      other: other,

      savings: savings,

      bufferPercent:
          draft.money('manualBufferPercent')
              .clamp(0, 100)
              .toInt(),

      otherIncome: 0,
    );
  }
}

// ============================================
// 5. SALARY ANALYSIS RESULT
// ============================================

class SalaryAnalysis {
  const SalaryAnalysis({
    required this.baseSalary,
    required this.grossSalary,
    required this.takeHomePay,
    required this.monthlyTransport,
    required this.monthlyMeals,
    required this.monthlyWorkCosts,
    required this.remainingAfterWork,
    required this.monthlyCommuteHours,
    required this.monthlyDistance,
    required this.committedHours,
    required this.effectiveHourlyIncome,
    required this.needs,
    required this.combinedIncome,
    required this.budgetReserve,
    required this.budgetRequired,
    required this.afterNeeds,
    required this.afterSavings,
    required this.afterBuffer,
    required this.finalSurplus,
    required this.financialScore,
    required this.travelScore,
    required this.balanceScore,
    required this.careerScore,
    required this.environmentScore,
    required this.score,
    required this.tier,
    required this.tierReason,
  });

  // Penghasilan.
  final int baseSalary;
  final int grossSalary;
  final int takeHomePay;

  // Biaya pekerjaan.
  final int monthlyTransport;
  final int monthlyMeals;
  final int monthlyWorkCosts;

  // Efektivitas pendapatan.
  final int remainingAfterWork;
  final double monthlyCommuteHours;
  final double monthlyDistance;
  final double committedHours;
  final int effectiveHourlyIncome;

  // Kebutuhan pengguna.
  final SalaryNeeds needs;
  final int combinedIncome;

  // Perbandingan anggaran.
  final int budgetReserve;
  final int budgetRequired;

  final int afterNeeds;
  final int afterSavings;
  final int afterBuffer;
  final int finalSurplus;

  // Komponen penilaian.
  final int? financialScore;
  final int? travelScore;
  final int? balanceScore;
  final int? careerScore;
  final int? environmentScore;

  final int? score;
  final SalaryTier? tier;
  final String? tierReason;

  bool get budgetReady => needs.ready;

  bool get isWorthConsidering =>
      tier == SalaryTier.s ||
      tier == SalaryTier.a ||
      tier == SalaryTier.b;

  // ========================================
  // 6. MAIN CALCULATION
  // ========================================

  static SalaryAnalysis calculate(
    SalaryCalculatorDraft d,
    SalaryNeeds needs,
  ) {
    // --------------------------------------
    // GAJI
    // --------------------------------------

    final rate = d.money('rate');

    final baseSalary =
        d.paymentMode == OfferPaymentMode.monthly
            ? rate
            : (rate * d.number('units')).round();

    final grossSalary =
        baseSalary +
        d.money('allowance') +
        d.money('bonus') +
        d.money('overtime') +
        d.money('otherIncome');

    final takeHomePay =
        grossSalary - d.money('deductions');

    // --------------------------------------
    // JADWAL KERJA
    // --------------------------------------

    final workDays =
        d.number('workDays')
            .round()
            .clamp(0, 31)
            .toInt();

    final officeDays =
        d.number('officeDays')
            .round()
            .clamp(0, workDays)
            .toInt();

    // --------------------------------------
    // BIAYA KERJA
    // --------------------------------------

    final monthlyTransport =
        (d.money('goCost') + d.money('returnCost')) *
        officeDays;

    final monthlyMeals =
        d.money('extraMeals') * officeDays;

    final monthlyWorkCosts =
        monthlyTransport +
        monthlyMeals +
        d.money('otherWorkCosts');

    final remainingAfterWork =
        takeHomePay - monthlyWorkCosts;

    // --------------------------------------
    // WAKTU DAN JARAK
    // --------------------------------------

    final dailyCommute =
        d.number('goMinutes') +
        d.number('returnMinutes');

    final monthlyCommuteHours =
        dailyCommute * officeDays / 60;

    final committedHours =
        workDays * d.number('workHours') +
        monthlyCommuteHours;

    final effectiveHourlyIncome =
        committedHours > 0
            ? (remainingAfterWork / committedHours).round()
            : 0;

    final monthlyDistance =
        (d.number('goDistance') +
         d.number('returnDistance')) *
        officeDays;

    // --------------------------------------
    // ANGGARAN KEUANGAN
    // --------------------------------------

    final combinedIncome =
        takeHomePay + needs.otherIncome;

    final reserveBase =
        needs.livingCosts +
        monthlyWorkCosts +
        needs.savings;

    final budgetReserve =
        (reserveBase * needs.bufferPercent + 99) ~/ 100;

    final target = d.money('targetRemaining');

    final budgetRequired =
        reserveBase +
        budgetReserve +
        target;

    final afterNeeds =
        combinedIncome -
        monthlyWorkCosts -
        needs.livingCosts;

    final afterSavings =
        afterNeeds - needs.savings;

    final afterBuffer =
        afterSavings - budgetReserve;

    final finalSurplus =
        afterBuffer - target;

    // --------------------------------------
    // SKOR KELAYAKAN PEKERJAAN
    // --------------------------------------

    int? financialScore;
    int? travelScore;
    int? balanceScore;
    int? careerScore;
    int? environmentScore;
    int? score;

    SalaryTier? tier;
    String? tierReason;

    if (grossSalary > 0 && needs.ready) {

      // 1. KEUANGAN
      // Maksimal 50 poin.

      financialScore =
          afterNeeds < 0
              ? 0
              : finalSurplus >=
                      (budgetRequired * 0.2).ceil()
                  ? 50
                  : finalSurplus >= 0
                      ? 44
                      : afterBuffer >= 0
                          ? 36
                          : afterSavings >= 0
                              ? 27
                              : 15;

      // 2. PERJALANAN
      // Maksimal 20 poin.

      final comfortable =
          d.number('comfortableCommute');

      travelScore =
          officeDays == 0
              ? 20
              : comfortable <= 0
                  ? 0
                  : dailyCommute <= comfortable
                      ? 20
                      : dailyCommute <= comfortable * 1.5
                          ? 12
                          : 4;

      // 3. WORK-LIFE BALANCE
      // Maksimal 10 poin.

      final weeklyHours =
          d.number('workHours') *
          d.number('daysPerWeek');

      balanceScore =
          weeklyHours <= 40
              ? 10
              : weeklyHours <= 48
                  ? 6
                  : 2;

      // 4. PROSPEK KARIER
      // Maksimal 10 poin.

      careerScore = d.careerRating * 2;

      // 5. KENYAMANAN KERJA
      // Maksimal 10 poin.

      environmentScore =
          d.workEnvironmentRating * 2;

      // TOTAL MAKSIMAL 100

      score =
          financialScore +
          travelScore +
          balanceScore +
          careerScore +
          environmentScore;

      // ------------------------------------
      // TIER PENAWARAN PEKERJAAN
      // ------------------------------------

      // Gaji pekerjaan tidak cukup
      // untuk menutupi biaya kerjanya.
      if (remainingAfterWork <= 0) {
        tier = SalaryTier.d;

        tierReason =
            'Gaji dari pekerjaan ini habis '
            'untuk biaya bekerja.';

      // Kebutuhan dasar belum terpenuhi.
      } else if (afterNeeds < 0) {
        tier = SalaryTier.d;

        tierReason =
            'Penghasilan belum menutupi '
            'kebutuhan hidup dan biaya kerja.';

      } else {

        // Tier berdasarkan skor utama.
        tier =
            score >= 90
                ? SalaryTier.s
                : score >= 80
                    ? SalaryTier.a
                    : score >= 65
                        ? SalaryTier.b
                        : score >= 50
                            ? SalaryTier.c
                            : SalaryTier.d;

        // Target tabungan belum terpenuhi.
        if (afterSavings < 0 &&
            tier.index < SalaryTier.c.index) {

          tier = SalaryTier.c;

          tierReason =
              'Target tabungan belum terpenuhi. '
              'Tier maksimal C.';

        // Cadangan atau uang bebas kurang.
        } else if (
            finalSurplus < 0 &&
            tier.index < SalaryTier.b.index) {

          tier = SalaryTier.b;

          tierReason =
              'Dana cadangan atau target uang '
              'bebas belum terpenuhi. '
              'Tier maksimal B.';

        // Tier S memerlukan ruang finansial besar.
        } else if (
            financialScore != 50 &&
            tier == SalaryTier.s) {

          tier = SalaryTier.a;

          tierReason =
              'Ruang uang bebas belum cukup besar '
              'untuk Tier S. Tier maksimal A.';
        }
      }
    }

    // --------------------------------------
    // HASIL AKHIR
    // --------------------------------------

    return SalaryAnalysis(
      baseSalary: baseSalary,
      grossSalary: grossSalary,
      takeHomePay: takeHomePay,

      monthlyTransport: monthlyTransport,
      monthlyMeals: monthlyMeals,
      monthlyWorkCosts: monthlyWorkCosts,

      remainingAfterWork: remainingAfterWork,
      monthlyCommuteHours: monthlyCommuteHours,

      monthlyDistance:
          monthlyDistance.toDouble(),

      committedHours:
          committedHours.toDouble(),

      effectiveHourlyIncome:
          effectiveHourlyIncome,

      needs: needs,
      combinedIncome: combinedIncome,

      budgetReserve: budgetReserve,
      budgetRequired: budgetRequired,

      afterNeeds: afterNeeds,
      afterSavings: afterSavings,
      afterBuffer: afterBuffer,
      finalSurplus: finalSurplus,

      financialScore: financialScore,
      travelScore: travelScore,
      balanceScore: balanceScore,
      careerScore: careerScore,
      environmentScore: environmentScore,

      score: score,
      tier: tier,
      tierReason: tierReason,
    );
  }
}

// ============================================
// 7. AUTOMATIC ANALYSIS PROVIDER
// ============================================

final salaryAnalysisProvider =
    Provider.autoDispose<SalaryAnalysis>((ref) {

  // Input kalkulator.
  final draft = ref.watch(salaryCalculatorProvider);

  // Data kebutuhan dari Planner.
  final plan = ref.watch(financePlanProvider);

  // Menggabungkan data kebutuhan.
  final needs = SalaryNeeds.from(draft, plan);

  // Menghasilkan analisis pekerjaan.
  return SalaryAnalysis.calculate(draft, needs);
});