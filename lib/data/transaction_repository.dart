
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/finance_transaction.dart';

// ==========================================
// MODEL RINGKASAN TRANSAKSI
// ==========================================

class TransactionSummary {
  const TransactionSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
  });

  // Total uang masuk.
  final int totalIncome;

  // Total uang keluar.
  final int totalExpense;

  // Jumlah transaksi.
  final int transactionCount;

  // Selisih pemasukan dan pengeluaran.
  int get netAmount {
    return totalIncome - totalExpense;
  }

  bool get isEmpty {
    return transactionCount == 0;
  }
}

// ==========================================
// HELPER FILTER QUERY
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
// SQLITE TRANSACTION REPOSITORY
// ==========================================

class TransactionRepository {
  static const String _databaseName =
      'finplan_transactions.db';

  static const String _tableName = 'transactions';

  static const int _databaseVersion = 1;

  Future<Database>? _databaseFuture;

  // ========================================
  // 1. MEMBUKA DATABASE
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
      // Izinkan percobaan ulang jika gagal.
      _databaseFuture = null;
      rethrow;
    }
  }

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
        // Membuat tabel transaksi.
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_date TEXT NOT NULL,
            amount INTEGER NOT NULL CHECK(amount > 0),
            type TEXT NOT NULL
              CHECK(type IN ('income', 'expense')),
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

        // Mempercepat pencarian berdasarkan tanggal.
        await db.execute('''
          CREATE INDEX idx_transactions_date
          ON $_tableName(transaction_date)
        ''');

        // Mempercepat pencarian berdasarkan akun.
        await db.execute('''
          CREATE INDEX idx_transactions_account
          ON $_tableName(account_type, account_name)
        ''');
      },
    );
  }

  // ========================================
  // 2. VALIDASI DATA TRANSAKSI
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
        'Nama bank, e-money, atau akun harus diisi.',
      );
    }

    if (transaction.description.trim().isEmpty) {
      throw ArgumentError(
        'Deskripsi transaksi harus diisi.',
      );
    }
  }

  // ========================================
  // 3. FORMAT TANGGAL DATABASE
  // ========================================

  String _dateText(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ========================================
  // 4. MEMBUAT FILTER QUERY
  // ========================================

  _SqlFilter _buildFilter({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    AccountType? accountType,
    String? accountName,
  }) {
    final conditions = <String>[];
    final arguments = <Object?>[];

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
      conditions.add('transaction_date >= ?');

      arguments.add(
        _dateText(startDate),
      );
    }

    // Filter tanggal akhir, termasuk tanggalnya.
    if (endDate != null) {
      conditions.add('transaction_date <= ?');

      arguments.add(
        _dateText(endDate),
      );
    }

    // Filter pemasukan / pengeluaran.
    if (type != null) {
      conditions.add('type = ?');

      arguments.add(type.name);
    }

    // Filter jenis akun.
    if (accountType != null) {
      conditions.add('account_type = ?');

      arguments.add(accountType.name);
    }

    // Filter nama akun.
    if (accountName != null &&
        accountName.trim().isNotEmpty) {
      conditions.add('account_name = ?');

      arguments.add(accountName.trim());
    }

    return _SqlFilter(
      where: conditions.isEmpty
          ? null
          : conditions.join(' AND '),

      arguments: arguments,
    );
  }

  // ========================================
  // 5. CREATE: MENAMBAHKAN TRANSAKSI
  // ========================================

  Future<int> insertTransaction(
    FinanceTransaction transaction,
  ) async {
    _validateTransaction(transaction);

    final db = await database;

    final data = transaction.toMap();

    // ID dibuat otomatis oleh SQLite.
    data.remove('id');

    // Rapikan input teks.
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
  // 6. READ: MENGAMBIL DAFTAR TRANSAKSI
  // ========================================

  Future<List<FinanceTransaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
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

    return rows
        .map(
          (row) => FinanceTransaction.fromMap(row),
        )
        .toList();
  }

  // ========================================
  // 7. READ: MENGAMBIL TRANSAKSI DARI ID
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
  // 8. UPDATE: MEMPERBARUI TRANSAKSI
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

    final data = transaction.toMap();

    // ID tidak boleh ikut diperbarui.
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
  // 9. DELETE: MENGHAPUS TRANSAKSI
  // ========================================

  Future<bool> deleteTransaction(int id) async {
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
  // 10. MEMBACA ANGKA DARI QUERY
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
  // 11. REKAP PEMASUKAN DAN PENGELUARAN
  // ========================================

  Future<TransactionSummary> getSummary({
    DateTime? startDate,
    DateTime? endDate,
    AccountType? accountType,
    String? accountName,
  }) async {
    final db = await database;

    final filter = _buildFilter(
      startDate: startDate,
      endDate: endDate,
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
  // 12. REKAP BERDASARKAN BULAN
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
  // 13. REKAP BERDASARKAN AKUN
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
  // 14. MENUTUP KONEKSI DATABASE
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
