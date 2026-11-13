
import 'dart:io';

// =====================================================
// FINPLAN - TRANSACTION UI MIGRATION V3
// =====================================================
//
// Memindahkan ketergantungan UI Transaksi ke Riverpod.
//
// Mendukung constructor satu baris atau multiline.
//
// Tidak menghapus TransactionController dari main.dart
// karena masih dibutuhkan untuk legacy provider dan
// proses penutupan database.
//
// File yang diubah:
// - transactions_page.dart
// - add_transaction_page.dart
// - finance_shell.dart
// - main.dart
//
// Seluruh pola divalidasi SEBELUM menulis file.
// Backup otomatis disediakan.
// =====================================================

class MigrationFile {
  MigrationFile(this.path)
      : original = File(path).readAsStringSync() {
    updated = original.replaceAll('\r\n', '\n');
  }

  final String path;
  final String original;

  late String updated;

  // ===================================================
  // REPLACE EXACTLY ONCE
  // ===================================================

  void replaceOne(
    String pattern,
    String replacement,
  ) {
    final regex = RegExp(
      pattern,
      multiLine: true,
    );

    final count = regex.allMatches(updated).length;

    if (count != 1) {
      throw StateError(
        '$path\n'
        'Pola ditemukan $count kali, '
        'seharusnya 1 kali.\n'
        'Pola: $pattern',
      );
    }

    updated = updated.replaceFirst(
      regex,
      replacement,
    );
  }

  // ===================================================
  // VALIDATION
  // ===================================================

  void requireText(String value) {
    if (!updated.contains(value)) {
      throw StateError(
        '$path tidak mengandung "$value".',
      );
    }
  }

  void forbidText(String value) {
    if (updated.contains(value)) {
      throw StateError(
        '$path masih mengandung "$value".',
      );
    }
  }

  // ===================================================
  // BACKUP
  // ===================================================

  void backup() {
    final backupFile = File(
      '$path.before_transaction_ui_v3.bak',
    );

    if (!backupFile.existsSync()) {
      backupFile.writeAsStringSync(original);
    }
  }

  // ===================================================
  // WRITE
  // ===================================================

  void save() {
    final contents = original.contains('\r\n')
        ? updated.replaceAll('\n', '\r\n')
        : updated;

    File(path).writeAsStringSync(contents);
  }

  void restore() {
    File(path).writeAsStringSync(original);
  }
}

// =====================================================
// TRANSACTIONS PAGE
// =====================================================

void migrateTransactionsPage(MigrationFile file) {
  file.requireText('ConsumerStatefulWidget');
  file.requireText('transactionStateProvider');

  // Mendukung constructor:
  //
  // const TransactionsPage({
  //   super.key,
  //   required this.controller,
  // });
  //
  // maupun:
  //
  // const TransactionsPage({
  //   super.key, required this.controller
  // });
  //
  // termasuk constructor satu baris.

  file.replaceOne(
    r'const\s+TransactionsPage\s*'
    r'\(\s*\{\s*super\.key\s*,\s*'
    r'required\s+this\.controller\s*,?\s*'
    r'\}\s*\)\s*;',
    'const TransactionsPage({super.key});',
  );

  // Hapus field controller.
  file.replaceOne(
    r'^[ \t]*final[ \t]+TransactionController'
    r'[ \t]+controller[ \t]*;[ \t]*\n',
    '',
  );

  // Hapus parameter controller yang diberikan
  // kepada AddTransactionPage.
  file.replaceOne(
    r'^[ \t]*controller[ \t]*:[ \t]*'
    r'widget\.controller[ \t]*,[ \t]*\n',
    '',
  );

  // Hapus import controller.
  file.replaceOne(
    r"^import '../state/"
    r"transaction_controller\.dart';[ \t]*\n",
    '',
  );

  // Pastikan state UI tetap Riverpod.
  file.requireText('transactionStateProvider');
  file.requireText('AddTransactionPage(');

  file.forbidText('widget.controller');
  file.forbidText('TransactionController');
}

// =====================================================
// ADD TRANSACTION PAGE
// =====================================================

void migrateAddTransactionPage(
  MigrationFile file,
) {
  file.requireText('ConsumerStatefulWidget');
  file.requireText('transactionStateProvider');

  // Hapus required controller.
  file.replaceOne(
    r'^[ \t]*required[ \t]+'
    r'this\.controller[ \t]*,[ \t]*\n',
    '',
  );

  // Hapus field controller.
  file.replaceOne(
    r'^[ \t]*final[ \t]+TransactionController'
    r'[ \t]+controller[ \t]*;[ \t]*\n',
    '',
  );

  // Hapus import controller.
  file.replaceOne(
    r"^import '../state/"
    r"transaction_controller\.dart';[ \t]*\n",
    '',
  );

  // Hapus komentar kompatibilitas yang sudah
  // tidak berlaku, jika ditemukan.
  file.updated = file.updated.replaceAll(
    '  // Dipertahankan untuk kompatibilitas\n'
    '  // dengan halaman Transaksi sebelumnya.\n',
    '',
  );

  // Validasi fitur form.
  file.requireText('transactionStateProvider');
  file.requireText('addTransaction(');
  file.requireText('updateTransaction(');

  file.forbidText('widget.controller');
  file.forbidText('TransactionController');
}

// =====================================================
// FINANCE SHELL
// =====================================================

void migrateFinanceShell(
  MigrationFile file,
) {
  file.requireText('TransactionsPage(');
  file.requireText('transactionStateProvider');

  // Hapus constructor parameter.
  file.replaceOne(
    r'^[ \t]*required[ \t]+'
    r'this\.transactionController[ \t]*,[ \t]*\n',
    '',
  );

  // Hapus field TransactionController.
  file.replaceOne(
    r'^[ \t]*final[ \t]+TransactionController'
    r'[ \t]+transactionController[ \t]*;[ \t]*\n',
    '',
  );

  // Hapus parameter saat membuka
  // halaman TransactionsPage.
  file.replaceOne(
    r'^[ \t]*controller[ \t]*:[ \t]*'
    r'widget\.transactionController[ \t]*,[ \t]*\n',
    '',
  );

  // Hapus import yang tidak digunakan.
  file.replaceOne(
    r"^import '../../../state/"
    r"transaction_controller\.dart';[ \t]*\n",
    '',
  );

  file.forbidText('widget.transactionController');
  file.forbidText('TransactionController');
}

// =====================================================
// MAIN.DART
// =====================================================

void migrateMain(MigrationFile file) {
  // Controller di main.dart JANGAN dihapus.
  //
  // Digunakan untuk:
  // - legacyTransactionControllerProvider
  // - closeDatabase()
  // - dispose()
  //
  // Hanya parameter yang dikirim ke
  // FinanceShell yang dihilangkan.

  file.requireText('FinanceShell(');
  file.requireText(
    'legacyTransactionControllerProvider',
  );
  file.requireText('closeDatabase()');

  file.replaceOne(
    r'^[ \t]*transactionController[ \t]*:[ \t]*'
    r'widget\.transactionController[ \t]*,[ \t]*\n',
    '',
  );

  // Validasi fallback tetap tersedia.
  file.requireText('TransactionController');
  file.requireText('closeDatabase()');
  file.requireText(
    'legacyTransactionControllerProvider',
  );
}

// =====================================================
// MAIN
// =====================================================

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln(
      'Jalankan script dari root project FinPlan.',
    );
    exitCode = 1;
    return;
  }

  final paths = [
    'lib/screens/transactions_page.dart',
    'lib/screens/add_transaction_page.dart',
    'lib/features/dashboard/presentation/finance_shell.dart',
    'lib/main.dart',
  ];

  final files = <MigrationFile>[];

  try {
    // ================================================
    // STEP 1: LOAD
    // ================================================

    for (final path in paths) {
      if (!File(path).existsSync()) {
        throw StateError(
          'File tidak ditemukan: $path',
        );
      }

      files.add(MigrationFile(path));
    }

    // ================================================
    // STEP 2: MIGRATE IN MEMORY
    // ================================================

    migrateTransactionsPage(files[0]);

    migrateAddTransactionPage(files[1]);

    migrateFinanceShell(files[2]);

    migrateMain(files[3]);

    stdout.writeln(
      'VALIDATION PASSED: Seluruh pola cocok.',
    );

    // ================================================
    // STEP 3: BACKUP
    // ================================================

    for (final file in files) {
      file.backup();
    }

    // ================================================
    // STEP 4: SAVE
    // ================================================

    try {
      for (final file in files) {
        file.save();

        stdout.writeln(
          'UPDATED: ${file.path}',
        );
      }
    } catch (error) {
      for (final file in files) {
        file.restore();
      }

      rethrow;
    }

    stdout.writeln();
    stdout.writeln('================================');
    stdout.writeln('MIGRASI TRANSAKSI BERHASIL');
    stdout.writeln('================================');
    stdout.writeln(
      'UI Transaksi sekarang menggunakan Riverpod.',
    );
    stdout.writeln(
      'Legacy TransactionController '
      'tetap tersedia di main.dart.',
    );
    stdout.writeln(
      'Database SQLite tidak diubah.',
    );
  } catch (error) {
    stderr.writeln();
    stderr.writeln(
      'MIGRASI DIBATALKAN: $error',
    );

    stderr.writeln(
      'Periksa pesan di atas sebelum mencoba lagi.',
    );

    exitCode = 1;
  }
}