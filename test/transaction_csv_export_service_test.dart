import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../lib/data/transaction_repository.dart';
import '../lib/models/finance_transaction.dart';
import '../lib/models/transaction_category.dart';
import '../lib/services/transaction_csv_export_service.dart';
import '../lib/services/transaction_csv_import_service.dart';

// ============================================================
// FINPLAN - CSV EXPORT & BACKUP RESTORE TEST
// ============================================================

// Repository SQLite sementara untuk testing.
class _TestTransactionRepository extends TransactionRepository {
  _TestTransactionRepository(this._testDatabase);

  final Database _testDatabase;

  @override
  Future<Database> get database async => _testDatabase;
}

// Membuat transaksi contoh.
FinanceTransaction _createExpense({
  String description = 'Makan siang',
  String accountName = 'BCA',
}) {
  return FinanceTransaction(
    id: 1,
    date: DateTime(2026, 11, 8),
    amount: 50000,
    type: TransactionType.expense,
    category: TransactionCategory.food,
    accountType: AccountType.bank,
    accountName: accountName,
    description: description,
    createdAt: DateTime(2026, 11, 8, 12, 30),
  );
}

FinanceTransaction _createIncome() {
  return FinanceTransaction(
    id: 2,
    date: DateTime(2026, 11, 7),
    amount: 5000000,
    type: TransactionType.income,
    category: TransactionCategory.other,
    accountType: AccountType.bank,
    accountName: 'BCA',
    description: 'Gaji bulanan',
    createdAt: DateTime(2026, 11, 7, 8, 0),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // GROUP 1: EXPORT CSV
  // ==========================================================

  group('Transaction CSV Export', () {
    test('CSV memiliki BOM UTF-8 dan header yang sesuai', () {
      final csv = TransactionCsvExportService.buildCsv([
        _createExpense(),
      ]);

      expect(csv.startsWith('\uFEFF'), isTrue);

      expect(
        csv,
        contains(
          'ID,Tanggal,Jenis Transaksi,Kategori,'
          'Nominal (Rp),Perubahan Saldo (Rp),'
          'Jenis Akun,Nama Akun,Deskripsi,Waktu Pencatatan',
        ),
      );

      expect(csv, contains('\r\n'));
    });

    test('Export pemasukan dan pengeluaran menggunakan tanda saldo benar', () {
      final csv = TransactionCsvExportService.buildCsv([
        _createExpense(),
        _createIncome(),
      ]);

      // Pengeluaran Rp50.000.
      expect(csv, contains(',50000,-50000,'));

      // Pemasukan Rp5.000.000.
      expect(csv, contains(',5000000,5000000,'));

      expect(csv, contains('Pengeluaran'));
      expect(csv, contains('Pemasukan'));
      expect(csv, contains('Gaji bulanan'));
    });

    test('Deskripsi dengan koma dan tanda kutip berhasil diekspor', () {
      final transaction = _createExpense(
        description: 'Makan "siang", ayam goreng',
      );

      final csv = TransactionCsvExportService.buildCsv([
        transaction,
      ]);

      // Tanda kutip harus digandakan dalam format CSV.
      expect(
        csv,
        contains('"Makan ""siang"", ayam goreng"'),
      );
    });

    test('Deskripsi dengan baris baru tidak hilang', () {
      final transaction = _createExpense(
        description: 'Belanja harian\nBeras dan telur',
      );

      final csv = TransactionCsvExportService.buildCsv([
        transaction,
      ]);

      expect(
        csv,
        contains('"Belanja harian\nBeras dan telur"'),
      );
    });

    test('Teks yang menyerupai rumus spreadsheet diberi pengaman', () {
      final transaction = _createExpense(
        description: '=2+2',
        accountName: '@contoh',
      );

      final csv = TransactionCsvExportService.buildCsv([
        transaction,
      ]);

      // Apostrof mencegah teks diawali simbol rumus.
      expect(csv, contains("\"'=2+2\""));
      expect(csv, contains("\"'@contoh\""));
    });
  });

  // ==========================================================
  // GROUP 2: BACKUP & RESTORE
  // ==========================================================

  group('Transaction CSV Backup Restore', () {
    late Database database;
    late TransactionCsvImportService importService;

    setUpAll(() {
      sqfliteFfiInit();
    });

    setUp(() async {
      database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );

      await database.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_date TEXT NOT NULL,
          amount INTEGER NOT NULL CHECK (amount > 0),
          type TEXT NOT NULL,
          account_type TEXT NOT NULL,
          account_name TEXT NOT NULL,
          description TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          category TEXT NOT NULL DEFAULT 'other'
        )
      ''');

      final repository = _TestTransactionRepository(database);

      importService = TransactionCsvImportService(repository);
    });

    tearDown(() async {
      await database.close();
    });

    test('Backup CSV dapat di-restore menjadi transaksi SQLite', () async {
      // ======================================================
      // 1. Siapkan transaksi asli.
      // ======================================================

      final originalTransactions = [
        _createExpense(),
        _createIncome(),
      ];

      // ======================================================
      // 2. Export transaksi menjadi CSV.
      // ======================================================

      final csv = TransactionCsvExportService.buildCsv(
        originalTransactions,
      );

      expect(csv.isNotEmpty, isTrue);

      // ======================================================
      // 3. Preview sebelum restore.
      // ======================================================

      final preview = await importService.previewCsv(csv);

      expect(preview.totalRows, 2);
      expect(preview.importableRows, 2);
      expect(preview.duplicateRows, 0);

      // Database masih kosong sebelum import.
      final beforeRestore = await database.query('transactions');

      expect(beforeRestore, isEmpty);

      // ======================================================
      // 4. Restore dari CSV.
      // ======================================================

      final result = await importService.importCsv(csv);

      expect(result.importedRows, 2);
      expect(result.duplicateRows, 0);

      // ======================================================
      // 5. Periksa data setelah restore.
      // ======================================================

      final rows = await database.query(
        'transactions',
        orderBy: 'id ASC',
      );

      expect(rows.length, 2);

      final restoredTransactions = rows
          .map(FinanceTransaction.fromMap)
          .toList();

      final restoredExpense = restoredTransactions.firstWhere(
        (transaction) => transaction.type == TransactionType.expense,
      );

      final restoredIncome = restoredTransactions.firstWhere(
        (transaction) => transaction.type == TransactionType.income,
      );

      expect(restoredExpense.amount, 50000);
      expect(restoredExpense.category, TransactionCategory.food);
      expect(restoredExpense.accountName, 'BCA');
      expect(restoredExpense.description, 'Makan siang');
      expect(restoredExpense.dateString, '2026-11-08');

      expect(restoredIncome.amount, 5000000);
      expect(restoredIncome.type, TransactionType.income);
      expect(restoredIncome.description, 'Gaji bulanan');
      expect(restoredIncome.dateString, '2026-11-07');
    });

    test('Restore ulang file backup tidak menggandakan transaksi', () async {
      final csv = TransactionCsvExportService.buildCsv([
        _createExpense(),
        _createIncome(),
      ]);

      // Restore pertama.
      final firstRestore = await importService.importCsv(csv);

      expect(firstRestore.importedRows, 2);

      // Restore kedua dengan CSV yang sama.
      final secondRestore = await importService.importCsv(csv);

      expect(secondRestore.importedRows, 0);
      expect(secondRestore.duplicateRows, 2);

      final rows = await database.query('transactions');

      // Jumlah transaksi harus tetap dua.
      expect(rows.length, 2);
    });

    test('Deskripsi dengan koma dan baris baru tetap sama setelah restore', () async {
      const originalDescription =
          'Belanja, makan siang\nBeras dan telur';

      final csv = TransactionCsvExportService.buildCsv([
        _createExpense(
          description: originalDescription,
        ),
      ]);

      final result = await importService.importCsv(csv);

      expect(result.importedRows, 1);

      final rows = await database.query('transactions');

      expect(rows.length, 1);

      final restoredTransaction = FinanceTransaction.fromMap(
        rows.first,
      );

      expect(
        restoredTransaction.description,
        originalDescription,
      );
    });
  });
}