import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/savings_goal.dart';

// ============================================================
// MODEL RINGKASAN TABUNGAN
// ============================================================

class SavingsSummary {
  const SavingsSummary({
    required this.totalSaved,
    required this.totalTarget,
    required this.activeGoals,
    required this.completedGoals,
    required this.archivedGoals,
  });

  // Jumlah uang yang tercatat di kantong aktif.
  final int totalSaved;

  // Total target seluruh kantong aktif.
  final int totalTarget;

  // Jumlah kantong aktif, termasuk yang sudah tercapai.
  final int activeGoals;

  // Jumlah kantong aktif yang sudah mencapai target.
  final int completedGoals;

  // Jumlah kantong yang diarsipkan.
  final int archivedGoals;

  // ==========================================================
  // TOTAL SISA TARGET
  // ==========================================================

  int get remainingTarget {
    final remaining = totalTarget - totalSaved;

    return remaining < 0 ? 0 : remaining;
  }

  // ==========================================================
  // PROGRESS KESELURUHAN
  // ==========================================================

  double get progress {
    if (totalTarget <= 0) {
      return 0;
    }

    return (totalSaved / totalTarget)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double get progressPercent {
    return progress * 100;
  }

  bool get isEmpty {
    return activeGoals == 0;
  }
}

// ============================================================
// SAVINGS REPOSITORY
// ============================================================

class SavingsRepository {
  SavingsRepository({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  // ==========================================================
  // KONFIGURASI PENYIMPANAN
  // ==========================================================

  static const String _storageKey =
      'finplan.savings_goals.v1';

  static const int _schemaVersion = 1;

  final SharedPreferencesAsync _preferences;

  // ==========================================================
  // ANTREAN OPERASI
  // ==========================================================

  // Semua operasi repository dijalankan secara berurutan
  // untuk mengurangi risiko lost update ketika pengguna
  // menekan tombol simpan atau tambah tabungan berdekatan.
  //
  // Gunakan satu instance SavingsRepository yang dibagikan
  // ke seluruh aplikasi melalui SavingsController.

  Future<void> _operationQueue = Future<void>.value();

  Future<T> _runSerialized<T>(
    Future<T> Function() operation,
  ) {
    final completer = Completer<T>();

    _operationQueue = _operationQueue.then((_) async {
      try {
        final result = await operation();

        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(
          error,
          stackTrace,
        );
      }
    });

    return completer.future;
  }

  // ==========================================================
  // MEMBACA SEMUA DATA DARI PENYIMPANAN
  // ==========================================================

  // Method internal.
  // Hanya dipanggil dari operasi yang sudah diserialisasi.

  Future<List<SavingsGoal>> _readGoalsInternal() async {
    final rawData = await _preferences.getString(
      _storageKey,
    );

    // Belum pernah membuat kantong.
    if (rawData == null || rawData.trim().isEmpty) {
      return <SavingsGoal>[];
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(rawData);
    } catch (error) {
      throw FormatException(
        'Data kantong tabungan tidak dapat dibaca: $error',
      );
    }

    List<dynamic> rawGoals;

    // Format penyimpanan utama.
    if (decoded is Map) {
      final versionValue = decoded['version'];

      final version = versionValue is int
          ? versionValue
          : int.tryParse(
                versionValue?.toString() ?? '',
              ) ??
              1;

      // Jangan menimpa data dari format yang lebih baru.
      if (version > _schemaVersion) {
        throw UnsupportedError(
          'Versi data tabungan lebih baru daripada '
          'versi aplikasi saat ini.',
        );
      }

      final goalsValue = decoded['goals'];

      if (goalsValue is! List) {
        throw const FormatException(
          'Daftar kantong tabungan tidak valid.',
        );
      }

      rawGoals = goalsValue;
    }

    // Mendukung format JSON list sederhana.
    else if (decoded is List) {
      rawGoals = decoded;
    } else {
      throw const FormatException(
        'Format penyimpanan kantong tabungan tidak valid.',
      );
    }

    final goals = <SavingsGoal>[];

    for (var index = 0; index < rawGoals.length; index++) {
      final item = rawGoals[index];

      if (item is! Map) {
        throw FormatException(
          'Data kantong ke-${index + 1} tidak valid.',
        );
      }

      try {
        final goal = SavingsGoal.fromJson(
          Map<String, dynamic>.from(item),
        );

        goals.add(goal);
      } catch (error) {
        throw FormatException(
          'Gagal membaca kantong ke-${index + 1}: $error',
        );
      }
    }

    _validateUniqueIds(goals);

    return goals;
  }

  // ==========================================================
  // VALIDASI ID KANTONG
  // ==========================================================

  void _validateUniqueIds(List<SavingsGoal> goals) {
    final ids = <String>{};

    for (final goal in goals) {
      if (!ids.add(goal.id)) {
        throw StateError(
          'Terdapat ID kantong ganda: ${goal.id}',
        );
      }
    }
  }

  String _validateId(String goalId) {
    final id = goalId.trim();

    if (id.isEmpty) {
      throw ArgumentError(
        'ID kantong tidak boleh kosong.',
      );
    }

    return id;
  }

  // ==========================================================
  // MENYIMPAN SEMUA DATA
  // ==========================================================

  Future<void> _writeGoalsInternal(
    List<SavingsGoal> goals,
  ) async {
    _validateUniqueIds(goals);

    final data = <String, dynamic>{
      'version': _schemaVersion,
      'updatedAt': DateTime.now().toIso8601String(),
      'goals': goals
          .map((goal) => goal.toJson())
          .toList(),
    };

    final encodedData = jsonEncode(data);

    await _preferences.setString(
      _storageKey,
      encodedData,
    );
  }

  // ==========================================================
  // MENCARI INDEX KANTONG
  // ==========================================================

  int _findGoalIndex(
    List<SavingsGoal> goals,
    String goalId,
  ) {
    return goals.indexWhere(
      (goal) => goal.id == goalId,
    );
  }

  // ==========================================================
  // MENDAPATKAN KANTONG ATAU THROW ERROR
  // ==========================================================

  SavingsGoal _requireGoal(
    List<SavingsGoal> goals,
    String goalId,
  ) {
    final index = _findGoalIndex(
      goals,
      goalId,
    );

    if (index == -1) {
      throw StateError(
        'Kantong tabungan tidak ditemukan.',
      );
    }

    return goals[index];
  }

  // ==========================================================
  // MEMPERBARUI DETAIL TANPA MENGUBAH SALDO
  // ==========================================================

  // Saat pengguna mengedit nama/target/deadline,
  // saldo dan riwayat lama tetap dipertahankan.

  SavingsGoal _mergeGoalDetails(
    SavingsGoal existing,
    SavingsGoal edited,
  ) {
    return existing.copyWith(
      name: edited.name,
      emoji: edited.emoji,
      description: edited.description,
      targetAmount: edited.targetAmount,
      deadline: edited.deadline,
      updatedAt: DateTime.now(),
    );
  }

  // ==========================================================
  // MEMBACA SEMUA KANTONG
  // ==========================================================

  Future<List<SavingsGoal>> getAllGoals({
    bool includeArchived = true,
  }) {
    return _runSerialized(() async {
      final goals = await _readGoalsInternal();

      final filtered = includeArchived
          ? goals
          : goals.where(
              (goal) => !goal.isArchived,
            ).toList();

      // Kantong yang terakhir diperbarui ditampilkan dahulu.
      filtered.sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );

      return List<SavingsGoal>.unmodifiable(
        filtered,
      );
    });
  }

  // ==========================================================
  // ALIAS UNTUK MEMUAT KANTONG
  // ==========================================================

  Future<List<SavingsGoal>> loadGoals({
    bool includeArchived = true,
  }) {
    return getAllGoals(
      includeArchived: includeArchived,
    );
  }

  // ==========================================================
  // MEMBACA SATU KANTONG
  // ==========================================================

  Future<SavingsGoal?> getGoalById(String goalId) {
    return _runSerialized(() async {
      final id = _validateId(goalId);

      final goals = await _readGoalsInternal();

      final index = _findGoalIndex(
        goals,
        id,
      );

      if (index == -1) {
        return null;
      }

      return goals[index];
    });
  }

  // ==========================================================
  // MEMBUAT KANTONG BARU
  // ==========================================================

  Future<SavingsGoal> createGoal(
    SavingsGoal newGoal,
  ) {
    return _runSerialized(() async {
      final goals = await _readGoalsInternal();

      final existingIndex = _findGoalIndex(
        goals,
        newGoal.id,
      );

      if (existingIndex != -1) {
        throw StateError(
          'Kantong dengan ID tersebut sudah ada.',
        );
      }

      goals.add(newGoal);

      await _writeGoalsInternal(goals);

      return newGoal;
    });
  }

  // ==========================================================
  // SIMPAN KANTONG (TAMBAH ATAU EDIT)
  // ==========================================================

  // Jika ID belum ada, dibuat kantong baru.
  // Jika ID sudah ada, hanya metadata yang diperbarui.
  // Saldo dan riwayat tetap menggunakan data tersimpan.

  Future<SavingsGoal> saveGoal(
    SavingsGoal goal,
  ) {
    return _runSerialized(() async {
      final goals = await _readGoalsInternal();

      final index = _findGoalIndex(
        goals,
        goal.id,
      );

      SavingsGoal savedGoal;

      if (index == -1) {
        savedGoal = goal;

        goals.add(savedGoal);
      } else {
        savedGoal = _mergeGoalDetails(
          goals[index],
          goal,
        );

        goals[index] = savedGoal;
      }

      await _writeGoalsInternal(goals);

      return savedGoal;
    });
  }

  // ==========================================================
  // EDIT INFORMASI KANTONG
  // ==========================================================

  Future<SavingsGoal> updateGoal(
    SavingsGoal editedGoal,
  ) {
    return _runSerialized(() async {
      final goals = await _readGoalsInternal();

      final index = _findGoalIndex(
        goals,
        editedGoal.id,
      );

      if (index == -1) {
        throw StateError(
          'Kantong yang ingin diedit tidak ditemukan.',
        );
      }

      final updatedGoal = _mergeGoalDetails(
        goals[index],
        editedGoal,
      );

      goals[index] = updatedGoal;

      await _writeGoalsInternal(goals);

      return updatedGoal;
    });
  }

  // ==========================================================
  // TAMBAH TABUNGAN
  // ==========================================================

  Future<SavingsGoal> addSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) {
    return _runSerialized(() async {
      final id = _validateId(goalId);

      final goals = await _readGoalsInternal();

      final existingGoal = _requireGoal(
        goals,
        id,
      );

      // SavingsGoal.addSavings otomatis:
      // 1. Menambah saldo.
      // 2. Membuat riwayat setoran.
      // 3. Memperbarui updatedAt.
      final updatedGoal = existingGoal.addSavings(
        amount,
        note: note,
        date: date,
      );

      final index = _findGoalIndex(
        goals,
        id,
      );

      goals[index] = updatedGoal;

      await _writeGoalsInternal(goals);

      return updatedGoal;
    });
  }

  // ==========================================================
  // AMBIL TABUNGAN
  // ==========================================================

  Future<SavingsGoal> withdrawSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) {
    return _runSerialized(() async {
      final id = _validateId(goalId);

      final goals = await _readGoalsInternal();

      final existingGoal = _requireGoal(
        goals,
        id,
      );

      // SavingsGoal akan menolak pengambilan
      // yang melebihi saldo tersedia.
      final updatedGoal = existingGoal.withdrawSavings(
        amount,
        note: note,
        date: date,
      );

      final index = _findGoalIndex(
        goals,
        id,
      );

      goals[index] = updatedGoal;

      await _writeGoalsInternal(goals);

      return updatedGoal;
    });
  }

  // ==========================================================
  // MENGARSIPKAN KANTONG
  // ==========================================================

  Future<SavingsGoal> archiveGoal(
    String goalId,
  ) {
    return _runSerialized(() async {
      final id = _validateId(goalId);

      final goals = await _readGoalsInternal();

      final existingGoal = _requireGoal(
        goals,
        id,
      );

      final archivedGoal = existingGoal.archive();

      final index = _findGoalIndex(
        goals,
        id,
      );

      goals[index] = archivedGoal;

      await _writeGoalsInternal(goals);

      return archivedGoal;
    });
  }

  // ==========================================================
  // MEMULIHKAN KANTONG DARI ARSIP
  // ==========================================================

  Future<SavingsGoal> restoreGoal(
    String goalId,
  ) {
    return _runSerialized(() async {
      final id = _validateId(goalId);

      final goals = await _readGoalsInternal();

      final existingGoal = _requireGoal(
        goals,
        id,
      );

      final restoredGoal = existingGoal.restore();

      final index = _findGoalIndex(
        goals,
        id,
      );

      goals[index] = restoredGoal;

      await _writeGoalsInternal(goals);

      return restoredGoal;
    });
  }

  // ==========================================================
  // HAPUS KANTONG
  // ==========================================================

  // Penghapusan dilakukan setelah UI menampilkan
  // dialog konfirmasi.
  //
  // Seluruh riwayat di dalam kantong ikut terhapus.

  Future<bool> deleteGoal(
    String goalId,
  ) {
    return _runSerialized(() async {
      final id = _validateId(goalId);

      final goals = await _readGoalsInternal();

      final oldLength = goals.length;

      goals.removeWhere(
        (goal) => goal.id == id,
      );

      if (goals.length == oldLength) {
        return false;
      }

      await _writeGoalsInternal(goals);

      return true;
    });
  }

  // ==========================================================
  // MEMBACA RIWAYAT SETORAN / PENARIKAN
  // ==========================================================

  Future<List<SavingsMovement>> getMovementHistory(
    String goalId,
  ) {
    return _runSerialized(() async {
      final id = _validateId(goalId);

      final goals = await _readGoalsInternal();

      final goal = _requireGoal(
        goals,
        id,
      );

      final movements = <SavingsMovement>[
        ...goal.movements,
      ];

      // Aktivitas paling baru ditampilkan dahulu.
      movements.sort(
        (a, b) => b.date.compareTo(a.date),
      );

      return List<SavingsMovement>.unmodifiable(
        movements,
      );
    });
  }

  // ==========================================================
  // RINGKASAN SELURUH TABUNGAN
  // ==========================================================

  Future<SavingsSummary> getSummary() {
    return _runSerialized(() async {
      final goals = await _readGoalsInternal();

      int totalSaved = 0;
      int totalTarget = 0;
      int activeGoals = 0;
      int completedGoals = 0;
      int archivedGoals = 0;

      for (final goal in goals) {
        if (goal.isArchived) {
          archivedGoals++;
          continue;
        }

        activeGoals++;

        totalSaved += goal.savedAmount;
        totalTarget += goal.targetAmount;

        if (goal.isCompleted) {
          completedGoals++;
        }
      }

      return SavingsSummary(
        totalSaved: totalSaved,
        totalTarget: totalTarget,
        activeGoals: activeGoals,
        completedGoals: completedGoals,
        archivedGoals: archivedGoals,
      );
    });
  }

  // ==========================================================
  // MEMBACA KANTONG YANG DIARSIPKAN
  // ==========================================================

  Future<List<SavingsGoal>> getArchivedGoals() {
    return _runSerialized(() async {
      final goals = await _readGoalsInternal();

      final archived = goals
          .where((goal) => goal.isArchived)
          .toList();

      archived.sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );

      return List<SavingsGoal>.unmodifiable(
        archived,
      );
    });
  }

  // ==========================================================
  // JUMLAH KANTONG
  // ==========================================================

  Future<int> getGoalCount({
    bool includeArchived = false,
  }) {
    return _runSerialized(() async {
      final goals = await _readGoalsInternal();

      if (includeArchived) {
        return goals.length;
      }

      return goals
          .where((goal) => !goal.isArchived)
          .length;
    });
  }

  // ==========================================================
  // CEK APAKAH SUDAH ADA KANTONG
  // ==========================================================

  Future<bool> hasGoals() {
    return _runSerialized(() async {
      final goals = await _readGoalsInternal();

      return goals.any(
        (goal) => !goal.isArchived,
      );
    });
  }
}