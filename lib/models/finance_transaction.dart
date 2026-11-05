// ==========================================
// FINPLAN TRANSACTION MODEL
// ==========================================
//
// Mencatat:
// - Pemasukan dan pengeluaran
// - Tanggal transaksi
// - Nominal uang
// - Jenis akun
// - Nama bank / e-money / tunai
// - Deskripsi transaksi
//
// Nominal menggunakan int (Rupiah).
// ==========================================

// ==========================================
// 1. JENIS TRANSAKSI
// ==========================================

enum TransactionType {
  income,
  expense,
}

// ==========================================
// 2. JENIS AKUN
// ==========================================

enum AccountType {
  bank,
  eMoney,
  cash,
  other,
}

// ==========================================
// 3. LABEL JENIS TRANSAKSI
// ==========================================

extension TransactionTypeLabel on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.income:
        return 'Pemasukan';

      case TransactionType.expense:
        return 'Pengeluaran';
    }
  }
}

// ==========================================
// 4. LABEL JENIS AKUN
// ==========================================

extension AccountTypeLabel on AccountType {
  String get label {
    switch (this) {
      case AccountType.bank:
        return 'Bank';

      case AccountType.eMoney:
        return 'E-Money';

      case AccountType.cash:
        return 'Tunai';

      case AccountType.other:
        return 'Lainnya';
    }
  }
}

// ==========================================
// 5. MODEL TRANSAKSI UTAMA
// ==========================================

class FinanceTransaction {
  FinanceTransaction({
    this.id,
    required this.date,
    required this.amount,
    required this.type,
    required this.accountType,
    required this.accountName,
    required this.description,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ID database. Null untuk transaksi baru.
  final int? id;

  // Tanggal transaksi.
  final DateTime date;

  // Nominal dalam Rupiah.
  final int amount;

  // Pemasukan atau pengeluaran.
  final TransactionType type;

  // Bank, e-money, tunai, atau lainnya.
  final AccountType accountType;

  // Contoh: BCA, Krom Bank, DANA.
  final String accountName;

  // Tujuan atau keterangan transaksi.
  final String description;

  // Waktu saat catatan dibuat.
  final DateTime createdAt;

  // ========================================
  // 6. NOMINAL BERTANDA
  // ========================================

  // Pemasukan positif.
  // Pengeluaran negatif.
  int get signedAmount {
    return type == TransactionType.income
        ? amount
        : -amount;
  }

  // ========================================
  // 7. FORMAT TANGGAL UNTUK DATABASE
  // ========================================

  String get dateString {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ========================================
  // 8. MENGUBAH TRANSAKSI KE MAP
  // ========================================

  Map<String, Object?> toMap() {
    final data = <String, Object?>{
      'transaction_date': dateString,
      'amount': amount,
      'type': type.name,
      'account_type': accountType.name,
      'account_name': accountName,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
    };

    if (id != null) {
      data['id'] = id;
    }

    return data;
  }

  // ========================================
  // 9. MEMBACA JENIS TRANSAKSI
  // ========================================

  static TransactionType _readTransactionType(
    dynamic value,
  ) {
    for (final type in TransactionType.values) {
      if (type.name == value) {
        return type;
      }
    }

    return TransactionType.expense;
  }

  // ========================================
  // 10. MEMBACA JENIS AKUN
  // ========================================

  static AccountType _readAccountType(
    dynamic value,
  ) {
    for (final type in AccountType.values) {
      if (type.name == value) {
        return type;
      }
    }

    return AccountType.other;
  }

  // ========================================
  // 11. MEMBACA TRANSAKSI DARI DATABASE
  // ========================================

  factory FinanceTransaction.fromMap(
    Map<String, Object?> map,
  ) {
    final dateValue =
        map['transaction_date']?.toString() ?? '';

    final createdAtValue = map['created_at'];

    return FinanceTransaction(
      id: (map['id'] as num?)?.toInt(),

      date: DateTime.tryParse(dateValue) ??
          DateTime.now(),

      amount: (map['amount'] as num?)?.toInt() ?? 0,

      type: _readTransactionType(
        map['type'],
      ),

      accountType: _readAccountType(
        map['account_type'],
      ),

      accountName:
          map['account_name']?.toString() ?? '',

      description:
          map['description']?.toString() ?? '',

      createdAt: createdAtValue is num
          ? DateTime.fromMillisecondsSinceEpoch(
              createdAtValue.toInt(),
            )
          : DateTime.now(),
    );
  }

  // ========================================
  // 12. COPY TRANSAKSI
  // ========================================

  FinanceTransaction copyWith({
    DateTime? date,
    int? amount,
    TransactionType? type,
    AccountType? accountType,
    String? accountName,
    String? description,
  }) {
    return FinanceTransaction(
      id: id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      accountType: accountType ?? this.accountType,
      accountName: accountName ?? this.accountName,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}
