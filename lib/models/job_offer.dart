
enum JobSalaryMode {
  monthly,
  daily,
  hourly,
  session,
}

extension JobSalaryModeLabel on JobSalaryMode {
  String get label {
    switch (this) {
      case JobSalaryMode.monthly:
        return 'Bulanan';
      case JobSalaryMode.daily:
        return 'Harian';
      case JobSalaryMode.hourly:
        return 'Per jam';
      case JobSalaryMode.session:
        return 'Per sesi';
    }
  }
}

enum JobWorthVerdict {
  incomplete,
  financialRisk,
  belowTarget,
  attractive,
  reasonable,
  needsReview,
}

extension JobWorthVerdictLabel on JobWorthVerdict {
  String get label {
    switch (this) {
      case JobWorthVerdict.incomplete:
        return 'Data belum lengkap';
      case JobWorthVerdict.financialRisk:
        return 'Berisiko secara finansial';
      case JobWorthVerdict.belowTarget:
        return 'Perlu negosiasi atau pertimbangan ulang';
      case JobWorthVerdict.attractive:
        return 'Menarik untuk dipertimbangkan';
      case JobWorthVerdict.reasonable:
        return 'Cukup layak, periksa detailnya';
      case JobWorthVerdict.needsReview:
        return 'Perlu evaluasi lebih lanjut';
    }
  }
}

class JobOffer {
  const JobOffer({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.company = '',
    this.location = '',
    this.salaryMode = JobSalaryMode.monthly,
    this.salaryRate = 0,
    this.paidUnitsPerMonth = 22,
    this.allowances = 0,
    this.bonuses = 0,
    this.overtimeIncome = 0,
    this.otherIncome = 0,
    this.deductions = 0,
    this.workDaysPerMonth = 22,
    this.officeDaysPerMonth = 22,
    this.daysPerWeek = 5,
    this.hoursPerDay = 8,
    this.goCost = 0,
    this.returnCost = 0,
    this.goMinutes = 0,
    this.returnMinutes = 0,
    this.goDistanceKm = 0,
    this.returnDistanceKm = 0,
    this.extraMealCost = 0,
    this.otherWorkCosts = 0,
    this.targetRemaining = 0,
    this.comfortableCommuteMinutes = 120,
    this.careerRating = 3,
    this.environmentRating = 3,
    this.notes = '',
    this.isArchived = false,
  });

  // Identitas pekerjaan
  final String id;
  final String title;
  final String company;
  final String location;

  // Sistem penghasilan
  final JobSalaryMode salaryMode;
  final int salaryRate;
  final double paidUnitsPerMonth;

  // Tambahan penghasilan
  final int allowances;
  final int bonuses;
  final int overtimeIncome;
  final int otherIncome;

  // Potongan gaji
  final int deductions;

  // Jadwal kerja
  final int workDaysPerMonth;
  final int officeDaysPerMonth;
  final int daysPerWeek;
  final double hoursPerDay;

  // Transportasi
  final int goCost;
  final int returnCost;

  final double goMinutes;
  final double returnMinutes;

  final double goDistanceKm;
  final double returnDistanceKm;

  // Biaya tambahan bekerja
  final int extraMealCost;
  final int otherWorkCosts;

  // Preferensi pengguna
  final int targetRemaining;
  final double comfortableCommuteMinutes;

  final int careerRating;
  final int environmentRating;

  // Informasi tambahan
  final String notes;
  final bool isArchived;

  final DateTime createdAt;
  final DateTime updatedAt;

  // =========================================================
  // MEMBUAT TAWARAN PEKERJAAN BARU
  // =========================================================

  factory JobOffer.create({
    required String title,
    String company = '',
    String location = '',
  }) {
    final now = DateTime.now();

    return JobOffer(
      id: 'job_${now.microsecondsSinceEpoch}',
      title: title,
      company: company,
      location: location,
      createdAt: now,
      updatedAt: now,
    );
  }

  // =========================================================
  // PERHITUNGAN PENGHASILAN
  // =========================================================

  int get baseMonthlyIncome {
    if (salaryMode == JobSalaryMode.monthly) {
      return salaryRate;
    }

    return (salaryRate * paidUnitsPerMonth).round();
  }

  int get totalAdditionalIncome {
    return allowances +
        bonuses +
        overtimeIncome +
        otherIncome;
  }

  int get grossMonthlyIncome {
    return baseMonthlyIncome + totalAdditionalIncome;
  }

  int get takeHomePay {
    return grossMonthlyIncome - deductions;
  }

  // =========================================================
  // PERHITUNGAN BIAYA KERJA
  // =========================================================

  int get effectiveOfficeDays {
    return officeDaysPerMonth.clamp(
      0,
      workDaysPerMonth,
    ).toInt();
  }

  int get dailyTransportCost {
    return goCost + returnCost;
  }

  int get monthlyTransportCost {
    return dailyTransportCost * effectiveOfficeDays;
  }

  int get monthlyExtraMealCost {
    return extraMealCost * effectiveOfficeDays;
  }

  int get totalMonthlyWorkCosts {
    return monthlyTransportCost +
        monthlyExtraMealCost +
        otherWorkCosts;
  }

  int get remainingMonthlyIncome {
    return takeHomePay - totalMonthlyWorkCosts;
  }

  double get workCostPercentage {
    if (takeHomePay <= 0) {
      return 0;
    }

    return totalMonthlyWorkCosts / takeHomePay * 100;
  }

  // =========================================================
  // PERHITUNGAN JARAK DAN WAKTU
  // =========================================================

  double get dailyCommuteMinutes {
    return goMinutes + returnMinutes;
  }

  double get monthlyCommuteHours {
    return dailyCommuteMinutes *
        effectiveOfficeDays /
        60;
  }

  double get dailyCommuteDistance {
    return goDistanceKm + returnDistanceKm;
  }

  double get monthlyCommuteDistance {
    return dailyCommuteDistance * effectiveOfficeDays;
  }

  double get monthlyWorkingHours {
    return workDaysPerMonth * hoursPerDay;
  }

  double get weeklyWorkingHours {
    return daysPerWeek * hoursPerDay;
  }

  double get totalCommittedHours {
    return monthlyWorkingHours + monthlyCommuteHours;
  }

  int get effectiveHourlyIncome {
    if (totalCommittedHours <= 0) {
      return 0;
    }

    return (
      remainingMonthlyIncome / totalCommittedHours
    ).round();
  }

  // =========================================================
  // ANALISIS JOB WORTH IT
  // =========================================================

  int? get worthScore {
    if (grossMonthlyIncome <= 0 ||
        targetRemaining <= 0 ||
        workDaysPerMonth <= 0 ||
        hoursPerDay <= 0 ||
        daysPerWeek <= 0 ||
        (effectiveOfficeDays > 0 &&
            comfortableCommuteMinutes <= 0)) {
      return null;
    }

    // 1. Kondisi keuangan: maksimal 50 poin.
    final financialRatio =
        remainingMonthlyIncome / targetRemaining;

    int financialScore;

    if (financialRatio >= 1.25) {
      financialScore = 50;
    } else if (financialRatio >= 1.0) {
      financialScore = 44;
    } else if (financialRatio >= 0.85) {
      financialScore = 30;
    } else if (financialRatio >= 0.70) {
      financialScore = 15;
    } else {
      financialScore = 0;
    }

    // 2. Kenyamanan perjalanan: maksimal 20 poin.
    int commuteScore;

    if (effectiveOfficeDays == 0) {
      commuteScore = 20;
    } else if (dailyCommuteMinutes <=
        comfortableCommuteMinutes) {
      commuteScore = 20;
    } else if (dailyCommuteMinutes <=
        comfortableCommuteMinutes * 1.5) {
      commuteScore = 12;
    } else {
      commuteScore = 4;
    }

    // 3. Waktu kerja: maksimal 10 poin.
    int workLifeScore;

    if (weeklyWorkingHours <= 40) {
      workLifeScore = 10;
    } else if (weeklyWorkingHours <= 48) {
      workLifeScore = 6;
    } else {
      workLifeScore = 2;
    }

    // 4. Prospek karier: maksimal 10 poin.
    final careerScore =
        careerRating.clamp(1, 5).toInt() * 2;

    // 5. Lingkungan dan stabilitas: maksimal 10 poin.
    final environmentScore =
        environmentRating.clamp(1, 5).toInt() * 2;

    return financialScore +
        commuteScore +
        workLifeScore +
        careerScore +
        environmentScore;
  }

  JobWorthVerdict get worthVerdict {
    final score = worthScore;

    if (score == null) {
      return JobWorthVerdict.incomplete;
    }

    if (remainingMonthlyIncome <= 0) {
      return JobWorthVerdict.financialRisk;
    }

    if (remainingMonthlyIncome < targetRemaining) {
      return JobWorthVerdict.belowTarget;
    }

    if (score >= 80) {
      return JobWorthVerdict.attractive;
    }

    if (score >= 65) {
      return JobWorthVerdict.reasonable;
    }

    return JobWorthVerdict.needsReview;
  }

  // =========================================================
  // PENJELASAN HASIL REKOMENDASI
  // =========================================================

  List<String> get analysisNotes {
    final results = <String>[];

    if (grossMonthlyIncome <= 0) {
      results.add(
        'Nominal penghasilan belum dimasukkan.',
      );

      return results;
    }

    if (targetRemaining <= 0) {
      results.add(
        'Tentukan target uang yang ingin tersisa '
        'setelah seluruh biaya bekerja.',
      );
    } else {
      final difference =
          remainingMonthlyIncome - targetRemaining;

      if (difference >= 0) {
        results.add(
          'Uang tersisa berada Rp$difference '
          'di atas target pribadi.',
        );
      } else {
        results.add(
          'Uang tersisa masih kurang '
          'Rp${-difference} dari target pribadi.',
        );
      }
    }

    results.add(
      'Total biaya bekerja sekitar '
      '${workCostPercentage.toStringAsFixed(1)}% '
      'dari gaji bersih.',
    );

    if (effectiveOfficeDays > 0) {
      results.add(
        'Perjalanan kerja menghabiskan '
        '${monthlyCommuteHours.toStringAsFixed(1)} '
        'jam setiap bulan.',
      );

      if (comfortableCommuteMinutes > 0 &&
          dailyCommuteMinutes >
              comfortableCommuteMinutes) {
        results.add(
          'Waktu perjalanan melebihi batas nyaman '
          'yang ditentukan pengguna.',
        );
      }
    } else {
      results.add(
        'Tidak ada perjalanan ke kantor '
        'pada jadwal yang dimasukkan.',
      );
    }

    if (weeklyWorkingHours > 48) {
      results.add(
        'Jam kerja mingguan cukup tinggi. '
        'Pertimbangkan waktu istirahat.',
      );
    }

    if (careerRating <= 2) {
      results.add(
        'Prospek karier dinilai rendah.',
      );
    }

    if (environmentRating <= 2) {
      results.add(
        'Kenyamanan atau stabilitas '
        'pekerjaan dinilai rendah.',
      );
    }

    return results;
  }

  // =========================================================
  // MEMPERBARUI DATA PEKERJAAN
  // =========================================================

  JobOffer copyWith({
    String? title,
    String? company,
    String? location,
    JobSalaryMode? salaryMode,
    int? salaryRate,
    double? paidUnitsPerMonth,
    int? allowances,
    int? bonuses,
    int? overtimeIncome,
    int? otherIncome,
    int? deductions,
    int? workDaysPerMonth,
    int? officeDaysPerMonth,
    int? daysPerWeek,
    double? hoursPerDay,
    int? goCost,
    int? returnCost,
    double? goMinutes,
    double? returnMinutes,
    double? goDistanceKm,
    double? returnDistanceKm,
    int? extraMealCost,
    int? otherWorkCosts,
    int? targetRemaining,
    double? comfortableCommuteMinutes,
    int? careerRating,
    int? environmentRating,
    String? notes,
    bool? isArchived,
  }) {
    return JobOffer(
      id: id,
      title: title ?? this.title,
      company: company ?? this.company,
      location: location ?? this.location,
      salaryMode: salaryMode ?? this.salaryMode,
      salaryRate: salaryRate ?? this.salaryRate,
      paidUnitsPerMonth:
          paidUnitsPerMonth ?? this.paidUnitsPerMonth,
      allowances: allowances ?? this.allowances,
      bonuses: bonuses ?? this.bonuses,
      overtimeIncome:
          overtimeIncome ?? this.overtimeIncome,
      otherIncome: otherIncome ?? this.otherIncome,
      deductions: deductions ?? this.deductions,
      workDaysPerMonth:
          workDaysPerMonth ?? this.workDaysPerMonth,
      officeDaysPerMonth:
          officeDaysPerMonth ?? this.officeDaysPerMonth,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
      goCost: goCost ?? this.goCost,
      returnCost: returnCost ?? this.returnCost,
      goMinutes: goMinutes ?? this.goMinutes,
      returnMinutes:
          returnMinutes ?? this.returnMinutes,
      goDistanceKm:
          goDistanceKm ?? this.goDistanceKm,
      returnDistanceKm:
          returnDistanceKm ?? this.returnDistanceKm,
      extraMealCost:
          extraMealCost ?? this.extraMealCost,
      otherWorkCosts:
          otherWorkCosts ?? this.otherWorkCosts,
      targetRemaining:
          targetRemaining ?? this.targetRemaining,
      comfortableCommuteMinutes:
          comfortableCommuteMinutes ??
          this.comfortableCommuteMinutes,
      careerRating: careerRating ?? this.careerRating,
      environmentRating:
          environmentRating ?? this.environmentRating,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // =========================================================
  // SERIALISASI JSON
  // =========================================================

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 1,
      'id': id,
      'title': title,
      'company': company,
      'location': location,
      'salaryMode': salaryMode.name,
      'salaryRate': salaryRate,
      'paidUnitsPerMonth': paidUnitsPerMonth,
      'allowances': allowances,
      'bonuses': bonuses,
      'overtimeIncome': overtimeIncome,
      'otherIncome': otherIncome,
      'deductions': deductions,
      'workDaysPerMonth': workDaysPerMonth,
      'officeDaysPerMonth': officeDaysPerMonth,
      'daysPerWeek': daysPerWeek,
      'hoursPerDay': hoursPerDay,
      'goCost': goCost,
      'returnCost': returnCost,
      'goMinutes': goMinutes,
      'returnMinutes': returnMinutes,
      'goDistanceKm': goDistanceKm,
      'returnDistanceKm': returnDistanceKm,
      'extraMealCost': extraMealCost,
      'otherWorkCosts': otherWorkCosts,
      'targetRemaining': targetRemaining,
      'comfortableCommuteMinutes':
          comfortableCommuteMinutes,
      'careerRating': careerRating,
      'environmentRating': environmentRating,
      'notes': notes,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory JobOffer.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    JobSalaryMode parsedMode = JobSalaryMode.monthly;

    for (final mode in JobSalaryMode.values) {
      if (mode.name == json['salaryMode']) {
        parsedMode = mode;
        break;
      }
    }

    return JobOffer(
      id: _readString(
        json['id'],
        'job_${now.microsecondsSinceEpoch}',
      ),
      title: _readString(json['title'], ''),
      company: _readString(json['company'], ''),
      location: _readString(json['location'], ''),
      salaryMode: parsedMode,
      salaryRate: _readInt(json['salaryRate']),
      paidUnitsPerMonth: _readDouble(
        json['paidUnitsPerMonth'],
        22,
      ),
      allowances: _readInt(json['allowances']),
      bonuses: _readInt(json['bonuses']),
      overtimeIncome: _readInt(
        json['overtimeIncome'],
      ),
      otherIncome: _readInt(json['otherIncome']),
      deductions: _readInt(json['deductions']),
      workDaysPerMonth: _readInt(
        json['workDaysPerMonth'],
        22,
      ).clamp(0, 31).toInt(),
      officeDaysPerMonth: _readInt(
        json['officeDaysPerMonth'],
        22,
      ).clamp(0, 31).toInt(),
      daysPerWeek: _readInt(
        json['daysPerWeek'],
        5,
      ).clamp(0, 7).toInt(),
      hoursPerDay: _readDouble(
        json['hoursPerDay'],
        8,
      ),
      goCost: _readInt(json['goCost']),
      returnCost: _readInt(json['returnCost']),
      goMinutes: _readDouble(json['goMinutes']),
      returnMinutes: _readDouble(
        json['returnMinutes'],
      ),
      goDistanceKm: _readDouble(
        json['goDistanceKm'],
      ),
      returnDistanceKm: _readDouble(
        json['returnDistanceKm'],
      ),
      extraMealCost: _readInt(json['extraMealCost']),
      otherWorkCosts: _readInt(
        json['otherWorkCosts'],
      ),
      targetRemaining: _readInt(
        json['targetRemaining'],
      ),
      comfortableCommuteMinutes: _readDouble(
        json['comfortableCommuteMinutes'],
        120,
      ),
      careerRating: _readInt(
        json['careerRating'],
        3,
      ).clamp(1, 5).toInt(),
      environmentRating: _readInt(
        json['environmentRating'],
        3,
      ).clamp(1, 5).toInt(),
      notes: _readString(json['notes'], ''),
      isArchived: json['isArchived'] == true,
      createdAt: DateTime.tryParse(
            _readString(json['createdAt'], ''),
          ) ??
          now,
      updatedAt: DateTime.tryParse(
            _readString(json['updatedAt'], ''),
          ) ??
          now,
    );
  }

  // =========================================================
  // MEMBANDINGKAN BEBERAPA TAWARAN
  // =========================================================

  static List<JobOffer> rankOffers(
    Iterable<JobOffer> offers,
  ) {
    final ranked = offers.toList();

    ranked.sort((a, b) {
      final aScore = a.worthScore ?? -1;
      final bScore = b.worthScore ?? -1;

      final scoreComparison = bScore.compareTo(aScore);

      if (scoreComparison != 0) {
        return scoreComparison;
      }

      return b.remainingMonthlyIncome.compareTo(
        a.remainingMonthlyIncome,
      );
    });

    return ranked;
  }

  // =========================================================
  // HELPERS JSON
  // =========================================================

  static String _readString(
    dynamic value,
    String fallback,
  ) {
    if (value is String) {
      return value;
    }

    return fallback;
  }

  static int _readInt(
    dynamic value, [
    int fallback = 0,
  ]) {
    int? result;

    if (value is num) {
      if (!value.isFinite) return fallback;
      result = value.toInt();
    } else if (value is String) {
      result = int.tryParse(value);
    }

    if (result == null || result < 0) {
      return fallback;
    }

    return result;
  }

  static double _readDouble(
    dynamic value, [
    double fallback = 0,
  ]) {
    double? result;

    if (value is num) {
      result = value.toDouble();
    } else if (value is String) {
      result = double.tryParse(
        value.replaceAll(',', '.'),
      );
    }

    if (result == null ||
        !result.isFinite ||
        result < 0) {
      return fallback;
    }

    return result;
  }
}
