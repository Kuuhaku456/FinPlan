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

  final int totalSaved;
  final int totalTarget;
  final int activeGoals;
  final int completedGoals;
  final int archivedGoals;

  int get remainingTarget {
    final remaining = totalTarget - totalSaved;
    return remaining < 0 ? 0 : remaining;
  }

  double get progress {
    if (totalTarget <= 0) return 0;

    return (totalSaved / totalTarget)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double get progressPercent => progress * 100;

  bool get isEmpty => activeGoals == 0;
}

// ============================================================
// SAVINGS REPOSITORY
// ============================================================

class SavingsRepository {
  SavingsRepository({
    SharedPreferencesAsync? preferences,
  }) : _providedPreferences = preferences;

  // ==========================================================
  // KONFIGURASI PENYIMPANAN
  // ==========================================================

  static const String _storageKey =
      'finplan.savings_goals.v1';

  static const int _schemaVersion = 1;

  // ==========================================================
  // PERBAIKAN: LAZY INITIALIZATION
  // ==========================================================

  // Menyimpan instance SharedPreferencesAsync
  // yang diberikan dari luar, jika ada.
  final SharedPreferencesAsync? _providedPreferences;

  // SharedPreferencesAsync baru dibuat ketika digunakan.
  // Dengan demikian, constructor SavingsRepository tidak
  // langsung mengakses plugin platform.
  //
  // Ini membantu Fake Repository dalam unit test yang
  // menggunakan extends SavingsRepository.
  late final SharedPreferencesAsync _preferences =
      _providedPreferences ?? SharedPreferencesAsync();

  // ==========================================================
  // ANTREAN OPERASI
  // ==========================================================

  // Operasi penyimpanan dijalankan berurutan agar
  // perubahan data tidak saling menimpa.

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
  // MEMBACA DATA DARI PENYIMPANAN
  // ==========================================================

  Future<List<SavingsGoal>> _readGoalsInternal() async {
    final rawData = await _preferences.getString(
      _storageKey,
    );

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

    if (decoded is Map) {
      final versionValue = decoded['version'];

      final version = versionValue is int
          ? versionValue
          : int.tryParse(
                versionValue?.toString() ?? '',
              ) ??
              1;

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
    } else if (decoded is List) {
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
  // MENYIMPAN DATA
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
  // HELPER MENCARI KANTONG
  // ==========================================================

  int _findGoalIndex(
    List<SavingsGoal> goals,
    String goalId,
  ) {
    return goals.indexWhere(
      (goal) => goal.id == goalId,
    );
  }

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
  // HELPER EDIT INFORMASI KANTONG
  // ==========================================================

  // Hanya mengubah informasi kantong.
  // Saldo dan riwayat tabungan tetap dipertahankan.

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
  // MEMUAT SEMUA KANTONG
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

      filtered.sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );

      return List<SavingsGoal>.unmodifiable(
        filtered,
      );
    });
  }

  // ==========================================================
  // ALIAS LOAD GOALS
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

  Future<SavingsGoal?> getGoalById(
    String goalId,
  ) {
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
  // SIMPAN KANTONG (CREATE ATAU EDIT)
  // ==========================================================

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
  // EDIT KANTONG
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
  // ARSIPKAN KANTONG
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
  // PULIHKAN KANTONG DARI ARSIP
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
  // RIWAYAT TABUNGAN
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

      movements.sort(
        (a, b) => b.date.compareTo(a.date),
      );

      return List<SavingsMovement>.unmodifiable(
        movements,
      );
    });
  }

  // ==========================================================
  // RINGKASAN TABUNGAN
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
  // MEMBACA KANTONG ARSIP
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
  // CEK APAKAH ADA KANTONG AKTIF
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