// ==========================================
// FINPLAN - FINANCE TRANSACTION MODEL
// ==========================================
//
// Model untuk menyimpan transaksi keuangan.
//
// Mendukung:
// - Pemasukan dan pengeluaran
// - Tanggal transaksi
// - Nominal Rupiah
// - Kategori transaksi
// - Jenis akun
// - Nama bank / e-money / tunai
// - Deskripsi transaksi
// - Penyimpanan SQLite
// - Edit transaksi
//
// ==========================================

import 'transaction_category.dart';

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
// 5. FINANCE TRANSACTION MODEL
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
    this.category = TransactionCategory.other,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ========================================
  // DATABASE ID
  // ========================================

  /// ID transaksi dari SQLite.
  /// Null ketika transaksi belum disimpan.
  final int? id;

  // ========================================
  // TRANSACTION DATE
  // ========================================

  /// Tanggal terjadinya transaksi.
  final DateTime date;

  // ========================================
  // TRANSACTION AMOUNT
  // ========================================

  /// Nominal dalam Rupiah.
  /// Disimpan sebagai integer.
  final int amount;

  // ========================================
  // TRANSACTION TYPE
  // ========================================

  /// Pemasukan atau pengeluaran.
  final TransactionType type;

  // ========================================
  // TRANSACTION CATEGORY
  // ========================================

  /// Kategori transaksi.
  ///
  /// Contoh:
  /// - food
  /// - transport
  /// - bills
  /// - healthcare
  ///
  /// Nilai default adalah other agar transaksi
  /// lama tetap kompatibel.
  final TransactionCategory category;

  // ========================================
  // ACCOUNT TYPE
  // ========================================

  /// Jenis akun yang digunakan.
  final AccountType accountType;

  // ========================================
  // ACCOUNT NAME
  // ========================================

  /// Contoh:
  /// - BCA
  /// - Krom Bank
  /// - DANA
  /// - GoPay
  /// - Tunai
  final String accountName;

  // ========================================
  // DESCRIPTION
  // ========================================

  /// Keterangan transaksi.
  ///
  /// Contoh:
  /// "Makan siang"
  /// "Naik KRL"
  /// "Bayar listrik"
  final String description;

  // ========================================
  // CREATED AT
  // ========================================

  /// Waktu transaksi dicatat.
  final DateTime createdAt;

  // ========================================
  // 6. NOMINAL BERTANDA
  // ========================================

  /// Pemasukan bernilai positif.
  /// Pengeluaran bernilai negatif.
  int get signedAmount {
    return type == TransactionType.income
        ? amount
        : -amount;
  }

  // ========================================
  // 7. HELPER JENIS TRANSAKSI
  // ========================================

  bool get isIncome {
    return type == TransactionType.income;
  }

  bool get isExpense {
    return type == TransactionType.expense;
  }

  // ========================================
  // 8. LABEL KATEGORI
  // ========================================

  String get categoryLabel {
    return category.label;
  }

  String get categoryEmoji {
    return category.emoji;
  }

  // ========================================
  // 9. FORMAT TANGGAL DATABASE
  // ========================================

  String get dateString {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ========================================
  // 10. CONVERT TRANSACTION TO MAP
  // ========================================

  /// Mengubah transaksi menjadi Map SQLite.
  ///
  /// includeCategory masih false secara default
  /// agar kompatibel dengan database versi lama.
  ///
  /// Setelah migrasi SQLite selesai, repository
  /// akan menggunakan includeCategory: true.
  Map<String, Object?> toMap({
    bool includeCategory = false,
  }) {
    final data = <String, Object?>{
      'transaction_date': dateString,
      'amount': amount,
      'type': type.name,
      'account_type': accountType.name,
      'account_name': accountName,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
    };

    // Kategori hanya disertakan jika
    // struktur SQLite sudah mendukungnya.
    if (includeCategory) {
      data['category'] = category.databaseValue;
    }

    if (id != null) {
      data['id'] = id;
    }

    return data;
  }

  // ========================================
  // 11. READ TRANSACTION TYPE
  // ========================================

  static TransactionType _readTransactionType(
    dynamic value,
  ) {
    for (final transactionType in TransactionType.values) {
      if (transactionType.name == value) {
        return transactionType;
      }
    }

    return TransactionType.expense;
  }

  // ========================================
  // 12. READ ACCOUNT TYPE
  // ========================================

  static AccountType _readAccountType(
    dynamic value,
  ) {
    for (final accountType in AccountType.values) {
      if (accountType.name == value) {
        return accountType;
      }
    }

    return AccountType.other;
  }

  // ========================================
  // 13. READ CATEGORY
  // ========================================

  static TransactionCategory _readCategory(
    dynamic value,
  ) {
    return TransactionCategoryExtension.fromDatabase(
      value,
    );
  }

  // ========================================
  // 14. CONVERT MAP TO TRANSACTION
  // ========================================

  /// Membaca data transaksi dari SQLite.
  ///
  /// Apabila kolom kategori belum tersedia,
  /// otomatis menggunakan kategori other.
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

      category: _readCategory(
        map['category'],
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
  // 15. COPY TRANSACTION
  // ========================================

  /// Digunakan ketika mengedit transaksi.
  ///
  /// Data yang tidak diubah akan menggunakan
  /// nilai dari transaksi sebelumnya.
  FinanceTransaction copyWith({
    DateTime? date,
    int? amount,
    TransactionType? type,
    TransactionCategory? category,
    AccountType? accountType,
    String? accountName,
    String? description,
  }) {
    return FinanceTransaction(
      id: id,

      date: date ?? this.date,

      amount: amount ?? this.amount,

      type: type ?? this.type,

      category: category ?? this.category,

      accountType: accountType ?? this.accountType,

      accountName: accountName ?? this.accountName,

      description: description ?? this.description,

      createdAt: createdAt,
    );
  }
}