import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/finance_transaction.dart';
import '../models/transaction_category.dart';

// ==========================================
// FINPLAN - TRANSACTION REPOSITORY
// ==========================================
//
// SQLite Database Version 2
//
// Fitur:
// - Menambah transaksi
// - Menampilkan transaksi
// - Mengedit transaksi
// - Menghapus transaksi
// - Filter berdasarkan tanggal
// - Filter berdasarkan jenis akun
// - Filter berdasarkan kategori
// - Rekap pemasukan dan pengeluaran
// - Rekap bulanan
// - Rekap berdasarkan akun
// - Rekap pengeluaran per kategori
// - Migrasi database otomatis
//
// ==========================================


// ==========================================
// 1. TRANSACTION SUMMARY MODEL
// ==========================================

class TransactionSummary {
  const TransactionSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
  });

  final int totalIncome;
  final int totalExpense;
  final int transactionCount;

  int get netAmount {
    return totalIncome - totalExpense;
  }

  bool get isEmpty {
    return transactionCount == 0;
  }
}


// ==========================================
// 2. EXPENSE CATEGORY SUMMARY MODEL
// ==========================================

class ExpenseCategorySummary {
  const ExpenseCategorySummary({
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
  });

  final TransactionCategory category;

  final int totalAmount;

  final int transactionCount;

  String get categoryName {
    return category.label;
  }

  String get categoryEmoji {
    return category.emoji;
  }
}


// ==========================================
// 3. SQL FILTER HELPER
// ==========================================

class _SqlFilter {
  const _SqlFilter({
    required this.where,
    required this.arguments,
  });

  final String? where;

  final List<Object?> arguments;
}


// ==========================================
// 4. TRANSACTION REPOSITORY
// ==========================================

class TransactionRepository {
  static const String _databaseName =
      'finplan_transactions.db';

  static const String _tableName = 'transactions';

  // Versi sebelumnya: 1
  // Versi sekarang: 2
  static const int _databaseVersion = 2;

  Future<Database>? _databaseFuture;


  // ========================================
  // 5. DATABASE INSTANCE
  // ========================================

  Future<Database> get database async {
    if (_databaseFuture != null) {
      return _databaseFuture!;
    }

    final future = _openDatabase();

    _databaseFuture = future;

    try {
      return await future;
    } catch (_) {
      _databaseFuture = null;
      rethrow;
    }
  }


  // ========================================
  // 6. OPEN DATABASE
  // ========================================

  Future<Database> _openDatabase() async {
    final databaseDirectory =
        await getDatabasesPath();

    final databasePath = join(
      databaseDirectory,
      _databaseName,
    );

    return openDatabase(
      databasePath,

      version: _databaseVersion,

      onCreate: (db, version) async {
        await _createTables(db);
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        // Migrasi dari versi 1 ke versi 2.
        if (oldVersion < 2) {
          await _migrateToVersion2(db);
        }
      },
    );
  }


  // ========================================
  // 7. CREATE TABLES
  // ========================================

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        transaction_date TEXT NOT NULL,

        amount INTEGER NOT NULL
          CHECK(amount > 0),

        type TEXT NOT NULL
          CHECK(type IN ('income', 'expense')),

        category TEXT NOT NULL
          DEFAULT 'other',

        account_type TEXT NOT NULL
          CHECK(account_type IN (
            'bank',
            'eMoney',
            'cash',
            'other'
          )),

        account_name TEXT NOT NULL,

        description TEXT NOT NULL,

        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_date
      ON $_tableName(transaction_date)
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_account
      ON $_tableName(account_type, account_name)
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_category_date
      ON $_tableName(category, transaction_date)
    ''');
  }


  // ========================================
  // 8. MIGRATION VERSION 2
  // ========================================

  /// Migrasi database tanpa menghapus
  /// transaksi yang sudah tersimpan.
  ///
  /// Semua transaksi lama otomatis memiliki
  /// kategori 'other'.
  Future<void> _migrateToVersion2(
    Database db,
  ) async {
    await db.execute('''
      ALTER TABLE $_tableName
      ADD COLUMN category TEXT NOT NULL
      DEFAULT 'other'
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_category_date
      ON $_tableName(category, transaction_date)
    ''');
  }


  // ========================================
  // 9. VALIDATE TRANSACTION
  // ========================================

  void _validateTransaction(
    FinanceTransaction transaction,
  ) {
    if (transaction.amount <= 0) {
      throw ArgumentError(
        'Nominal transaksi harus lebih dari 0.',
      );
    }

    if (transaction.accountName.trim().isEmpty) {
      throw ArgumentError(
        'Nama akun harus diisi.',
      );
    }

    if (transaction.description.trim().isEmpty) {
      throw ArgumentError(
        'Deskripsi transaksi harus diisi.',
      );
    }
  }


  // ========================================
  // 10. DATE FORMAT
  // ========================================

  String _dateText(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }


  // ========================================
  // 11. SQL FILTER BUILDER
  // ========================================

  _SqlFilter _buildFilter({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    TransactionCategory? category,
    AccountType? accountType,
    String? accountName,
  }) {
    final conditions = <String>[];

    final arguments = <Object?>[];

    // Validasi rentang tanggal.
    if (startDate != null && endDate != null) {
      if (_dateText(startDate)
              .compareTo(_dateText(endDate)) >
          0) {
        throw ArgumentError(
          'Tanggal awal tidak boleh melewati tanggal akhir.',
        );
      }
    }

    // Filter tanggal awal.
    if (startDate != null) {
      conditions.add(
        'transaction_date >= ?',
      );

      arguments.add(
        _dateText(startDate),
      );
    }

    // Filter tanggal akhir.
    if (endDate != null) {
      conditions.add(
        'transaction_date <= ?',
      );

      arguments.add(
        _dateText(endDate),
      );
    }

    // Filter jenis transaksi.
    if (type != null) {
      conditions.add(
        'type = ?',
      );

      arguments.add(
        type.name,
      );
    }

    // Filter kategori.
    if (category != null) {
      conditions.add(
        'category = ?',
      );

      arguments.add(
        category.databaseValue,
      );
    }

    // Filter jenis akun.
    if (accountType != null) {
      conditions.add(
        'account_type = ?',
      );

      arguments.add(
        accountType.name,
      );
    }

    // Filter nama akun.
    if (accountName != null &&
        accountName.trim().isNotEmpty) {
      conditions.add(
        'account_name = ?',
      );

      arguments.add(
        accountName.trim(),
      );
    }

    return _SqlFilter(
      where: conditions.isEmpty
          ? null
          : conditions.join(' AND '),

      arguments: arguments,
    );
  }


  // ========================================
  // 12. INSERT TRANSACTION
  // ========================================

  Future<int> insertTransaction(
    FinanceTransaction transaction,
  ) async {
    _validateTransaction(transaction);

    final db = await database;

    // Kategori sekarang ikut disimpan.
    final data = transaction.toMap(
      includeCategory: true,
    );

    // ID otomatis dari SQLite.
    data.remove('id');

    data['account_name'] =
        transaction.accountName.trim();

    data['description'] =
        transaction.description.trim();

    final id = await db.insert(
      _tableName,
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return id;
  }


  // ========================================
  // 13. GET TRANSACTIONS
  // ========================================

  Future<List<FinanceTransaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    TransactionCategory? category,
    AccountType? accountType,
    String? accountName,
    int limit = 100,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError(
        'Limit harus antara 1 sampai 500.',
      );
    }

    if (offset < 0) {
      throw ArgumentError(
        'Offset tidak boleh negatif.',
      );
    }

    final db = await database;

    final filter = _buildFilter(
      startDate: startDate,
      endDate: endDate,
      type: type,
      category: category,
      accountType: accountType,
      accountName: accountName,
    );

    final rows = await db.query(
      _tableName,

      where: filter.where,

      whereArgs: filter.arguments.isEmpty
          ? null
          : filter.arguments,

      orderBy:
          'transaction_date DESC, created_at DESC, id DESC',

      limit: limit,

      offset: offset,
    );

    return rows.map((row) {
      return FinanceTransaction.fromMap(row);
    }).toList();
  }


  // ========================================
  // 14. GET TRANSACTION BY ID
  // ========================================

  Future<FinanceTransaction?> getTransactionById(
    int id,
  ) async {
    if (id <= 0) {
      throw ArgumentError(
        'ID transaksi tidak valid.',
      );
    }

    final db = await database;

    final rows = await db.query(
      _tableName,

      where: 'id = ?',

      whereArgs: [id],

      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return FinanceTransaction.fromMap(
      rows.first,
    );
  }


  // ========================================
  // 15. UPDATE TRANSACTION
  // ========================================

  Future<bool> updateTransaction(
    FinanceTransaction transaction,
  ) async {
    _validateTransaction(transaction);

    final id = transaction.id;

    if (id == null || id <= 0) {
      throw ArgumentError(
        'Transaksi harus memiliki ID untuk diedit.',
      );
    }

    final db = await database;

    final data = transaction.toMap(
      includeCategory: true,
    );

    data.remove('id');

    data['account_name'] =
        transaction.accountName.trim();

    data['description'] =
        transaction.description.trim();

    final updatedRows = await db.update(
      _tableName,

      data,

      where: 'id = ?',

      whereArgs: [id],

      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return updatedRows > 0;
  }


  // ========================================
  // 16. DELETE TRANSACTION
  // ========================================

  Future<bool> deleteTransaction(
    int id,
  ) async {
    if (id <= 0) {
      throw ArgumentError(
        'ID transaksi tidak valid.',
      );
    }

    final db = await database;

    final deletedRows = await db.delete(
      _tableName,

      where: 'id = ?',

      whereArgs: [id],
    );

    return deletedRows > 0;
  }


  // ========================================
  // 17. READ INTEGER FROM QUERY
  // ========================================

  int _readInt(
    Map<String, Object?> row,
    String key,
  ) {
    final value = row[key];

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }


  // ========================================
  // 18. TRANSACTION SUMMARY
  // ========================================

  Future<TransactionSummary> getSummary({
    DateTime? startDate,
    DateTime? endDate,
    TransactionCategory? category,
    AccountType? accountType,
    String? accountName,
  }) async {
    final db = await database;

    final filter = _buildFilter(
      startDate: startDate,
      endDate: endDate,
      category: category,
      accountType: accountType,
      accountName: accountName,
    );

    final whereSql = filter.where == null
        ? ''
        : 'WHERE ${filter.where}';

    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(
          SUM(
            CASE
              WHEN type = 'income' THEN amount
              ELSE 0
            END
          ),
          0
        ) AS total_income,

        COALESCE(
          SUM(
            CASE
              WHEN type = 'expense' THEN amount
              ELSE 0
            END
          ),
          0
        ) AS total_expense,

        COUNT(*) AS transaction_count

      FROM $_tableName

      $whereSql
      ''',

      filter.arguments,
    );

    if (rows.isEmpty) {
      return const TransactionSummary(
        totalIncome: 0,
        totalExpense: 0,
        transactionCount: 0,
      );
    }

    final row = rows.first;

    return TransactionSummary(
      totalIncome: _readInt(
        row,
        'total_income',
      ),

      totalExpense: _readInt(
        row,
        'total_expense',
      ),

      transactionCount: _readInt(
        row,
        'transaction_count',
      ),
    );
  }


  // ========================================
  // 19. MONTHLY SUMMARY
  // ========================================

  Future<TransactionSummary> getMonthlySummary({
    required int year,
    required int month,
  }) async {
    if (month < 1 || month > 12) {
      throw ArgumentError(
        'Bulan harus antara 1 dan 12.',
      );
    }

    final firstDay = DateTime(
      year,
      month,
      1,
    );

    final lastDay = DateTime(
      year,
      month + 1,
      0,
    );

    return getSummary(
      startDate: firstDay,
      endDate: lastDay,
    );
  }


  // ========================================
  // 20. ACCOUNT SUMMARY
  // ========================================

  Future<TransactionSummary> getAccountSummary({
    required AccountType accountType,
    required String accountName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return getSummary(
      accountType: accountType,
      accountName: accountName,
      startDate: startDate,
      endDate: endDate,
    );
  }


  // ========================================
  // 21. EXPENSE CATEGORY SUMMARY
  // ========================================

  /// Menghitung total pengeluaran
  /// berdasarkan kategori.
  ///
  /// Menggunakan query SQLite langsung,
  /// sehingga tidak terpengaruh pagination.
  Future<List<ExpenseCategorySummary>>
      getExpenseCategorySummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    final filter = _buildFilter(
      startDate: startDate,
      endDate: endDate,
      type: TransactionType.expense,
    );

    final rows = await db.rawQuery(
      '''
      SELECT
        category,

        COALESCE(
          SUM(amount),
          0
        ) AS total_amount,

        COUNT(*) AS transaction_count

      FROM $_tableName

      WHERE ${filter.where}

      GROUP BY category

      ORDER BY
        total_amount DESC,
        category ASC
      ''',

      filter.arguments,
    );

    return rows.map((row) {
      return ExpenseCategorySummary(
        category: TransactionCategoryExtension.fromDatabase(
          row['category'],
        ),

        totalAmount: _readInt(
          row,
          'total_amount',
        ),

        transactionCount: _readInt(
          row,
          'transaction_count',
        ),
      );
    }).toList();
  }


  // ========================================
  // 22. MONTHLY CATEGORY SUMMARY
  // ========================================

  /// Mengambil rekap kategori pengeluaran
  /// untuk satu bulan tertentu.
  Future<List<ExpenseCategorySummary>>
      getMonthlyExpenseCategorySummary({
    required int year,
    required int month,
  }) async {
    if (month < 1 || month > 12) {
      throw ArgumentError(
        'Bulan harus antara 1 dan 12.',
      );
    }

    final firstDay = DateTime(
      year,
      month,
      1,
    );

    final lastDay = DateTime(
      year,
      month + 1,
      0,
    );

    return getExpenseCategorySummary(
      startDate: firstDay,
      endDate: lastDay,
    );
  }


  // ========================================
  // 23. CLOSE DATABASE
  // ========================================

  Future<void> close() async {
    final databaseFuture = _databaseFuture;

    if (databaseFuture == null) {
      return;
    }

    _databaseFuture = null;

    final db = await databaseFuture;

    if (db.isOpen) {
      await db.close();
    }
  }
}