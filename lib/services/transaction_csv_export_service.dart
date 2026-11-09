import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/transaction_repository.dart';
import '../models/finance_transaction.dart';
import '../models/transaction_category.dart';

// ==========================================
// FINPLAN - CSV EXPORT SERVICE
// ==========================================
//
// Fitur:
// - Ekspor seluruh transaksi
// - Ekspor berdasarkan tanggal
// - Ekspor berdasarkan jenis transaksi
// - Ekspor berdasarkan kategori
// - Mendukung pagination database
// - Format CSV kompatibel dengan Excel
// - Encoding UTF-8
// - Melindungi kolom teks dari CSV injection
//
// Tidak mengubah atau menghapus data SQLite.
//
// ==========================================

// ==========================================
// 1. CSV EXPORT RESULT
// ==========================================

class CsvExportResult {
  const CsvExportResult({
    required this.file,
    required this.fileName,
    required this.transactionCount,
    required this.totalIncome,
    required this.totalExpense,
  });

  final File file;

  final String fileName;

  final int transactionCount;

  final int totalIncome;

  final int totalExpense;

  int get netAmount {
    return totalIncome - totalExpense;
  }

  String get filePath {
    return file.path;
  }
}

// ==========================================
// 2. CSV EXPORT SERVICE
// ==========================================

class TransactionCsvExportService {
  const TransactionCsvExportService(
    this._repository,
  );

  final TransactionRepository _repository;

  static const int _pageSize = 500;

  // ========================================
  // 3. EXPORT TRANSACTIONS
  // ========================================

  Future<CsvExportResult> exportTransactions({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    TransactionCategory? category,
  }) async {
    final transactions = <FinanceTransaction>[];

    var offset = 0;

    // ======================================
    // LOAD ALL TRANSACTIONS
    // ======================================

    while (true) {
      final page = await _repository.getTransactions(
        startDate: startDate,
        endDate: endDate,
        type: type,
        category: category,
        limit: _pageSize,
        offset: offset,
      );

      transactions.addAll(page);

      offset += page.length;

      // Hentikan ketika seluruh data
      // sudah berhasil diambil.
      if (page.length < _pageSize) {
        break;
      }
    }

    // ======================================
    // VALIDATE DATA
    // ======================================

    if (transactions.isEmpty) {
      throw StateError(
        'Belum ada transaksi untuk diekspor.',
      );
    }

    // ======================================
    // CALCULATE SUMMARY
    // ======================================

    var totalIncome = 0;
    var totalExpense = 0;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        totalIncome += transaction.amount;
      } else {
        totalExpense += transaction.amount;
      }
    }

    // ======================================
    // GENERATE CSV
    // ======================================

    final csvContent = buildCsv(
      transactions,
    );

    // ======================================
    // GENERATE FILE NAME
    // ======================================

    final timestamp =
        DateTime.now().microsecondsSinceEpoch;

    final fileName =
        'FinPlan_Transaksi_$timestamp.csv';

    // ======================================
    // GET TEMPORARY DIRECTORY
    // ======================================

    final directory =
        await getTemporaryDirectory();

    final file = File(
      '${directory.path}'
      '${Platform.pathSeparator}'
      '$fileName',
    );

    // ======================================
    // WRITE CSV FILE
    // ======================================

    await file.writeAsString(
      csvContent,
      encoding: utf8,
      flush: true,
    );

    return CsvExportResult(
      file: file,
      fileName: fileName,
      transactionCount: transactions.length,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
    );
  }

  // ========================================
  // 4. BUILD CSV CONTENT
  // ========================================

  /// Mengubah daftar transaksi menjadi CSV.
  ///
  /// Fungsi ini dapat diuji secara terpisah
  /// tanpa membuka database SQLite.
  static String buildCsv(
    Iterable<FinanceTransaction> transactions,
  ) {
    final buffer = StringBuffer();

    // UTF-8 BOM membantu Excel membaca
    // karakter Indonesia dan emoji.
    buffer.write('\uFEFF');

    // ======================================
    // CSV HEADER
    // ======================================

    buffer.write(
      'ID,'
      'Tanggal,'
      'Jenis Transaksi,'
      'Kategori,'
      'Nominal (Rp),'
      'Perubahan Saldo (Rp),'
      'Jenis Akun,'
      'Nama Akun,'
      'Deskripsi,'
      'Waktu Pencatatan\r\n',
    );

    // ======================================
    // CSV ROWS
    // ======================================

    for (final transaction in transactions) {
      final categoryLabel =
          transaction.type == TransactionType.income
              ? '-'
              : transaction.category.label;

      final cells = <String>[
        transaction.id?.toString() ?? '',

        _csvCell(
          transaction.dateString,
        ),

        _csvCell(
          transaction.type.label,
        ),

        _csvCell(
          categoryLabel,
        ),

        transaction.amount.toString(),

        transaction.signedAmount.toString(),

        _csvCell(
          transaction.accountType.label,
        ),

        _csvCell(
          transaction.accountName,
        ),

        _csvCell(
          transaction.description,
        ),

        _csvCell(
          _formatDateTime(
            transaction.createdAt,
          ),
        ),
      ];

      buffer.write(
        '${cells.join(',')}\r\n',
      );
    }

    return buffer.toString();
  }

  // ========================================
  // 5. ESCAPE CSV CELL
  // ========================================

  /// Mengamankan karakter khusus CSV.
  ///
  /// Menghindari teks deskripsi atau akun
  /// yang terbaca sebagai rumus Excel.
  static String _csvCell(String value) {
    var safeValue = value.replaceAll(
      '\u0000',
      '',
    );

    // Formula spreadsheet dapat dimulai
    // dengan =, +, -, atau @.
    final formulaPattern = RegExp(
      r'^\s*[=+\-@]',
    );

    if (formulaPattern.hasMatch(safeValue)) {
      safeValue = "'$safeValue";
    }

    // Escape karakter tanda kutip.
    safeValue = safeValue.replaceAll(
      '"',
      '""',
    );

    // Semua kolom teks dibungkus
    // tanda kutip ganda.
    return '"$safeValue"';
  }

  // ========================================
  // 6. FORMAT DATE TIME
  // ========================================

  static String _formatDateTime(
    DateTime date,
  ) {
    final year = date.year.toString().padLeft(4, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    final hour =
        date.hour.toString().padLeft(2, '0');

    final minute =
        date.minute.toString().padLeft(2, '0');

    final second =
        date.second.toString().padLeft(2, '0');

    return '$year-$month-$day '
        '$hour:$minute:$second';
  }
}