import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../lib/data/transaction_repository.dart';
import '../lib/models/finance_transaction.dart';
import '../lib/models/transaction_category.dart';
import '../lib/services/transaction_csv_import_service.dart';

// ======================================================
// FINPLAN - TRANSACTION CSV IMPORT SERVICE TEST
// ======================================================
//
// Tujuan:
// 1. Menguji keberhasilan import CSV.
// 2. Mencegah transaksi duplikat.
// 3. Memastikan preview tidak mengubah database.
// 4. Memvalidasi file CSV yang rusak.
// 5. Mendukung deskripsi dengan koma dan baris baru.
//
// Database menggunakan SQLite in-memory.
// Data transaksi asli pengguna tidak akan diubah.
// ======================================================

// Repository khusus untuk pengujian.
class _MemoryTransactionRepository extends TransactionRepository {
  _MemoryTransactionRepository(this._testDatabase);

  final Database _testDatabase;

  @override
  Future<Database> get database async => _testDatabase;
}

// Header harus mengikuti format dari CSV Export Service.
const String _csvHeader =
    'ID,Tanggal,Jenis Transaksi,Kategori,'
    'Nominal (Rp),Perubahan Saldo (Rp),'
    'Jenis Akun,Nama Akun,Deskripsi,Waktu Pencatatan';

// Membuat isi CSV lengkap.
String _buildCsv(List<String> rows) {
  return '\uFEFF$_csvHeader\r\n'
      '${rows.join('\r\n')}\r\n';
}

// Contoh transaksi pengeluaran.
String _expenseRow({
  int id = 1,
  String date = '2026-11-08',
  int amount = 50000,
  String description = 'Makan siang',
  String createdAt = '2026-11-08 12:30:00',
}) {
  return '$id,'
      '$date,'
      'Pengeluaran,'
      '${TransactionCategory.food.label},'
      '$amount,'
      '-$amount,'
      'Bank,'
      'BCA,'
      '$description,'
      '$createdAt';
}

// Contoh transaksi pemasukan.
String _incomeRow({
  int id = 2,
  String description = 'Gaji bulanan',
}) {
  return '$id,'
      '2026-11-07,'
      'Pemasukan,'
      '-,'
      '5000000,'
      '5000000,'
      'Bank,'
      'BCA,'
      '$description,'
      '2026-11-07 08:00:00';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late TransactionCsvImportService importService;

  // ====================================================
  // SETUP DATABASE
  // ====================================================

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

    final repository = _MemoryTransactionRepository(database);

    importService = TransactionCsvImportService(repository);
  });

  tearDown(() async {
    await database.close();
  });

  Future<List<FinanceTransaction>> readTransactions() async {
    final rows = await database.query(
      'transactions',
      orderBy: 'id ASC',
    );

    return rows.map(FinanceTransaction.fromMap).toList();
  }

  // ====================================================
  // TEST 1: IMPORT CSV BERHASIL
  // ====================================================

  test('Berhasil import transaksi pemasukan dan pengeluaran', () async {
    final csv = _buildCsv([
      _expenseRow(),
      _incomeRow(),
    ]);

    final result = await importService.importCsv(csv);

    expect(result.totalRows, 2);
    expect(result.importedRows, 2);
    expect(result.duplicateRows, 0);
    expect(result.isSuccess, isTrue);

    final transactions = await readTransactions();

    expect(transactions.length, 2);

    final expense = transactions[0];
    final income = transactions[1];

    expect(expense.id, isNotNull);
    expect(expense.type, TransactionType.expense);
    expect(expense.amount, 50000);
    expect(expense.category, TransactionCategory.food);
    expect(expense.accountName, 'BCA');
    expect(expense.description, 'Makan siang');

    expect(income.id, isNotNull);
    expect(income.type, TransactionType.income);
    expect(income.amount, 5000000);

    final totalIncome = transactions
        .where((transaction) => transaction.type == TransactionType.income)
        .fold<int>(0, (sum, transaction) => sum + transaction.amount);

    final totalExpense = transactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .fold<int>(0, (sum, transaction) => sum + transaction.amount);

    expect(totalIncome, 5000000);
    expect(totalExpense, 50000);
  });

  // ====================================================
  // TEST 2: MENCEGAH DUPLIKAT
  // ====================================================

  test('Import file yang sama dua kali tidak menggandakan transaksi', () async {
    final csv = _buildCsv([
      _expenseRow(),
      _incomeRow(),
    ]);

    final firstResult = await importService.importCsv(csv);

    expect(firstResult.importedRows, 2);

    final secondResult = await importService.importCsv(csv);

    expect(secondResult.totalRows, 2);
    expect(secondResult.importedRows, 0);
    expect(secondResult.duplicateRows, 2);

    final transactions = await readTransactions();

    expect(transactions.length, 2);
  });

  // ====================================================
  // TEST 3: PREVIEW TIDAK MENGUBAH DATABASE
  // ====================================================

  test('Preview menghitung transaksi baru dan duplikat', () async {
    final existingCsv = _buildCsv([
      _expenseRow(),
    ]);

    await importService.importCsv(existingCsv);

    final newCsv = _buildCsv([
      _expenseRow(),
      _incomeRow(),
    ]);

    final preview = await importService.previewCsv(newCsv);

    expect(preview.totalRows, 2);
    expect(preview.importableRows, 1);
    expect(preview.duplicateRows, 1);
    expect(preview.hasData, isTrue);
    expect(preview.canImport, isTrue);

    // Preview tidak boleh menyimpan transaksi baru.
    var transactions = await readTransactions();

    expect(transactions.length, 1);

    // Setelah import, baru jumlah transaksi bertambah.
    final result = await importService.importCsv(newCsv);

    expect(result.importedRows, 1);
    expect(result.duplicateRows, 1);

    transactions = await readTransactions();

    expect(transactions.length, 2);
  });

  // ====================================================
  // TEST 4: CSV TIDAK VALID
  // ====================================================

  test('CSV tidak valid tidak mengubah database', () async {
    // Baris pertama valid.
    // Baris kedua memiliki perubahan saldo yang salah.
    final invalidCsv = _buildCsv([
      _expenseRow(),
      '3,'
          '2026-11-08,'
          'Pengeluaran,'
          '${TransactionCategory.food.label},'
          '25000,'
          '25000,'
          'Bank,'
          'BCA,'
          'Transaksi tidak valid,'
          '2026-11-08 13:00:00',
    ]);

    await expectLater(
      importService.importCsv(invalidCsv),
      throwsA(isA<FormatException>()),
    );

    final transactions = await readTransactions();

    // Tidak boleh ada transaksi yang tersimpan.
    expect(transactions, isEmpty);
  });

  // ====================================================
  // TEST 5: HEADER CSV SALAH
  // ====================================================

  test('Menolak file yang header CSV-nya tidak sesuai', () async {
    const invalidCsv =
        'Tanggal,Nominal,Deskripsi\n'
        '2026-11-08,50000,Makan siang\n';

    await expectLater(
      importService.previewCsv(invalidCsv),
      throwsA(isA<FormatException>()),
    );

    final transactions = await readTransactions();

    expect(transactions, isEmpty);
  });

  // ====================================================
  // TEST 6: DESKRIPSI MENGANDUNG KOMA
  // ====================================================

  test('Membaca deskripsi yang mengandung koma dan baris baru', () async {
    const description = 'Makan, minum\nbelanja mingguan';

    final escapedDescription =
        '"${description.replaceAll('"', '""')}"';

    final csv = _buildCsv([
      _expenseRow(
        description: escapedDescription,
      ),
    ]);

    final result = await importService.importCsv(csv);

    expect(result.importedRows, 1);

    final transactions = await readTransactions();

    expect(transactions.length, 1);
    expect(transactions.first.description, description);
  });

  // ====================================================
  // TEST 7: BARIS IDENTIK DALAM FILE YANG SAMA
  // ====================================================

  test('Mempertahankan jumlah transaksi identik dalam CSV', () async {
    final transactionRow = _expenseRow();

    // Dua transaksi identik memang ada pada file sumber.
    final csv = _buildCsv([
      transactionRow,
      transactionRow,
    ]);

    final firstResult = await importService.importCsv(csv);

    expect(firstResult.importedRows, 2);
    expect(firstResult.duplicateRows, 0);

    var transactions = await readTransactions();

    expect(transactions.length, 2);

    // Ketika file diimpor lagi, keduanya dikenali.
    final secondResult = await importService.importCsv(csv);

    expect(secondResult.importedRows, 0);
    expect(secondResult.duplicateRows, 2);

    transactions = await readTransactions();

    expect(transactions.length, 2);
  });
}