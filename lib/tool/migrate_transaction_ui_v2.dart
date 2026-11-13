
import 'dart:io';

// =====================================================
// FINPLAN - TRANSACTION UI MIGRATION V2
// =====================================================
//
// Menghapus ketergantungan TransactionController
// dari halaman Transaksi dan form tambah/edit.
//
// File yang diperbarui:
// 1. lib/screens/transactions_page.dart
// 2. lib/screens/add_transaction_page.dart
// 3. lib/features/dashboard/presentation/finance_shell.dart
// 4. lib/main.dart
//
// Tidak mengubah:
// - TransactionRepository
// - Database SQLite
// - Skema tabel transaksi
// - TransactionNotifier
// - TransactionController legacy
// - Desain halaman
//
// Semua perubahan diperiksa sebelum disimpan.
// Backup otomatis dibuat untuk setiap file.
//
// Jalankan:
// dart run tool/migrate_transaction_ui_v2.dart
// =====================================================

class SourceFile {
  SourceFile(this.path)
      : original = File(path).readAsStringSync() {
    content = original.replaceAll('\r\n', '\n');
  }

  final String path;
  final String original;
  late String content;

  void removeOne(String pattern) {
    final expression = RegExp(
      pattern,
      multiLine: true,
    );

    final matches = expression.allMatches(content).toList();

    if (matches.length != 1) {
      throw StateError(
        '$path: pola ditemukan ${matches.length} kali '
        '(seharusnya tepat 1).\n'
        'Pola: $pattern',
      );
    }

    content = content.replaceFirst(expression, '');
  }

  void ensureAbsent(String expression) {
    final pattern = RegExp(expression);

    if (pattern.hasMatch(content)) {
      throw StateError(
        '$path: referensi lama masih ditemukan.\n'
        'Pola: $expression',
      );
    }
  }

  void ensurePresent(String expression) {
    final pattern = RegExp(expression);

    if (!pattern.hasMatch(content)) {
      throw StateError(
        '$path: komponen yang diperlukan tidak ada.\n'
        'Pola: $expression',
      );
    }
  }

  String get output {
    if (original.contains('\r\n')) {
      return content.replaceAll('\n', '\r\n');
    }

    return content;
  }

  void createBackup() {
    final backup = File(
      '$path.before_transaction_ui_v2.bak',
    );

    if (!backup.existsSync()) {
      backup.writeAsStringSync(original);
    }
  }

  void write() {
    File(path).writeAsStringSync(output);
  }

  void restore() {
    File(path).writeAsStringSync(original);
  }
}

// =====================================================
// TRANSACTIONS PAGE
// =====================================================

void migrateTransactionsPage(SourceFile source) {
  // Hapus import controller lama.
  source.removeOne(
    r"^import '../state/transaction_controller\.dart';[ \t]*\n",
  );

  // Hapus required controller pada constructor.
  source.removeOne(
    r'^[ \t]*required this\.controller,[ \t]*\n',
  );

  // Hapus field controller.
  source.removeOne(
    r'^[ \t]*final TransactionController controller;[ \t]*\n',
  );

  // Form tambah/edit sudah menggunakan
  // transactionStateProvider.
  //
  // Karena itu controller tidak perlu diteruskan.
  source.removeOne(
    r'^[ \t]*controller:[ \t]*widget\.controller,[ \t]*\n',
  );

  // Validasi.
  source.ensurePresent(
    r'ConsumerStatefulWidget',
  );

  source.ensurePresent(
    r'transactionStateProvider',
  );

  source.ensurePresent(
    r'AddTransactionPage\(',
  );

  source.ensureAbsent(
    r'\bTransactionController\b',
  );

  source.ensureAbsent(
    r'widget\.controller',
  );
}

// =====================================================
// ADD / EDIT TRANSACTION PAGE
// =====================================================

void migrateAddTransactionPage(SourceFile source) {
  // Hapus import controller lama.
  source.removeOne(
    r"^import '../state/transaction_controller\.dart';[ \t]*\n",
  );

  // Hapus parameter controller pada constructor.
  source.removeOne(
    r'^[ \t]*required this\.controller,[ \t]*\n',
  );

  // Hapus field controller lama.
  source.removeOne(
    r'^[ \t]*final TransactionController controller;[ \t]*\n',
  );

  // Validasi form Riverpod.
  source.ensurePresent(
    r'ConsumerStatefulWidget',
  );

  source.ensurePresent(
    r'transactionStateProvider',
  );

  source.ensurePresent(
    r'addTransaction\(',
  );

  source.ensurePresent(
    r'updateTransaction\(',
  );

  source.ensureAbsent(
    r'\bTransactionController\b',
  );

  source.ensureAbsent(
    r'widget\.controller',
  );
}

// =====================================================
// FINANCE SHELL
// =====================================================

void migrateFinanceShell(SourceFile source) {
  // Hapus import TransactionController.
  source.removeOne(
    r"^import '../../../state/transaction_controller\.dart';[ \t]*\n",
  );

  // Hapus constructor parameter.
  source.removeOne(
    r'^[ \t]*required this\.transactionController,[ \t]*\n',
  );

  // Hapus field lama.
  source.removeOne(
    r'^[ \t]*final TransactionController transactionController;[ \t]*\n',
  );

  // Halaman Transaksi sekarang tidak membutuhkan
  // parameter controller.
  source.removeOne(
    r'^[ \t]*controller:[ \t]*widget\.transactionController,[ \t]*\n',
  );

  // Validasi.
  source.ensurePresent(
    r'TransactionsPage\(',
  );

  source.ensurePresent(
    r'transactionStateProvider',
  );

  source.ensureAbsent(
    r'widget\.transactionController',
  );

  source.ensureAbsent(
    r'\bTransactionController\b',
  );
}

// =====================================================
// MAIN.DART
// =====================================================

void migrateMain(SourceFile source) {
  // Hanya menghapus parameter TransactionController
  // pada pemanggilan FinanceShell.
  //
  // Instance TransactionController di main.dart
  // sengaja tetap dipertahankan untuk fallback V1
  // selama seluruh modul belum dimigrasikan.

  source.removeOne(
    r'^[ \t]*transactionController:[ \t]*'
    r'widget\.transactionController,[ \t]*\n',
  );

  // Pastikan mode legacy tetap tersedia.
  source.ensurePresent(
    r'legacyTransactionControllerProvider',
  );

  source.ensurePresent(
    r'FinanceShell\(',
  );
}

// =====================================================
// PROGRAM UTAMA
// =====================================================

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln(
      'ERROR: Jalankan script dari folder utama FinPlan.',
    );

    exitCode = 1;
    return;
  }

  final paths = <String>[
    'lib/screens/transactions_page.dart',
    'lib/screens/add_transaction_page.dart',
    'lib/features/dashboard/presentation/finance_shell.dart',
    'lib/main.dart',
  ];

  final files = <SourceFile>[];

  try {
    // ================================================
    // 1. CHECK FILES
    // ================================================

    for (final path in paths) {
      if (!File(path).existsSync()) {
        throw StateError(
          'File tidak ditemukan: $path',
        );
      }

      files.add(SourceFile(path));
    }

    // ================================================
    // 2. VALIDATE AND MODIFY IN MEMORY
    // ================================================

    migrateTransactionsPage(files[0]);
    migrateAddTransactionPage(files[1]);
    migrateFinanceShell(files[2]);
    migrateMain(files[3]);

    stdout.writeln(
      'Semua pola migrasi berhasil divalidasi.',
    );

    // ================================================
    // 3. CREATE BACKUPS
    // ================================================

    for (final source in files) {
      source.createBackup();
    }

    // ================================================
    // 4. WRITE FILES
    // ================================================

    try {
      for (final source in files) {
        source.write();

        stdout.writeln(
          'UPDATED: ${source.path}',
        );
      }
    } catch (_) {
      // Jika penulisan gagal, pulihkan seluruh
      // file ke kondisi sebelum migrasi.
      for (final source in files) {
        source.restore();
      }

      rethrow;
    }

    // ================================================
    // 5. RESULT
    // ================================================

    stdout.writeln();
    stdout.writeln(
      'SUCCESS: Transaction UI migration selesai.',
    );

    stdout.writeln(
      'Halaman Transaksi dan form tambah/edit '
      'sekarang tidak lagi menerima '
      'TransactionController.',
    );

    stdout.writeln(
      'Controller legacy tetap tersedia '
      'sebagai fallback.',
    );
  } catch (error) {
    stderr.writeln();
    stderr.writeln(
      'MIGRASI DIBATALKAN: $error',
    );

    stderr.writeln(
      'File aplikasi tidak diubah apabila '
      'validasi gagal.',
    );

    exitCode = 1;
  }
}
