
import 'dart:io';

// =====================================================
// FINPLAN - SAVINGS UI RIVERPOD MIGRATION V1
// =====================================================
//
// Tujuan:
// Menghapus ketergantungan SavingsController
// dari halaman UI yang sudah menggunakan Riverpod.
//
// File yang dimigrasikan:
// 1. savings_page.dart
// 2. savings_detail_page.dart
// 3. add_savings_goal_page.dart
// 4. finance_shell.dart
// 5. main.dart
//
// Yang tidak diubah:
// - SavingsRepository
// - SavingsGoal
// - SavingsMovement
// - SharedPreferences
// - Data saldo dan riwayat tabungan
// - SavingsController legacy di main.dart
//
// Semua pola divalidasi sebelum menulis file.
// Backup otomatis dibuat.
//
// Menjalankan:
// dart run lib/tool/migrate_savings_ui_v1.dart
// =====================================================

// =====================================================
// SOURCE FILE MANAGER
// =====================================================

class _Source {
  _Source(this.path)
      : original = File(path).readAsStringSync() {
    content = original.replaceAll('\r\n', '\n');
  }

  final String path;
  final String original;

  late String content;

  // ===================================================
  // REPLACE EXACTLY ONCE
  // ===================================================

  void replaceOnce(
    String pattern,
    String replacement,
  ) {
    final regex = RegExp(
      pattern,
      multiLine: true,
    );

    final found = regex.allMatches(content).length;

    if (found != 1) {
      throw StateError(
        '$path: pola ditemukan $found kali '
        '(harus tepat 1).\n'
        'Pola: $pattern',
      );
    }

    content = content.replaceFirst(
      regex,
      replacement,
    );
  }

  // ===================================================
  // REQUIRE TEXT
  // ===================================================

  void require(String value) {
    if (!content.contains(value)) {
      throw StateError(
        '$path: tidak ditemukan "$value".',
      );
    }
  }

  // ===================================================
  // FORBID LEGACY REFERENCE
  // ===================================================

  void forbidPattern(String pattern) {
    if (RegExp(
      pattern,
      multiLine: true,
    ).hasMatch(content)) {
      throw StateError(
        '$path: referensi lama masih ada: $pattern',
      );
    }
  }

  // ===================================================
  // CREATE BACKUP
  // ===================================================

  void backupTo(Directory directory) {
    final filename = path.replaceAll('/', '__');

    final backup = File(
      '${directory.path}/$filename',
    );

    if (!backup.existsSync()) {
      backup.writeAsStringSync(original);
    }
  }

  // ===================================================
  // SAVE FILE
  // ===================================================

  void save() {
    final output = original.contains('\r\n')
        ? content.replaceAll('\n', '\r\n')
        : content;

    File(path).writeAsStringSync(output);
  }

  // ===================================================
  // RESTORE FILE
  // ===================================================

  void restore() {
    File(path).writeAsStringSync(original);
  }
}

// =====================================================
// MIGRATE SAVINGS PAGE
// =====================================================

void _removeControllerFromSavingsPage(
  _Source file,
) {
  file.require(
    'class SavingsPage extends ConsumerStatefulWidget',
  );

  file.require('savingsStateProvider');

  // Hapus parameter controller.
  file.replaceOnce(
    r'\brequired\s+this\.controller\s*,?',
    '',
  );

  // Hapus field controller.
  file.replaceOnce(
    r'^[ \t]*final\s+SavingsController\s+'
    r'controller\s*;[ \t]*\n',
    '',
  );

  // Hapus import legacy controller.
  file.replaceOnce(
    r"^[ \t]*import '../state/"
    r"savings_controller\.dart';[ \t]*\n",
    '',
  );

  // Hapus komentar kompatibilitas lama.
  file.content = file.content.replaceAll(
    '  // Kompatibilitas dengan FinanceShell/main.dart.\n'
    '  // Pembacaan dan perubahan data menggunakan Riverpod.\n',
    '',
  );

  // Pastikan tidak ada penggunaan controller lama.
  file.forbidPattern(
    r'\bwidget\.controller\b|\bSavingsController\b',
  );

  // Pastikan callback halaman masih tersedia.
  file.require('onCreateGoal');
  file.require('onOpenGoal');
}

// =====================================================
// MIGRATE SAVINGS DETAIL PAGE
// =====================================================

void _removeControllerFromSavingsDetail(
  _Source file,
) {
  file.require(
    'class SavingsDetailPage extends ConsumerStatefulWidget',
  );

  file.require('savingsStateProvider');

  // Hapus parameter controller.
  file.replaceOnce(
    r'\brequired\s+this\.controller\s*,?',
    '',
  );

  // Hapus field controller.
  file.replaceOnce(
    r'^[ \t]*final\s+SavingsController\s+'
    r'controller\s*;[ \t]*\n',
    '',
  );

  // Hapus import controller.
  file.replaceOnce(
    r"^[ \t]*import '../state/"
    r"savings_controller\.dart';[ \t]*\n",
    '',
  );

  // Perbaiki pemeriksaan perubahan widget.
  //
  // Sebelumnya:
  // oldWidget.goalId != widget.goalId ||
  // oldWidget.controller != widget.controller
  //
  // Sesudah:
  // oldWidget.goalId != widget.goalId

  file.replaceOnce(
    r'oldWidget\.goalId\s*!=\s*widget\.goalId'
    r'\s*\|\|\s*'
    r'oldWidget\.controller\s*!=\s*widget\.controller',
    'oldWidget.goalId != widget.goalId',
  );

  // Perbaiki komentar.
  file.content = file.content.replaceAll(
    'Pesan error disimpan oleh SavingsController',
    'Pesan error disimpan oleh provider tabungan',
  );

  file.content = file.content.replaceAll(
    '  // Kompatibilitas dengan main.dart / FinanceShell.\n',
    '',
  );

  // Validasi.
  file.forbidPattern(
    r'\bwidget\.controller\b|\bSavingsController\b',
  );

  file.require('onEditGoal');
  file.require('goalId');
}

// =====================================================
// MIGRATE ADD SAVINGS GOAL PAGE
// =====================================================

void _removeControllerFromSavingsForm(
  _Source file,
) {
  file.require(
    'class AddSavingsGoalPage extends ConsumerStatefulWidget',
  );

  file.require('savingsStateProvider');

  // Hapus parameter controller.
  file.replaceOnce(
    r'\brequired\s+this\.controller\s*,?',
    '',
  );

  // Hapus field controller.
  file.replaceOnce(
    r'^[ \t]*final\s+SavingsController\s+'
    r'controller\s*;[ \t]*\n',
    '',
  );

  // Hapus import controller.
  file.replaceOnce(
    r"^[ \t]*import '../state/"
    r"savings_controller\.dart';[ \t]*\n",
    '',
  );

  // Hapus komentar lama jika tersedia.
  file.content = file.content.replaceAll(
    '  // Kompatibilitas dengan main.dart / FinanceShell.\n',
    '',
  );

  // Validasi.
  file.forbidPattern(
    r'\bwidget\.controller\b|\bSavingsController\b',
  );

  file.require('goalId');
}

// =====================================================
// MIGRATE FINANCE SHELL
// =====================================================

void _removeControllerFromShell(
  _Source file,
) {
  file.require(
    'class FinanceShell extends ConsumerStatefulWidget',
  );

  file.require('savingsStateProvider');

  // Hapus parameter constructor.
  file.replaceOnce(
    r'\brequired\s+this\.savingsController\s*,?',
    '',
  );

  // Hapus field SavingsController.
  file.replaceOnce(
    r'^[ \t]*final\s+SavingsController\s+'
    r'savingsController\s*;[ \t]*\n',
    '',
  );

  // Hapus import legacy.
  file.replaceOnce(
    r"^[ \t]*import '../../../state/"
    r"savings_controller\.dart';[ \t]*\n",
    '',
  );

  // ===================================================
  // REMOVE CONTROLLER FROM PAGE CALLS
  // ===================================================

  // Mendukung:
  //
  // SavingsPage(
  //   controller: widget.savingsController,
  //   ...
  // )
  //
  // Maupun:
  //
  // SavingsPage(controller: widget.savingsController, ...)
  //
  // Callback lain tetap dipertahankan.

  for (final name in [
    'AddSavingsGoalPage',
    'SavingsDetailPage',
    'SavingsPage',
  ]) {
    file.replaceOnce(
      '\\b$name\\s*\\(\\s*'
      'controller\\s*:\\s*'
      'widget\\.savingsController\\s*,?',
      '$name(',
    );
  }

  // Validasi.
  file.forbidPattern(
    r'\bwidget\.savingsController\b|\bSavingsController\b',
  );

  file.require('SavingsPage(');
  file.require('SavingsDetailPage(');
  file.require('AddSavingsGoalPage(');
}

// =====================================================
// MIGRATE MAIN.DART
// =====================================================

void _removeShellArgumentFromMain(
  _Source file,
) {
  file.require('FinanceShell(');

  file.require(
    'legacySavingsControllerProvider',
  );

  file.require(
    'widget.savingsController.dispose()',
  );

  // Hanya menghapus argumen savingsController
  // dari pemanggilan FinanceShell.
  //
  // Instance SavingsController di main.dart
  // dan override provider legacy tetap disimpan.

  file.replaceOnce(
    r'\bsavingsController\s*:\s*'
    r'widget\.savingsController\s*,?',
    '',
  );

  // Pastikan legacy fallback tetap tersedia.
  file.require(
    'legacySavingsControllerProvider',
  );

  file.require(
    'widget.savingsController.dispose()',
  );

  file.require('SavingsController(');
}

// =====================================================
// MAIN MIGRATION
// =====================================================

void main() {
  // ===================================================
  // CHECK PROJECT ROOT
  // ===================================================

  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln(
      'ERROR: Jalankan dari folder utama project FinPlan.',
    );

    exitCode = 1;
    return;
  }

  // ===================================================
  // TARGET FILES
  // ===================================================

  final paths = <String>[
    'lib/screens/savings_page.dart',
    'lib/screens/savings_detail_page.dart',
    'lib/screens/add_savings_goal_page.dart',
    'lib/features/dashboard/presentation/finance_shell.dart',
    'lib/main.dart',
  ];

  final sources = <_Source>[];

  try {
    // =================================================
    // 1. READ ALL FILES
    // =================================================

    for (final path in paths) {
      if (!File(path).existsSync()) {
        throw StateError(
          'File tidak ditemukan: $path',
        );
      }

      sources.add(_Source(path));
    }

    // =================================================
    // 2. VALIDATE AND MODIFY IN MEMORY
    // =================================================

    _removeControllerFromSavingsPage(
      sources[0],
    );

    _removeControllerFromSavingsDetail(
      sources[1],
    );

    _removeControllerFromSavingsForm(
      sources[2],
    );

    _removeControllerFromShell(
      sources[3],
    );

    _removeShellArgumentFromMain(
      sources[4],
    );

    stdout.writeln(
      'VALIDATION PASSED: 5 file cocok.',
    );

    // =================================================
    // 3. CREATE BACKUPS
    // =================================================

    // Jika Git tersedia, simpan backup di dalam
    // .git agar tidak ikut masuk Git commit.

    final backupRoot =
        Directory('.git').existsSync()
            ? Directory(
                '.git/finplan_backups/savings_ui_v1',
              )
            : Directory(
                '.finplan_backups/savings_ui_v1',
              );

    backupRoot.createSync(recursive: true);

    for (final file in sources) {
      file.backupTo(backupRoot);
    }

    if (!Directory('.git').existsSync()) {
      stdout.writeln(
        'PERHATIAN: Backup berada di '
        '.finplan_backups/. '
        'Jangan unggah folder backup ke Git.',
      );
    }

    // =================================================
    // 4. SAVE MODIFIED FILES
    // =================================================

    try {
      for (final file in sources) {
        file.save();

        stdout.writeln(
          'UPDATED: ${file.path}',
        );
      }
    } catch (error) {
      // Kembalikan seluruh file ke kondisi awal
      // jika proses penulisan gagal.

      for (final file in sources) {
        file.restore();
      }

      rethrow;
    }

    // =================================================
    // 5. SUCCESS MESSAGE
    // =================================================

    stdout.writeln();
    stdout.writeln(
      '=========================================',
    );

    stdout.writeln(
      'SAVINGS UI RIVERPOD MIGRATION BERHASIL',
    );

    stdout.writeln(
      '=========================================',
    );

    stdout.writeln(
      'SUCCESS: Savings UI -> Riverpod wiring selesai.',
    );

    stdout.writeln(
      'Backup: ${backupRoot.path}',
    );

    stdout.writeln(
      'SavingsController lama tetap tersedia '
      'di main.dart sebagai fallback.',
    );

    stdout.writeln(
      'Data tabungan tidak dimodifikasi.',
    );
  } catch (error) {
    // Bila validasi gagal, file source
    // belum diubah.

    stderr.writeln();

    stderr.writeln(
      'MIGRASI DIBATALKAN: $error',
    );

    stderr.writeln(
      'Periksa hasil ini sebelum mencoba kembali.',
    );

    exitCode = 1;
  }
}