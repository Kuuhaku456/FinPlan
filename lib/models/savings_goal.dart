import 'dart:convert';
import 'dart:math';

// ============================================================
// GENERATOR ID SEDERHANA
// ============================================================

int _savingsIdCounter = 0;

String _generateSavingsId(String prefix) {
  _savingsIdCounter++;

  final timestamp = DateTime.now().microsecondsSinceEpoch;

  return '${prefix}_${timestamp}_$_savingsIdCounter';
}

// ============================================================
// HELPER JSON
// ============================================================

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _readDate(Object? value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}

// ============================================================
// JENIS AKTIVITAS TABUNGAN
// ============================================================

enum SavingsMovementType {
  deposit,
  withdrawal,
}

extension SavingsMovementTypeLabel on SavingsMovementType {
  String get label {
    switch (this) {
      case SavingsMovementType.deposit:
        return 'Tambah Tabungan';

      case SavingsMovementType.withdrawal:
        return 'Ambil Tabungan';
    }
  }
}

// ============================================================
// MODEL RIWAYAT TABUNGAN
// ============================================================

class SavingsMovement {
  SavingsMovement({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.note = '',
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('ID aktivitas tidak boleh kosong.');
    }

    if (amount <= 0) {
      throw ArgumentError(
        'Nominal aktivitas harus lebih besar dari Rp0.',
      );
    }
  }

  final String id;

  final SavingsMovementType type;

  final int amount;

  final DateTime date;

  final String note;

  // ==========================================================
  // NOMINAL POSITIF / NEGATIF
  // ==========================================================

  int get signedAmount {
    if (type == SavingsMovementType.deposit) {
      return amount;
    }

    return -amount;
  }

  bool get isDeposit {
    return type == SavingsMovementType.deposit;
  }

  // ==========================================================
  // SERIALISASI JSON
  // ==========================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory SavingsMovement.fromJson(
    Map<String, dynamic> json,
  ) {
    final typeName = json['type']?.toString() ?? 'deposit';

    final movementType = SavingsMovementType.values.firstWhere(
      (item) => item.name == typeName,
      orElse: () => SavingsMovementType.deposit,
    );

    return SavingsMovement(
      id: json['id']?.toString() ??
          _generateSavingsId('movement'),
      type: movementType,
      amount: _readInt(json['amount']),
      date: _readDate(json['date']) ?? DateTime.now(),
      note: json['note']?.toString() ?? '',
    );
  }
}

// ============================================================
// MODEL KANTONG TABUNGAN
// ============================================================

class SavingsGoal {
  SavingsGoal({
    required this.id,
    required String name,
    required this.targetAmount,
    this.savedAmount = 0,
    String emoji = '🎯',
    this.description = '',
    this.deadline,
    this.isArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SavingsMovement> movements = const [],
  })  : name = name.trim(),
        emoji = emoji.trim().isEmpty ? '🎯' : emoji.trim(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now(),
        movements = List.unmodifiable(movements) {
    if (id.trim().isEmpty) {
      throw ArgumentError('ID kantong tidak boleh kosong.');
    }

    if (this.name.isEmpty) {
      throw ArgumentError('Nama kantong tidak boleh kosong.');
    }

    if (targetAmount <= 0) {
      throw ArgumentError(
        'Target tabungan harus lebih besar dari Rp0.',
      );
    }

    if (savedAmount < 0) {
      throw ArgumentError(
        'Saldo tabungan tidak boleh negatif.',
      );
    }
  }

  // ==========================================================
  // DATA UTAMA
  // ==========================================================

  final String id;

  final String name;

  final String emoji;

  final String description;

  // Target yang ingin dicapai.
  final int targetAmount;

  // Jumlah uang yang dicatat sudah terkumpul.
  final int savedAmount;

  // Tanggal target, boleh null.
  final DateTime? deadline;

  // Status arsip.
  final bool isArchived;

  // Tanggal dibuat.
  final DateTime createdAt;

  // Terakhir diperbarui.
  final DateTime updatedAt;

  // Riwayat setoran dan pengambilan.
  final List<SavingsMovement> movements;

  // ==========================================================
  // FACTORY MEMBUAT KANTONG BARU
  // ==========================================================

  factory SavingsGoal.create({
    required String name,
    required int targetAmount,
    int initialAmount = 0,
    String emoji = '🎯',
    String description = '',
    DateTime? deadline,
  }) {
    final now = DateTime.now();

    return SavingsGoal(
      id: _generateSavingsId('goal'),
      name: name,
      targetAmount: targetAmount,
      savedAmount: initialAmount,
      emoji: emoji,
      description: description,
      deadline: deadline,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ==========================================================
  // PERHITUNGAN PROGRESS
  // ==========================================================

  // Hasil antara 0.0 sampai 1.0.
  //
  // Contoh:
  // 0.25 = 25%
  // 0.50 = 50%
  // 1.00 = 100%
  double get progress {
    if (targetAmount <= 0) {
      return 0;
    }

    return (savedAmount / targetAmount)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  // Hasil antara 0 sampai 100.
  double get progressPercent {
    return progress * 100;
  }

  // ==========================================================
  // SISA TARGET
  // ==========================================================

  int get remainingAmount {
    return max(0, targetAmount - savedAmount);
  }

  // ==========================================================
  // STATUS TARGET
  // ==========================================================

  bool get isCompleted {
    return savedAmount >= targetAmount;
  }

  bool get hasSavings {
    return savedAmount > 0;
  }

  bool get hasDeadline {
    return deadline != null;
  }

  // ==========================================================
  // SISA HARI MENUJU DEADLINE
  // ==========================================================

  int? get daysRemaining {
    if (deadline == null) {
      return null;
    }

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final targetDate = DateTime(
      deadline!.year,
      deadline!.month,
      deadline!.day,
    );

    return targetDate.difference(today).inDays;
  }

  // ==========================================================
  // CEK TARGET TERLAMBAT
  // ==========================================================

  bool get isOverdue {
    if (deadline == null || isCompleted) {
      return false;
    }

    return (daysRemaining ?? 0) < 0;
  }

  // ==========================================================
  // STATUS TEKS
  // ==========================================================

  String get statusLabel {
    if (isArchived) {
      return 'Diarsipkan';
    }

    if (isCompleted) {
      return 'Target Tercapai';
    }

    if (isOverdue) {
      return 'Melewati Tenggat';
    }

    if (savedAmount == 0) {
      return 'Belum Dimulai';
    }

    return 'Sedang Menabung';
  }

  // ==========================================================
  // TAMBAH TABUNGAN MANUAL
  // ==========================================================

  SavingsGoal addSavings(
    int amount, {
    String note = '',
    DateTime? date,
  }) {
    if (amount <= 0) {
      throw ArgumentError(
        'Nominal tabungan harus lebih besar dari Rp0.',
      );
    }

    if (isArchived) {
      throw StateError(
        'Kantong yang diarsipkan tidak bisa menerima setoran.',
      );
    }

    final now = DateTime.now();

    final movement = SavingsMovement(
      id: _generateSavingsId('movement'),
      type: SavingsMovementType.deposit,
      amount: amount,
      date: date ?? now,
      note: note,
    );

    return copyWith(
      savedAmount: savedAmount + amount,
      updatedAt: now,
      movements: [
        ...movements,
        movement,
      ],
    );
  }

  // ==========================================================
  // AMBIL TABUNGAN MANUAL
  // ==========================================================

  SavingsGoal withdrawSavings(
    int amount, {
    String note = '',
    DateTime? date,
  }) {
    if (amount <= 0) {
      throw ArgumentError(
        'Nominal pengambilan harus lebih besar dari Rp0.',
      );
    }

    if (isArchived) {
      throw StateError(
        'Kantong yang diarsipkan tidak bisa digunakan.',
      );
    }

    if (amount > savedAmount) {
      throw StateError(
        'Jumlah pengambilan melebihi saldo kantong.',
      );
    }

    final now = DateTime.now();

    final movement = SavingsMovement(
      id: _generateSavingsId('movement'),
      type: SavingsMovementType.withdrawal,
      amount: amount,
      date: date ?? now,
      note: note,
    );

    return copyWith(
      savedAmount: savedAmount - amount,
      updatedAt: now,
      movements: [
        ...movements,
        movement,
      ],
    );
  }

  // ==========================================================
  // ARSIPKAN KANTONG
  // ==========================================================

  SavingsGoal archive() {
    return copyWith(
      isArchived: true,
      updatedAt: DateTime.now(),
    );
  }

  // ==========================================================
  // AKTIFKAN KEMBALI KANTONG
  // ==========================================================

  SavingsGoal restore() {
    return copyWith(
      isArchived: false,
      updatedAt: DateTime.now(),
    );
  }

  // ==========================================================
  // COPY WITH
  // ==========================================================

  // Sentinel agar deadline dapat dihapus dengan:
  // goal.copyWith(deadline: null)
  static const Object _unchanged = Object();

  SavingsGoal copyWith({
    String? name,
    String? emoji,
    String? description,
    int? targetAmount,
    int? savedAmount,
    Object? deadline = _unchanged,
    bool? isArchived,
    DateTime? updatedAt,
    List<SavingsMovement>? movements,
  }) {
    final DateTime? newDeadline;

    if (identical(deadline, _unchanged)) {
      newDeadline = this.deadline;
    } else {
      newDeadline = deadline as DateTime?;
    }

    return SavingsGoal(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      deadline: newDeadline,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      movements: movements ?? this.movements,
    );
  }

  // ==========================================================
  // SERIALISASI KE JSON
  // ==========================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'description': description,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'deadline': deadline?.toIso8601String(),
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'movements': movements
          .map((movement) => movement.toJson())
          .toList(),
    };
  }

  // ==========================================================
  // MEMBACA DATA DARI JSON
  // ==========================================================

  factory SavingsGoal.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawMovements = json['movements'];

    final parsedMovements = <SavingsMovement>[];

    if (rawMovements is List) {
      for (final item in rawMovements) {
        if (item is Map) {
          parsedMovements.add(
            SavingsMovement.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    final created = _readDate(json['createdAt']);

    return SavingsGoal(
      id: json['id']?.toString() ??
          _generateSavingsId('goal'),
      name: json['name']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🎯',
      description:
          json['description']?.toString() ?? '',
      targetAmount: _readInt(json['targetAmount']),
      savedAmount: _readInt(json['savedAmount']),
      deadline: _readDate(json['deadline']),
      isArchived: json['isArchived'] == true,
      createdAt: created,
      updatedAt: _readDate(json['updatedAt']) ?? created,
      movements: parsedMovements,
    );
  }

  // ==========================================================
  // KONVERSI LANGSUNG KE STRING JSON
  // ==========================================================

  String toJsonString() {
    return jsonEncode(toJson());
  }

  // ==========================================================
  // MEMBACA STRING JSON
  // ==========================================================

  factory SavingsGoal.fromJsonString(String source) {
    final decoded = jsonDecode(source);

    if (decoded is! Map) {
      throw const FormatException(
        'Format JSON kantong tabungan tidak valid.',
      );
    }

    return SavingsGoal.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  // ==========================================================
  // DEBUG
  // ==========================================================

  @override
  String toString() {
    return 'SavingsGoal('
        'id: $id, '
        'name: $name, '
        'savedAmount: $savedAmount, '
        'targetAmount: $targetAmount, '
        'progress: ${progressPercent.toStringAsFixed(1)}%, '
        'status: $statusLabel'
        ')';
  }
}