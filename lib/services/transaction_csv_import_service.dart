import 'dart:convert';

import '../data/transaction_repository.dart';
import '../models/finance_transaction.dart';
import '../models/transaction_category.dart';

// ==========================================
// FINPLAN - CSV IMPORT SERVICE
// ==========================================

// Format header harus sama dengan
// transaction_csv_export_service.dart.
const List<String> _csvHeaders = [
  'ID',
  'Tanggal',
  'Jenis Transaksi',
  'Kategori',
  'Nominal (Rp)',
  'Perubahan Saldo (Rp)',
  'Jenis Akun',
  'Nama Akun',
  'Deskripsi',
  'Waktu Pencatatan',
];

// ==========================================
// MODEL PREVIEW IMPORT
// ==========================================

class CsvImportPreview {
  const CsvImportPreview({
    required this.totalRows,
    required this.importableRows,
    required this.duplicateRows,
  });

  final int totalRows;
  final int importableRows;
  final int duplicateRows;

  bool get hasData => totalRows > 0;

  bool get canImport => importableRows > 0;
}

// ==========================================
// MODEL HASIL IMPORT
// ==========================================

class CsvImportResult {
  const CsvImportResult({
    required this.totalRows,
    required this.importedRows,
    required this.duplicateRows,
  });

  final int totalRows;
  final int importedRows;
  final int duplicateRows;

  bool get isSuccess => importedRows > 0;
}

// ==========================================
// IMPORT SERVICE
// ==========================================

class TransactionCsvImportService {
  TransactionCsvImportService(
    this._repository,
  );

  final TransactionRepository _repository;

  static const int maxRows = 100000;

  // Batas ukuran teks sekitar 30 juta karakter.
  static const int maxCharacters = 30000000;

  // ========================================
  // 1. FORMAT TANGGAL
  // ========================================

  DateTime _parseDate(
    String value,
    int rowNumber,
  ) {
    final input = value.trim();

    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(input);

    if (match == null) {
      throw FormatException(
        'Baris $rowNumber: format tanggal tidak valid.',
      );
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    final date = DateTime(
      year,
      month,
      day,
    );

    if (date.year != year ||
        date.month != month ||
        date.day != day) {
      throw FormatException(
        'Baris $rowNumber: tanggal tidak ditemukan.',
      );
    }

    return date;
  }

  // ========================================
  // 2. FORMAT WAKTU PENCATATAN
  // ========================================

  DateTime _parseCreatedAt(
    String value,
    int rowNumber,
  ) {
    final input = value.trim();

    final normalized = input.replaceFirst(
      ' ',
      'T',
    );

    final result = DateTime.tryParse(
      normalized,
    );

    if (result == null) {
      throw FormatException(
        'Baris $rowNumber: waktu pencatatan tidak valid.',
      );
    }

    return result;
  }

  // ========================================
  // 3. FORMAT JENIS TRANSAKSI
  // ========================================

  TransactionType _parseTransactionType(
    String value,
    int rowNumber,
  ) {
    final input = value.trim().toLowerCase();

    switch (input) {
      case 'pemasukan':
      case 'income':
        return TransactionType.income;

      case 'pengeluaran':
      case 'expense':
        return TransactionType.expense;

      default:
        throw FormatException(
          'Baris $rowNumber: jenis transaksi '
          '"$value" tidak dikenali.',
        );
    }
  }

  // ========================================
  // 4. FORMAT JENIS AKUN
  // ========================================

  AccountType _parseAccountType(
    String value,
    int rowNumber,
  ) {
    final input = value
        .trim()
        .toLowerCase()
        .replaceAll(
          RegExp(r'[\s_-]'),
          '',
        );

    switch (input) {
      case 'bank':
        return AccountType.bank;

      case 'emoney':
        return AccountType.eMoney;

      case 'tunai':
      case 'cash':
        return AccountType.cash;

      case 'lainnya':
      case 'other':
        return AccountType.other;

      default:
        throw FormatException(
          'Baris $rowNumber: jenis akun '
          '"$value" tidak dikenali.',
        );
    }
  }

  // ========================================
  // 5. FORMAT KATEGORI
  // ========================================

  TransactionCategory _parseCategory(
    String value,
    TransactionType type,
    int rowNumber,
  ) {
    if (type == TransactionType.income) {
      return TransactionCategory.other;
    }

    final input = value.trim().toLowerCase();

    if (input.isEmpty || input == '-') {
      return TransactionCategory.other;
    }

    for (final category
        in TransactionCategory.values) {
      final matchesName =
          category.name.toLowerCase() == input;

      final matchesLabel =
          category.label.toLowerCase() == input;

      if (matchesName || matchesLabel) {
        return category;
      }
    }

    throw FormatException(
      'Baris $rowNumber: kategori '
      '"$value" tidak dikenali.',
    );
  }

  // ========================================
  // 6. MEMULIHKAN TEKS EXCEL
  // ========================================

  String _restoreExcelText(String value) {
    // Export FinPlan menambahkan apostrof
    // untuk mengamankan teks yang terlihat
    // seperti formula Excel.
    //
    // Hilangkan apostrof tersebut ketika
    // membaca kembali file backup.

    if (value.length < 2 ||
        !value.startsWith("'")) {
      return value;
    }

    const dangerousPrefixes = [
      '=',
      '+',
      '-',
      '@',
      '\t',
      '\r',
    ];

    if (dangerousPrefixes.contains(value[1])) {
      return value.substring(1);
    }

    return value;
  }

  // ========================================
  // 7. MEMBACA CSV
  // ========================================

  List<List<String>> _parseCsv(String content) {
    var text = content;

    // Menghapus UTF-8 BOM bila tersedia.
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }

    if (text.length > maxCharacters) {
      throw const FormatException(
        'File CSV terlalu besar.',
      );
    }

    final rows = <List<String>>[];
    final currentRow = <String>[];

    var field = StringBuffer();
    var insideQuotes = false;

    void finishField() {
      currentRow.add(field.toString());
      field = StringBuffer();
    }

    void finishRow() {
      finishField();

      // Abaikan baris yang sepenuhnya kosong.
      if (currentRow.any(
        (item) => item.isNotEmpty,
      )) {
        rows.add(
          List<String>.from(currentRow),
        );
      }

      currentRow.clear();

      if (rows.length > maxRows + 1) {
        throw const FormatException(
          'Jumlah baris CSV melebihi batas.',
        );
      }
    }

    for (var i = 0; i < text.length; i++) {
      final character = text[i];

      if (insideQuotes) {
        if (character == '"') {
          if (i + 1 < text.length &&
              text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            insideQuotes = false;
          }
        } else {
          field.write(character);
        }

        continue;
      }

      switch (character) {
        case '"':
          if (field.isNotEmpty) {
            throw const FormatException(
              'Format tanda kutip CSV tidak valid.',
            );
          }

          insideQuotes = true;
          break;

        case ',':
          finishField();
          break;

        case '\n':
          finishRow();
          break;

        case '\r':
          if (i + 1 < text.length &&
              text[i + 1] == '\n') {
            i++;
          }

          finishRow();
          break;

        default:
          field.write(character);
      }
    }

    if (insideQuotes) {
      throw const FormatException(
        'Tanda kutip CSV belum ditutup.',
      );
    }

    if (field.isNotEmpty ||
        currentRow.isNotEmpty) {
      finishRow();
    }

    return rows;
  }

  // ========================================
  // 8. VALIDASI HEADER
  // ========================================

  void _validateHeaders(
    List<String> actual,
  ) {
    if (actual.length != _csvHeaders.length) {
      throw const FormatException(
        'Jumlah kolom tidak sesuai '
        'dengan format backup FinPlan.',
      );
    }

    for (var i = 0; i < _csvHeaders.length; i++) {
      if (actual[i].trim() != _csvHeaders[i]) {
        throw FormatException(
          'Kolom "${_csvHeaders[i]}" '
          'tidak ditemukan pada posisi yang sesuai.',
        );
      }
    }
  }

  // ========================================
  // 9. KONVERSI BARIS KE TRANSAKSI
  // ========================================

  FinanceTransaction _transactionFromRow(
    List<String> row,
    int rowNumber,
  ) {
    if (row.length != _csvHeaders.length) {
      throw FormatException(
        'Baris $rowNumber: jumlah kolom tidak sesuai.',
      );
    }

    final date = _parseDate(
      row[1],
      rowNumber,
    );

    final type = _parseTransactionType(
      row[2],
      rowNumber,
    );

    final category = _parseCategory(
      row[3],
      type,
      rowNumber,
    );

    final amount = int.tryParse(
      row[4].trim(),
    );

    if (amount == null || amount <= 0) {
      throw FormatException(
        'Baris $rowNumber: nominal harus '
        'berupa angka positif.',
      );
    }

    // Periksa kesesuaian kolom saldo.
    final signedAmount = int.tryParse(
      row[5].trim(),
    );

    final expectedSignedAmount =
        type == TransactionType.income
            ? amount
            : -amount;

    if (signedAmount != expectedSignedAmount) {
      throw FormatException(
        'Baris $rowNumber: perubahan saldo '
        'tidak sesuai dengan jenis transaksi.',
      );
    }

    final accountType = _parseAccountType(
      row[6],
      rowNumber,
    );

    final accountName = _restoreExcelText(
      row[7],
    ).trim();

    final description = _restoreExcelText(
      row[8],
    ).trim();

    if (accountName.isEmpty) {
      throw FormatException(
        'Baris $rowNumber: nama akun kosong.',
      );
    }

    if (description.isEmpty) {
      throw FormatException(
        'Baris $rowNumber: deskripsi kosong.',
      );
    }

    final createdAt = _parseCreatedAt(
      row[9],
      rowNumber,
    );

    return FinanceTransaction(
      // ID CSV sengaja tidak digunakan.
      // SQLite akan membuat ID baru.
      date: date,
      amount: amount,
      type: type,
      category: category,
      accountType: accountType,
      accountName: accountName,
      description: description,
      createdAt: createdAt,
    );
  }

  // ========================================
  // 10. VALIDASI SELURUH FILE
  // ========================================

  List<FinanceTransaction> _readTransactions(
    String csvText,
  ) {
    final rows = _parseCsv(csvText);

    if (rows.isEmpty) {
      throw const FormatException(
        'File CSV kosong.',
      );
    }

    _validateHeaders(rows.first);

    final transactions = <FinanceTransaction>[];

    for (var i = 1; i < rows.length; i++) {
      final rowNumber = i + 1;

      transactions.add(
        _transactionFromRow(
          rows[i],
          rowNumber,
        ),
      );
    }

    return transactions;
  }

  // ========================================
  // 11. KUNCI PENDETEKSI DUPLIKAT
  // ========================================

  String _transactionKey(
    FinanceTransaction transaction,
  ) {
    final createdAt = transaction.createdAt.toLocal();

    // Export CSV hanya menyimpan waktu
    // hingga detik. Karena itu milidetik
    // tidak digunakan untuk perbandingan.
    final timestamp = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
      createdAt.hour,
      createdAt.minute,
      createdAt.second,
    ).toIso8601String();

    return jsonEncode([
      transaction.dateString,
      transaction.amount,
      transaction.type.name,
      transaction.category.name,
      transaction.accountType.name,
      transaction.accountName,
      transaction.description,
      timestamp,
    ]);
  }

  // ========================================
  // 12. HITUNG DATA IDENTIK
  // ========================================

  Map<String, int> _buildExistingCounts(
    Iterable<FinanceTransaction> existing,
  ) {
    final counts = <String, int>{};

    for (final transaction in existing) {
      final key = _transactionKey(
        transaction,
      );

      counts[key] = (counts[key] ?? 0) + 1;
    }

    return counts;
  }

  // ========================================
  // 13. PREVIEW IMPORT
  // ========================================

  Future<CsvImportPreview> previewCsv(
    String csvText,
  ) async {
    final incoming = _readTransactions(
      csvText,
    );

    final database = await _repository.database;

    final existingRows = await database.query(
      'transactions',
    );

    final existing = existingRows
        .map(
          (row) => FinanceTransaction.fromMap(
            row,
          ),
        )
        .toList();

    final existingCounts = _buildExistingCounts(
      existing,
    );

    final seenInCsv = <String, int>{};

    var duplicateRows = 0;
    var importableRows = 0;

    for (final transaction in incoming) {
      final key = _transactionKey(
        transaction,
      );

      final occurrence =
          (seenInCsv[key] ?? 0) + 1;

      seenInCsv[key] = occurrence;

      final existingCount =
          existingCounts[key] ?? 0;

      if (occurrence <= existingCount) {
        duplicateRows++;
      } else {
        importableRows++;
      }
    }

    return CsvImportPreview(
      totalRows: incoming.length,
      importableRows: importableRows,
      duplicateRows: duplicateRows,
    );
  }

  // ========================================
  // 14. SIMPAN HASIL IMPORT
  // ========================================

  Future<CsvImportResult> importCsv(
    String csvText,
  ) async {
    // Semua baris divalidasi sebelum
    // satu pun transaksi ditambahkan.
    final incoming = _readTransactions(
      csvText,
    );

    final database = await _repository.database;

    // Transaksi database:
    // jika ada error, semua INSERT dibatalkan.
    return database.transaction<CsvImportResult>(
      (txn) async {
        final existingRows = await txn.query(
          'transactions',
        );

        final existing = existingRows
            .map(
              (row) => FinanceTransaction.fromMap(
                row,
              ),
            )
            .toList();

        final existingCounts =
            _buildExistingCounts(existing);

        final seenInCsv = <String, int>{};

        var importedRows = 0;
        var duplicateRows = 0;

        for (final transaction in incoming) {
          final key = _transactionKey(
            transaction,
          );

          final occurrence =
              (seenInCsv[key] ?? 0) + 1;

          seenInCsv[key] = occurrence;

          final existingCount =
              existingCounts[key] ?? 0;

          if (occurrence <= existingCount) {
            duplicateRows++;
            continue;
          }

          await txn.insert(
            'transactions',
            transaction.toMap(
              includeCategory: true,
            ),
          );

          importedRows++;
        }

        return CsvImportResult(
          totalRows: incoming.length,
          importedRows: importedRows,
          duplicateRows: duplicateRows,
        );
      },
    );
  }
}