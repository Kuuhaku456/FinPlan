
// ==========================================
// FINPLAN FINANCIAL MODEL V2
// ==========================================
//
// Mendukung:
// - Gaji utama
// - Pemasukan tambahan
// - Anggaran makan Senin-Minggu
// - Transportasi multi-moda
// - Perjalanan pergi dan pulang
// - Kebutuhan custom
// - Tabungan dan dana cadangan
//
// Seluruh nominal menggunakan int (Rupiah).
// ==========================================


// ==========================================
// 1. FREKUENSI PEMASUKAN / PENGELUARAN
// ==========================================

enum BudgetFrequency {
  weekly,
  monthly,
  yearly,
}

// Membaca frekuensi dari JSON.
BudgetFrequency frequencyFromJson(dynamic value) {
  for (final frequency in BudgetFrequency.values) {
    if (frequency.name == value) {
      return frequency;
    }
  }

  return BudgetFrequency.monthly;
}

// Mengubah nominal berulang menjadi
// estimasi rata-rata per bulan.
int monthlyEstimate(
  int amount,
  BudgetFrequency frequency,
) {
  switch (frequency) {
    case BudgetFrequency.weekly:
      return (amount * 52 + 11) ~/ 12;

    case BudgetFrequency.monthly:
      return amount;

    case BudgetFrequency.yearly:
      return (amount + 11) ~/ 12;
  }
}

// Mengambil angka nonnegatif dari JSON.
int safeAmount(
  Map<String, dynamic> json,
  String key, [
  int fallback = 0,
]) {
  final value = json[key];

  if (value is num) {
    return value
        .toInt()
        .clamp(0, 1000000000000)
        .toInt();
  }

  return fallback;
}

// Membaca daftar object dari JSON.
List<T> readObjectList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) parser,
) {
  if (value is! List) {
    return <T>[];
  }

  final result = <T>[];

  for (final item in value) {
    if (item is Map) {
      try {
        result.add(
          parser(
            Map<String, dynamic>.from(item),
          ),
        );
      } catch (_) {
        // Abaikan entri yang tidak valid.
      }
    }
  }

  return result;
}


// ==========================================
// 2. MODEL PEMASUKAN TAMBAHAN
// ==========================================

class IncomeSource {
  const IncomeSource({
    this.id = '',
    required this.name,
    required this.amount,
    this.frequency = BudgetFrequency.monthly,
  });

  final String id;

  // Contoh: Freelance, Bisnis, Komisi.
  final String name;

  // Nominal per frekuensi.
  final int amount;

  final BudgetFrequency frequency;

  int get monthlyAmount {
    return monthlyEstimate(
      amount,
      frequency,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'frequency': frequency.name,
    };
  }

  factory IncomeSource.fromJson(
    Map<String, dynamic> json,
  ) {
    return IncomeSource(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      amount: safeAmount(json, 'amount'),
      frequency: frequencyFromJson(
        json['frequency'],
      ),
    );
  }
}


// ==========================================
// 3. MODEL SEGMEN TRANSPORTASI
// ==========================================
//
// Satu perjalanan bisa menggunakan
// lebih dari satu transportasi.
//
// Contoh pergi:
// Bus -> KRL -> Ojek Online
//
// Contoh pulang:
// KRL -> Bus
// ==========================================

class TransportLeg {
  const TransportLeg({
    required this.mode,
    required this.cost,
    this.note = '',
  });

  // Contoh: KRL, TransJakarta, Gojek.
  // Bisa diisi nama transportasi custom.
  final String mode;

  // Biaya satu segmen perjalanan.
  final int cost;

  final String note;

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'cost': cost,
      'note': note,
    };
  }

  factory TransportLeg.fromJson(
    Map<String, dynamic> json,
  ) {
    return TransportLeg(
      mode: json['mode']?.toString() ?? '',
      cost: safeAmount(json, 'cost'),
      note: json['note']?.toString() ?? '',
    );
  }
}


// ==========================================
// 4. MODEL TRANSPORTASI HARIAN
// ==========================================
//
// weekday:
// 1 = Senin
// 2 = Selasa
// 3 = Rabu
// 4 = Kamis
// 5 = Jumat
// 6 = Sabtu
// 7 = Minggu
// ==========================================

class DailyTransport {
  const DailyTransport({
    required this.weekday,
    this.outbound = const [],
    this.returnTrip = const [],
  });

  final int weekday;

  // Daftar transportasi saat pergi.
  final List<TransportLeg> outbound;

  // Daftar transportasi saat pulang.
  final List<TransportLeg> returnTrip;

  int get outboundTotal {
    return outbound.fold<int>(
      0,
      (sum, leg) => sum + leg.cost,
    );
  }

  int get returnTotal {
    return returnTrip.fold<int>(
      0,
      (sum, leg) => sum + leg.cost,
    );
  }

  int get dailyTotal {
    return outboundTotal + returnTotal;
  }

  Map<String, dynamic> toJson() {
    return {
      'weekday': weekday,
      'outbound': outbound
          .map((leg) => leg.toJson())
          .toList(),
      'returnTrip': returnTrip
          .map((leg) => leg.toJson())
          .toList(),
    };
  }

  factory DailyTransport.fromJson(
    Map<String, dynamic> json,
  ) {
    return DailyTransport(
      weekday: safeAmount(
        json,
        'weekday',
        1,
      ).clamp(1, 7).toInt(),

      outbound: readObjectList<TransportLeg>(
        json['outbound'],
        TransportLeg.fromJson,
      ),

      returnTrip: readObjectList<TransportLeg>(
        json['returnTrip'],
        TransportLeg.fromJson,
      ),
    );
  }
}


// ==========================================
// 5. MODEL KEBUTUHAN CUSTOM
// ==========================================
//
// Pengguna bebas menambahkan kebutuhan.
//
// Contoh:
// - Perpuluhan
// - Kirim uang ke keluarga
// - Langganan aplikasi
// - Biaya pendidikan
// - Kebutuhan hewan peliharaan
// ==========================================

class CustomExpense {
  const CustomExpense({
    this.id = '',
    required this.name,
    required this.amount,
    this.frequency = BudgetFrequency.monthly,
  });

  final String id;
  final String name;
  final int amount;
  final BudgetFrequency frequency;

  int get monthlyAmount {
    return monthlyEstimate(
      amount,
      frequency,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'frequency': frequency.name,
    };
  }

  factory CustomExpense.fromJson(
    Map<String, dynamic> json,
  ) {
    return CustomExpense(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      amount: safeAmount(json, 'amount'),
      frequency: frequencyFromJson(
        json['frequency'],
      ),
    );
  }
}


// ==========================================
// 6. MODEL UTAMA FINANCIAL PLAN
// ==========================================

class FinancePlan {
  const FinancePlan({
    required this.name,
    required this.actualIncome,
    required this.housing,
    required int food,
    required int transport,
    required this.bills,
    required this.personal,
    required this.savings,
    required this.bufferPercent,

    // FITUR BARU V2
    this.additionalIncomes = const [],
    this.foodByWeekday = const {},
    this.transportByWeekday = const [],
    this.customExpenses = const [],
  })  : _monthlyFoodFallback = food,
        _monthlyTransportFallback = transport;

  // ========================================
  // DATA PENGGUNA
  // ========================================

  final String name;

  // Gaji bersih utama per bulan.
  final int actualIncome;

  final int housing;
  final int bills;
  final int personal;
  final int savings;
  final int bufferPercent;

  // Nilai bulanan dari model lama.
  final int _monthlyFoodFallback;
  final int _monthlyTransportFallback;

  // ========================================
  // DATA BARU V2
  // ========================================

  // Pemasukan tambahan.
  final List<IncomeSource> additionalIncomes;

  // Anggaran makanan per hari.
  //
  // Key 1-7 = Senin-Minggu.
  // Value = anggaran makanan per hari.
  final Map<int, int> foodByWeekday;

  // Rute transportasi Senin-Minggu.
  final List<DailyTransport> transportByWeekday;

  // Kebutuhan tambahan buatan pengguna.
  final List<CustomExpense> customExpenses;


  // ========================================
  // 7. TOTAL PEMASUKAN TAMBAHAN
  // ========================================

  int get monthlyAdditionalIncome {
    return additionalIncomes.fold<int>(
      0,
      (sum, income) {
        return sum + income.monthlyAmount;
      },
    );
  }

  // ========================================
  // 8. TOTAL PEMASUKAN BULANAN
  // ========================================

  int get totalMonthlyIncome {
    return actualIncome + monthlyAdditionalIncome;
  }


  // ========================================
  // 9. TOTAL MAKANAN PER MINGGU
  // ========================================

  int get weeklyFoodTotal {
    return foodByWeekday.values.fold<int>(
      0,
      (sum, amount) => sum + amount,
    );
  }

  // ========================================
  // 10. ESTIMASI MAKANAN BULANAN
  // ========================================

  // Getter ini mempertahankan nama 'food'
  // supaya kode lama tetap kompatibel.
  int get food {
    if (foodByWeekday.isEmpty) {
      return _monthlyFoodFallback;
    }

    return monthlyEstimate(
      weeklyFoodTotal,
      BudgetFrequency.weekly,
    );
  }


  // ========================================
  // 11. TOTAL TRANSPORTASI MINGGUAN
  // ========================================

  int get weeklyTransportTotal {
    return transportByWeekday.fold<int>(
      0,
      (sum, day) {
        return sum + day.dailyTotal;
      },
    );
  }

  // ========================================
  // 12. ESTIMASI TRANSPORTASI BULANAN
  // ========================================

  // Getter ini mempertahankan nama
  // 'transport' dari model sebelumnya.
  int get transport {
    if (transportByWeekday.isEmpty) {
      return _monthlyTransportFallback;
    }

    return monthlyEstimate(
      weeklyTransportTotal,
      BudgetFrequency.weekly,
    );
  }


  // ========================================
  // 13. TOTAL KEBUTUHAN CUSTOM
  // ========================================

  int get monthlyCustomExpenses {
    return customExpenses.fold<int>(
      0,
      (sum, expense) {
        return sum + expense.monthlyAmount;
      },
    );
  }


  // ========================================
  // 14. TOTAL PENGELUARAN BULANAN
  // ========================================

  int get expenses {
    return housing +
        food +
        transport +
        bills +
        personal +
        monthlyCustomExpenses;
  }


  // ========================================
  // 15. PENGHASILAN MINIMUM
  // ========================================

  int get minimumIncome {
    return expenses + savings;
  }


  // ========================================
  // 16. DANA CADANGAN
  // ========================================

  int get buffer {
    return (minimumIncome * bufferPercent + 99) ~/ 100;
  }


  // ========================================
  // 17. REKOMENDASI GAJI IDEAL
  // ========================================

  int get idealIncome {
    return minimumIncome + buffer;
  }


  // ========================================
  // 18. SELISIH PENGHASILAN
  // ========================================

  int get plannedDifference {
    return totalMonthlyIncome - idealIncome;
  }


  // ========================================
  // 19. STATUS KECUKUPAN PENGHASILAN
  // ========================================

  bool get canFundPlan {
    return plannedDifference >= 0;
  }


  // ========================================
  // 20. DATA DEFAULT
  // ========================================

  static FinancePlan defaults() {
    return const FinancePlan(
      name: '',
      actualIncome: 6000000,
      housing: 1200000,
      food: 1200000,
      transport: 500000,
      bills: 300000,
      personal: 500000,
      savings: 1000000,
      bufferPercent: 10,
    );
  }


  // ========================================
  // 21. COPY DATA TANPA MENGHAPUS FIELD LAIN
  // ========================================

  FinancePlan copyWith({
    String? name,
    int? actualIncome,
    int? housing,
    int? food,
    int? transport,
    int? bills,
    int? personal,
    int? savings,
    int? bufferPercent,
    List<IncomeSource>? additionalIncomes,
    Map<int, int>? foodByWeekday,
    List<DailyTransport>? transportByWeekday,
    List<CustomExpense>? customExpenses,
  }) {
    return FinancePlan(
      name: name ?? this.name,

      actualIncome: actualIncome ?? this.actualIncome,

      housing: housing ?? this.housing,

      food: food ?? _monthlyFoodFallback,

      transport: transport ?? _monthlyTransportFallback,

      bills: bills ?? this.bills,

      personal: personal ?? this.personal,

      savings: savings ?? this.savings,

      bufferPercent: bufferPercent ?? this.bufferPercent,

      additionalIncomes:
          additionalIncomes ?? this.additionalIncomes,

      foodByWeekday:
          foodByWeekday ?? this.foodByWeekday,

      transportByWeekday:
          transportByWeekday ?? this.transportByWeekday,

      customExpenses:
          customExpenses ?? this.customExpenses,
    );
  }


  // ========================================
  // 22. KONVERSI KE JSON
  // ========================================

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 2,

      'name': name,
      'actualIncome': actualIncome,
      'housing': housing,

      // Fallback nominal dari versi lama.
      'food': _monthlyFoodFallback,
      'transport': _monthlyTransportFallback,

      'bills': bills,
      'personal': personal,
      'savings': savings,
      'bufferPercent': bufferPercent,

      'additionalIncomes': additionalIncomes
          .map((income) => income.toJson())
          .toList(),

      'foodByWeekday': foodByWeekday.map(
        (day, amount) {
          return MapEntry(
            day.toString(),
            amount,
          );
        },
      ),

      'transportByWeekday': transportByWeekday
          .map((day) => day.toJson())
          .toList(),

      'customExpenses': customExpenses
          .map((expense) => expense.toJson())
          .toList(),
    };
  }


  // ========================================
  // 23. MEMBACA FOOD SCHEDULE DARI JSON
  // ========================================

  static Map<int, int> _readFoodSchedule(dynamic value) {
    final result = <int, int>{};

    if (value is! Map) {
      return result;
    }

    for (final entry in value.entries) {
      final day = int.tryParse(
        entry.key.toString(),
      );

      final amount = entry.value;

      if (day == null || day < 1 || day > 7) {
        continue;
      }

      if (amount is num) {
        result[day] = amount
            .toInt()
            .clamp(0, 1000000000000)
            .toInt();
      }
    }

    return result;
  }


  // ========================================
  // 24. MEMBACA FINANCIAL PLAN DARI JSON
  // ========================================

  factory FinancePlan.fromJson(
    Map<String, dynamic> json,
  ) {
    return FinancePlan(
      name: json['name']?.toString() ?? '',

      actualIncome: safeAmount(
        json,
        'actualIncome',
      ),

      housing: safeAmount(
        json,
        'housing',
      ),

      food: safeAmount(
        json,
        'food',
      ),

      transport: safeAmount(
        json,
        'transport',
      ),

      bills: safeAmount(
        json,
        'bills',
      ),

      personal: safeAmount(
        json,
        'personal',
      ),

      savings: safeAmount(
        json,
        'savings',
      ),

      bufferPercent: safeAmount(
        json,
        'bufferPercent',
        10,
      ).clamp(0, 50).toInt(),

      additionalIncomes: readObjectList<IncomeSource>(
        json['additionalIncomes'],
        IncomeSource.fromJson,
      ),

      foodByWeekday: _readFoodSchedule(
        json['foodByWeekday'],
      ),

      transportByWeekday: readObjectList<DailyTransport>(
        json['transportByWeekday'],
        DailyTransport.fromJson,
      ),

      customExpenses: readObjectList<CustomExpense>(
        json['customExpenses'],
        CustomExpense.fromJson,
      ),
    );
  }
}
