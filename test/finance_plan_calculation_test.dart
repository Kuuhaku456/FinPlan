import 'package:flutter_test/flutter_test.dart';

import '../lib/models/finance_plan.dart';

// =====================================================
// FINPLAN - FINANCE PLAN CALCULATION TEST
// =====================================================
//
// Menguji:
// 1. Konversi anggaran menjadi estimasi bulanan.
// 2. Perhitungan anggaran makan.
// 3. Perhitungan transportasi kombinasi.
// 4. Pemasukan utama dan tambahan.
// 5. Kebutuhan custom.
// 6. Dana cadangan dan rekomendasi gaji.
// 7. Penyimpanan dan pembacaan ulang data Planner.
//
// Semua nominal menggunakan Rupiah.
// =====================================================

// Membuat FinancePlan dasar untuk pengujian.
FinancePlan _createPlan({
  int actualIncome = 6000000,
  int bufferPercent = 10,
  List<IncomeSource> additionalIncomes = const [],
  Map<int, int> foodByWeekday = const {},
  List<DailyTransport> transportByWeekday = const [],
  List<CustomExpense> customExpenses = const [],
}) {
  return FinancePlan(
    name: 'Pengguna FinPlan',
    actualIncome: actualIncome,
    housing: 1000000,
    food: 650000,
    transport: 250000,
    bills: 300000,
    personal: 200000,
    savings: 1000000,
    bufferPercent: bufferPercent,
    additionalIncomes: additionalIncomes,
    foodByWeekday: foodByWeekday,
    transportByWeekday: transportByWeekday,
    customExpenses: customExpenses,
  );
}

void main() {
  // ===================================================
  // TEST 1: KONVERSI FREKUENSI
  // ===================================================

  test(
    'Konversi mingguan, bulanan, dan tahunan sudah benar',
    () {
      expect(
        monthlyEstimate(
          100000,
          BudgetFrequency.weekly,
        ),
        433334,
      );

      expect(
        monthlyEstimate(
          500000,
          BudgetFrequency.monthly,
        ),
        500000,
      );

      expect(
        monthlyEstimate(
          1200000,
          BudgetFrequency.yearly,
        ),
        100000,
      );
    },
  );

  // ===================================================
  // TEST 2: ANGGARAN MAKAN
  // ===================================================

  test(
    'Anggaran makan mengikuti kebutuhan setiap hari',
    () {
      final plan = _createPlan(
        foodByWeekday: {
          1: 25000, // Senin
          2: 25000, // Selasa
          3: 25000, // Rabu
          4: 25000, // Kamis
          5: 25000, // Jumat
          6: 25000, // Sabtu
          7: 0,     // Minggu
        },
      );

      // Total anggaran makan per minggu.
      expect(plan.weeklyFoodTotal, 150000);

      // Estimasi rata-rata bulanan: 150.000 x 52 / 12.
      expect(plan.food, 650000);
    },
  );

  // ===================================================
  // TEST 3: TRANSPORTASI KOMBINASI
  // ===================================================

  test(
    'Transportasi pergi dan pulang dihitung secara terpisah',
    () {
      final monday = DailyTransport(
        weekday: 1,
        outbound: [
          TransportLeg(
            mode: 'KRL',
            cost: 3000,
          ),
          TransportLeg(
            mode: 'TransJakarta',
            cost: 3500,
          ),
        ],
        returnTrip: [
          TransportLeg(
            mode: 'KRL',
            cost: 3000,
          ),
        ],
      );

      final sunday = DailyTransport(
        weekday: 7,
        outbound: const [],
        returnTrip: [
          TransportLeg(
            mode: 'TransJakarta',
            cost: 3500,
          ),
        ],
      );

      final plan = _createPlan(
        transportByWeekday: [
          monday,
          sunday,
        ],
      );

      // Senin: pergi Rp6.500, pulang Rp3.000.
      expect(monday.outboundTotal, 6500);
      expect(monday.returnTotal, 3000);
      expect(monday.dailyTotal, 9500);

      // Minggu: hanya perjalanan pulang.
      expect(sunday.outboundTotal, 0);
      expect(sunday.returnTotal, 3500);
      expect(sunday.dailyTotal, 3500);

      // Total biaya transportasi mingguan.
      expect(plan.weeklyTransportTotal, 13000);

      // Estimasi rata-rata bulanan.
      expect(plan.transport, 56334);
    },
  );

  // ===================================================
  // TEST 4: PEMASUKAN TAMBAHAN
  // ===================================================

  test(
    'Penghasilan tambahan dihitung sesuai frekuensinya',
    () {
      final plan = _createPlan(
        actualIncome: 5000000,
        additionalIncomes: [
          IncomeSource(
            name: 'Freelance',
            amount: 1000000,
            frequency: BudgetFrequency.monthly,
          ),
          IncomeSource(
            name: 'Bonus Tahunan',
            amount: 1200000,
            frequency: BudgetFrequency.yearly,
          ),
          IncomeSource(
            name: 'Penghasilan Mingguan',
            amount: 120000,
            frequency: BudgetFrequency.weekly,
          ),
        ],
      );

      // Freelance: 1.000.000
      // Bonus tahunan: 100.000
      // Penghasilan mingguan: 520.000
      expect(plan.monthlyAdditionalIncome, 1620000);

      // Gaji utama + pemasukan tambahan.
      expect(plan.totalMonthlyIncome, 6620000);
    },
  );

  // ===================================================
  // TEST 5: KEBUTUHAN CUSTOM
  // ===================================================

  test(
    'Kebutuhan custom ikut dihitung dalam total pengeluaran',
    () {
      final plan = _createPlan(
        customExpenses: [
          CustomExpense(
            name: 'Perpuluhan',
            amount: 500000,
            frequency: BudgetFrequency.monthly,
          ),
          CustomExpense(
            name: 'Langganan Tahunan',
            amount: 240000,
            frequency: BudgetFrequency.yearly,
          ),
        ],
      );

      // Perpuluhan: 500.000 per bulan.
      // Langganan: 240.000 / 12 = 20.000.
      expect(plan.monthlyCustomExpenses, 520000);

      // Kebutuhan dasar:
      // Rumah: 1.000.000
      // Makan: 650.000
      // Transportasi: 250.000
      // Tagihan: 300.000
      // Pribadi: 200.000
      // Custom: 520.000
      expect(plan.expenses, 2920000);
    },
  );

  // ===================================================
  // TEST 6: GAJI IDEAL DAN DANA CADANGAN
  // ===================================================

  test(
    'Dana cadangan dan kecukupan gaji dihitung dengan benar',
    () {
      final plan = _createPlan(
        actualIncome: 3000000,
        bufferPercent: 10,
        customExpenses: [
          CustomExpense(
            name: 'Kebutuhan Lain',
            amount: 100000,
          ),
        ],
      );

      // Total kebutuhan rutin.
      expect(plan.expenses, 2500000);

      // Kebutuhan rutin + tabungan.
      expect(plan.minimumIncome, 3500000);

      // Cadangan 10% dari minimum income.
      expect(plan.buffer, 350000);

      // Rekomendasi penghasilan ideal.
      expect(plan.idealIncome, 3850000);

      // Gaji 3 juta belum cukup.
      expect(plan.plannedDifference, -850000);
      expect(plan.canFundPlan, isFalse);

      // Simulasi peningkatan gaji.
      final higherIncomePlan = plan.copyWith(
        actualIncome: 4000000,
      );

      expect(higherIncomePlan.plannedDifference, 150000);
      expect(higherIncomePlan.canFundPlan, isTrue);

      // Simulasi tanpa cadangan.
      final noBufferPlan = plan.copyWith(
        bufferPercent: 0,
      );

      expect(noBufferPlan.buffer, 0);
      expect(noBufferPlan.idealIncome, 3500000);
    },
  );

  // ===================================================
  // TEST 7: JSON BACKUP DAN RESTORE
  // ===================================================

  test(
    'Data Planner tetap utuh setelah disimpan dan dibaca ulang',
    () {
      final originalPlan = _createPlan(
        actualIncome: 6200000,
        foodByWeekday: {
          1: 25000,
          2: 25000,
          7: 0,
        },
        additionalIncomes: [
          IncomeSource(
            id: 'income-1',
            name: 'Freelance',
            amount: 400000,
          ),
        ],
        transportByWeekday: [
          DailyTransport(
            weekday: 7,
            outbound: const [],
            returnTrip: [
              TransportLeg(
                mode: 'TransJakarta',
                cost: 3500,
              ),
            ],
          ),
        ],
        customExpenses: [
          CustomExpense(
            id: 'expense-1',
            name: 'Perpuluhan',
            amount: 200000,
          ),
        ],
      );

      // Ubah data menjadi JSON.
      final json = originalPlan.toJson();

      // Baca kembali dari JSON.
      final restoredPlan = FinancePlan.fromJson(json);

      expect(restoredPlan.name, originalPlan.name);

      expect(restoredPlan.actualIncome, 6200000);

      expect(restoredPlan.foodByWeekday[1], 25000);
      expect(restoredPlan.foodByWeekday[7], 0);

      expect(restoredPlan.additionalIncomes.length, 1);
      expect(
        restoredPlan.additionalIncomes.first.name,
        'Freelance',
      );

      expect(restoredPlan.transportByWeekday.length, 1);
      expect(
        restoredPlan.transportByWeekday.first.returnTotal,
        3500,
      );

      expect(restoredPlan.customExpenses.length, 1);
      expect(
        restoredPlan.customExpenses.first.amount,
        200000,
      );

      // Total keuangan harus tetap sama.
      expect(
        restoredPlan.totalMonthlyIncome,
        originalPlan.totalMonthlyIncome,
      );

      expect(restoredPlan.food, originalPlan.food);

      expect(
        restoredPlan.transport,
        originalPlan.transport,
      );

      expect(
        restoredPlan.idealIncome,
        originalPlan.idealIncome,
      );

      expect(
        restoredPlan.plannedDifference,
        originalPlan.plannedDifference,
      );
    },
  );
}