import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../lib/data/transaction_repository.dart';
import '../lib/models/finance_transaction.dart';
import '../lib/models/transaction_category.dart';
import '../lib/state/transaction_controller.dart';
import '../lib/state/transaction_notifier.dart';

// ======================================================
// FINPLAN - TRANSACTION & DASHBOARD INTEGRATION TEST
// ======================================================
//
// Menguji:
// 1. Sinkronisasi transaksi dengan Dashboard.
// 2. Tambah, edit, dan hapus transaksi.
// 3. Filter transaksi berdasarkan bulan.
// 4. Pagination dan akurasi total transaksi.
// 5. Ringkasan transaksi berdasarkan akun.
//
// Menggunakan SQLite sementara (in-memory).
// ======================================================

class _TestTransactionRepository extends TransactionRepository {
  _TestTransactionRepository(this._testDatabase);

  final Database _testDatabase;

  @override
  Future<Database> get database async => _testDatabase;
}

// Membuat transaksi contoh.
FinanceTransaction _transaction({
  int? id,
  required int day,
  int month = 11,
  required int amount,
  required TransactionType type,
  required String description,
  TransactionCategory category = TransactionCategory.other,
  AccountType accountType = AccountType.bank,
  String accountName = 'BCA',
}) {
  return FinanceTransaction(
    id: id,
    date: DateTime(2026, month, day),
    amount: amount,
    type: type,
    category: category,
    accountType: accountType,
    accountName: accountName,
    description: description,
    createdAt: DateTime(2026, month, day, 12),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late _TestTransactionRepository repository;
  late TransactionController controller;

  // ====================================================
  // DATABASE SETUP
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
        amount INTEGER NOT NULL CHECK(amount > 0),
        type TEXT NOT NULL,
        account_type TEXT NOT NULL,
        account_name TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        category TEXT NOT NULL DEFAULT 'other'
      )
    ''');

    repository = _TestTransactionRepository(database);

    controller = TransactionController(
      repository,
      initialMonth: DateTime(2026, 11),
    );
  });

  tearDown(() async {
    controller.dispose();
    await database.close();
  });

  // ====================================================
  // TEST 1: TRANSAKSI DAN DASHBOARD
  // ====================================================

  test(
    'Menambah transaksi memperbarui ringkasan Dashboard',
    () async {
      // Hubungkan controller ke Riverpod.
      final container = ProviderContainer(
        overrides: [
          legacyTransactionControllerProvider.overrideWithValue(
            controller,
          ),
        ],
      );

      addTearDown(container.dispose);

      // Aktifkan provider.
      container.read(transactionStateProvider);

      final notifier = container.read(
        transactionStateProvider.notifier,
      );

      await notifier.loadTransactions();

      // Kondisi awal.
      var state = container.read(transactionStateProvider);

      expect(state.totalIncome, 0);
      expect(state.totalExpense, 0);
      expect(state.netAmount, 0);

      // Tambahkan pemasukan.
      await notifier.addTransaction(
        _transaction(
          day: 2,
          amount: 5000000,
          type: TransactionType.income,
          description: 'Gaji bulanan',
        ),
      );

      state = container.read(transactionStateProvider);

      expect(state.totalIncome, 5000000);
      expect(state.totalExpense, 0);
      expect(state.netAmount, 5000000);

      // Tambahkan pengeluaran.
      await notifier.addTransaction(
        _transaction(
          day: 3,
          amount: 50000,
          type: TransactionType.expense,
          category: TransactionCategory.food,
          description: 'Makan siang',
        ),
      );

      state = container.read(transactionStateProvider);

      expect(state.totalIncome, 5000000);
      expect(state.totalExpense, 50000);
      expect(state.netAmount, 4950000);
      expect(state.transactionCount, 2);
      expect(state.transactions.length, 2);
    },
  );

  // ====================================================
  // TEST 2: CREATE, UPDATE, DELETE
  // ====================================================

  test(
    'Tambah, edit, dan hapus transaksi mengubah total dengan benar',
    () async {
      await controller.loadTransactions();

      // Tambahkan pengeluaran pertama.
      final transactionId = await controller.addTransaction(
        _transaction(
          day: 5,
          amount: 50000,
          type: TransactionType.expense,
          category: TransactionCategory.food,
          description: 'Makan',
        ),
      );

      expect(controller.totalExpense, 50000);
      expect(controller.transactionCount, 1);

      // Edit nominal dari Rp50.000 menjadi Rp80.000.
      final updated = await controller.updateTransaction(
        _transaction(
          id: transactionId,
          day: 5,
          amount: 80000,
          type: TransactionType.expense,
          category: TransactionCategory.food,
          description: 'Makan dan minum',
        ),
      );

      expect(updated, isTrue);
      expect(controller.totalExpense, 80000);

      // Periksa perubahan di database.
      final savedTransaction = await controller.getTransactionById(
        transactionId,
      );

      expect(savedTransaction, isNotNull);
      expect(savedTransaction!.amount, 80000);
      expect(savedTransaction.description, 'Makan dan minum');

      // Hapus transaksi.
      final deleted = await controller.deleteTransaction(
        transactionId,
      );

      expect(deleted, isTrue);
      expect(controller.totalExpense, 0);
      expect(controller.transactionCount, 0);

      // Pastikan data benar-benar hilang.
      final deletedTransaction =
          await controller.getTransactionById(transactionId);

      expect(deletedTransaction, isNull);
    },
  );

  // ====================================================
  // TEST 3: FILTER BULAN
  // ====================================================

  test(
    'Filter bulan hanya menampilkan transaksi pada periode terpilih',
    () async {
      // Transaksi Oktober.
      await repository.insertTransaction(
        _transaction(
          day: 20,
          month: 10,
          amount: 100000,
          type: TransactionType.expense,
          description: 'Belanja Oktober',
        ),
      );

      // Transaksi November.
      await repository.insertTransaction(
        _transaction(
          day: 5,
          month: 11,
          amount: 3000000,
          type: TransactionType.income,
          description: 'Gaji November',
        ),
      );

      // Pilih November.
      await controller.loadTransactions();

      expect(controller.selectedMonth.month, 11);
      expect(controller.totalIncome, 3000000);
      expect(controller.totalExpense, 0);
      expect(controller.transactionCount, 1);

      // Pindah ke Oktober.
      await controller.selectMonth(DateTime(2026, 10));

      expect(controller.selectedMonth.month, 10);
      expect(controller.totalIncome, 0);
      expect(controller.totalExpense, 100000);
      expect(controller.netAmount, -100000);
      expect(controller.transactionCount, 1);

      // Pindah ke Desember yang belum ada transaksi.
      await controller.selectMonth(DateTime(2026, 12));

      expect(controller.totalIncome, 0);
      expect(controller.totalExpense, 0);
      expect(controller.netAmount, 0);
      expect(controller.transactionCount, 0);
      expect(controller.transactions, isEmpty);
    },
  );

  // ====================================================
  // TEST 4: PAGINATION
  // ====================================================

  test(
    'Ringkasan menghitung seluruh transaksi meskipun daftar dipaginasi',
    () async {
      // Tambahkan 55 pengeluaran.
      for (var i = 0; i < 55; i++) {
        await repository.insertTransaction(
          _transaction(
            day: (i % 28) + 1,
            amount: 10000,
            type: TransactionType.expense,
            description: 'Pengeluaran ${i + 1}',
          ),
        );
      }

      // Tambahkan satu pemasukan.
      await repository.insertTransaction(
        _transaction(
          day: 1,
          amount: 1000000,
          type: TransactionType.income,
          description: 'Gaji',
        ),
      );

      await controller.loadTransactions();

      // Total ada 56 transaksi.
      expect(controller.transactionCount, 56);

      // Hanya 50 transaksi dimuat pada halaman pertama.
      expect(controller.transactions.length, 50);

      // Tetapi ringkasan harus mencakup semuanya.
      expect(controller.totalIncome, 1000000);
      expect(controller.totalExpense, 550000);
      expect(controller.netAmount, 450000);

      expect(controller.hasMore, isTrue);

      // Muat transaksi berikutnya.
      await controller.loadMore();

      expect(controller.transactions.length, 56);
      expect(controller.hasMore, isFalse);

      // Total ringkasan tidak boleh berubah.
      expect(controller.totalIncome, 1000000);
      expect(controller.totalExpense, 550000);
      expect(controller.netAmount, 450000);
    },
  );

  // ====================================================
  // TEST 5: RINGKASAN BERDASARKAN AKUN
  // ====================================================

  test(
    'Ringkasan akun BCA tidak tercampur dengan akun DANA',
    () async {
      // Pemasukan BCA.
      await repository.insertTransaction(
        _transaction(
          day: 5,
          amount: 3000000,
          type: TransactionType.income,
          description: 'Gaji',
          accountName: 'BCA',
        ),
      );

      // Pengeluaran BCA.
      await repository.insertTransaction(
        _transaction(
          day: 6,
          amount: 100000,
          type: TransactionType.expense,
          description: 'Belanja',
          accountName: 'BCA',
        ),
      );

      // Pengeluaran DANA.
      await repository.insertTransaction(
        _transaction(
          day: 7,
          amount: 25000,
          type: TransactionType.expense,
          description: 'Jajan',
          accountType: AccountType.eMoney,
          accountName: 'DANA',
        ),
      );

      await controller.loadTransactions();

      // Total seluruh akun.
      expect(controller.totalIncome, 3000000);
      expect(controller.totalExpense, 125000);

      // Khusus akun BCA.
      final bcaSummary = await controller.getAccountSummary(
        accountType: AccountType.bank,
        accountName: 'BCA',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(bcaSummary.totalIncome, 3000000);
      expect(bcaSummary.totalExpense, 100000);
      expect(bcaSummary.netAmount, 2900000);
      expect(bcaSummary.transactionCount, 2);

      // Khusus akun DANA.
      final danaSummary = await controller.getAccountSummary(
        accountType: AccountType.eMoney,
        accountName: 'DANA',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(danaSummary.totalIncome, 0);
      expect(danaSummary.totalExpense, 25000);
      expect(danaSummary.netAmount, -25000);
      expect(danaSummary.transactionCount, 1);
    },
  );
}