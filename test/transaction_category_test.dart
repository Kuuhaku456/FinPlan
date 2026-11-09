import 'package:flutter_test/flutter_test.dart';

import '../lib/models/finance_transaction.dart';
import '../lib/models/transaction_category.dart';
import '../lib/data/transaction_repository.dart';

void main() {
  // ========================================
  // TRANSACTION CATEGORY TESTS
  // ========================================

  group('TransactionCategory', () {
    test(
      'Kategori memiliki nama dan emoji yang benar',
      () {
        expect(
          TransactionCategory.food.label,
          'Makanan & Minuman',
        );

        expect(
          TransactionCategory.food.emoji,
          '🍔',
        );

        expect(
          TransactionCategory.transport.label,
          'Transportasi',
        );

        expect(
          TransactionCategory.transport.emoji,
          '🚆',
        );
      },
    );

    test(
      'Kategori dikonversi ke nilai database',
      () {
        expect(
          TransactionCategory.food.databaseValue,
          'food',
        );

        expect(
          TransactionCategory.transport.databaseValue,
          'transport',
        );

        expect(
          TransactionCategory.bills.databaseValue,
          'bills',
        );
      },
    );

    test(
      'Nilai kategori dari database dibaca dengan benar',
      () {
        final category =
            TransactionCategoryExtension.fromDatabase(
          'transport',
        );

        expect(
          category,
          TransactionCategory.transport,
        );
      },
    );

    test(
      'Kategori tidak dikenal menjadi other',
      () {
        final category =
            TransactionCategoryExtension.fromDatabase(
          'unknown_category',
        );

        expect(
          category,
          TransactionCategory.other,
        );
      },
    );

    test(
      'Kategori null menjadi other',
      () {
        final category =
            TransactionCategoryExtension.fromDatabase(
          null,
        );

        expect(
          category,
          TransactionCategory.other,
        );
      },
    );
  });

  // ========================================
  // FINANCE TRANSACTION TESTS
  // ========================================

  group('FinanceTransaction', () {
    test(
      'Transaksi baru menggunakan kategori other secara default',
      () {
        final transaction = FinanceTransaction(
          date: DateTime(2026, 11, 7),
          amount: 25000,
          type: TransactionType.expense,
          accountType: AccountType.bank,
          accountName: 'BCA',
          description: 'Makan siang',
        );

        expect(
          transaction.category,
          TransactionCategory.other,
        );
      },
    );

    test(
      'Transaksi dapat memiliki kategori transportasi',
      () {
        final transaction = FinanceTransaction(
          date: DateTime(2026, 11, 7),
          amount: 10000,
          type: TransactionType.expense,
          category: TransactionCategory.transport,
          accountType: AccountType.bank,
          accountName: 'BCA',
          description: 'Naik KRL',
        );

        expect(
          transaction.category,
          TransactionCategory.transport,
        );

        expect(
          transaction.categoryLabel,
          'Transportasi',
        );

        expect(
          transaction.categoryEmoji,
          '🚆',
        );
      },
    );

    test(
      'Pengeluaran menghasilkan nominal negatif',
      () {
        final transaction = FinanceTransaction(
          date: DateTime(2026, 11, 7),
          amount: 50000,
          type: TransactionType.expense,
          category: TransactionCategory.food,
          accountType: AccountType.cash,
          accountName: 'Tunai',
          description: 'Makan',
        );

        expect(
          transaction.signedAmount,
          -50000,
        );

        expect(
          transaction.isExpense,
          true,
        );

        expect(
          transaction.isIncome,
          false,
        );
      },
    );

    test(
      'Pemasukan menghasilkan nominal positif',
      () {
        final transaction = FinanceTransaction(
          date: DateTime(2026, 11, 7),
          amount: 3000000,
          type: TransactionType.income,
          accountType: AccountType.bank,
          accountName: 'BCA',
          description: 'Gaji',
        );

        expect(
          transaction.signedAmount,
          3000000,
        );

        expect(
          transaction.isIncome,
          true,
        );

        expect(
          transaction.isExpense,
          false,
        );
      },
    );

    test(
      'Tanggal transaksi diformat untuk SQLite',
      () {
        final transaction = FinanceTransaction(
          date: DateTime(2026, 1, 5),
          amount: 10000,
          type: TransactionType.expense,
          accountType: AccountType.cash,
          accountName: 'Tunai',
          description: 'Belanja',
        );

        expect(
          transaction.dateString,
          '2026-01-05',
        );
      },
    );

    test(
      'toMap default tetap kompatibel dengan database lama',
      () {
        final transaction = FinanceTransaction(
          date: DateTime(2026, 11, 7),
          amount: 15000,
          type: TransactionType.expense,
          category: TransactionCategory.transport,
          accountType: AccountType.bank,
          accountName: 'BCA',
          description: 'Naik KRL',
        );

        final map = transaction.toMap();

        expect(
          map.containsKey('category'),
          false,
        );

        expect(
          map['amount'],
          15000,
        );
      },
    );

    test(
      'toMap menyertakan kategori untuk SQLite versi 2',
      () {
        final transaction = FinanceTransaction(
          date: DateTime(2026, 11, 7),
          amount: 15000,
          type: TransactionType.expense,
          category: TransactionCategory.transport,
          accountType: AccountType.bank,
          accountName: 'BCA',
          description: 'Naik KRL',
        );

        final map = transaction.toMap(
          includeCategory: true,
        );

        expect(
          map['category'],
          'transport',
        );

        expect(
          map['amount'],
          15000,
        );

        expect(
          map['type'],
          'expense',
        );

        expect(
          map['account_name'],
          'BCA',
        );
      },
    );

    test(
      'fromMap membaca kategori yang tersimpan',
      () {
        final map = <String, Object?>{
          'id': 1,
          'transaction_date': '2026-11-07',
          'amount': 25000,
          'type': 'expense',
          'category': 'food',
          'account_type': 'bank',
          'account_name': 'BCA',
          'description': 'Makan siang',
          'created_at': 1794000000000,
        };

        final transaction =
            FinanceTransaction.fromMap(map);

        expect(
          transaction.id,
          1,
        );

        expect(
          transaction.amount,
          25000,
        );

        expect(
          transaction.category,
          TransactionCategory.food,
        );

        expect(
          transaction.accountName,
          'BCA',
        );
      },
    );

    test(
      'fromMap mendukung transaksi lama tanpa kategori',
      () {
        final oldTransaction = <String, Object?>{
          'id': 2,
          'transaction_date': '2026-10-15',
          'amount': 10000,
          'type': 'expense',
          'account_type': 'cash',
          'account_name': 'Tunai',
          'description': 'Belanja',
          'created_at': 1792000000000,
        };

        final transaction =
            FinanceTransaction.fromMap(
          oldTransaction,
        );

        expect(
          transaction.id,
          2,
        );

        expect(
          transaction.amount,
          10000,
        );

        expect(
          transaction.category,
          TransactionCategory.other,
        );
      },
    );

    test(
      'copyWith dapat mengubah kategori dan nominal',
      () {
        final createdAt = DateTime(2026, 11, 7);

        final original = FinanceTransaction(
          id: 10,
          date: DateTime(2026, 11, 7),
          amount: 25000,
          type: TransactionType.expense,
          category: TransactionCategory.food,
          accountType: AccountType.bank,
          accountName: 'BCA',
          description: 'Makan siang',
          createdAt: createdAt,
        );

        final updated = original.copyWith(
          amount: 30000,
          category: TransactionCategory.transport,
          description: 'Naik transportasi',
        );

        expect(
          updated.id,
          10,
        );

        expect(
          updated.amount,
          30000,
        );

        expect(
          updated.category,
          TransactionCategory.transport,
        );

        expect(
          updated.description,
          'Naik transportasi',
        );

        expect(
          updated.createdAt,
          createdAt,
        );

        // Data awal tidak boleh berubah.
        expect(
          original.amount,
          25000,
        );

        expect(
          original.category,
          TransactionCategory.food,
        );
      },
    );
  });

  // ========================================
  // EXPENSE CATEGORY SUMMARY TESTS
  // ========================================

  group('ExpenseCategorySummary', () {
    test(
      'Rekap kategori menampilkan nilai yang benar',
      () {
        const summary = ExpenseCategorySummary(
          category: TransactionCategory.transport,
          totalAmount: 150000,
          transactionCount: 12,
        );

        expect(
          summary.categoryName,
          'Transportasi',
        );

        expect(
          summary.categoryEmoji,
          '🚆',
        );

        expect(
          summary.totalAmount,
          150000,
        );

        expect(
          summary.transactionCount,
          12,
        );
      },
    );

    test(
      'Persentase kategori dapat dihitung dengan tepat',
      () {
        const food = ExpenseCategorySummary(
          category: TransactionCategory.food,
          totalAmount: 150000,
          transactionCount: 5,
        );

        const transport = ExpenseCategorySummary(
          category: TransactionCategory.transport,
          totalAmount: 50000,
          transactionCount: 3,
        );

        const summaries = [
          food,
          transport,
        ];

        final total = summaries.fold<int>(
          0,
          (sum, item) => sum + item.totalAmount,
        );

        final foodPercentage =
            food.totalAmount / total * 100;

        final transportPercentage =
            transport.totalAmount / total * 100;

        expect(
          total,
          200000,
        );

        expect(
          foodPercentage,
          75.0,
        );

        expect(
          transportPercentage,
          25.0,
        );
      },
    );
  });
}