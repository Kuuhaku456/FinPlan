
import 'dart:io';

// =====================================================
// FINPLAN - SETTINGS UI RIVERPOD MIGRATION
// =====================================================
//
// File yang diperbarui:
// 1. lib/features/settings/presentation/settings_page.dart
// 2. lib/features/dashboard/presentation/finance_shell.dart
// 3. lib/main.dart
//
// Mempertahankan:
// - Tampilan Settings
// - Light, Dark, dan System Theme
// - Pengaturan ukuran font
// - Reset Finance Plan
// - Import dan Export Transaksi
// - Legacy PlanController di main.dart
// - Seluruh data lokal
//
// Semua pola divalidasi sebelum penulisan.
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
  // REQUIRE
  // ===================================================

  void require(String value) {
    if (!content.contains(value)) {
      throw StateError(
        '$path: tidak ditemukan "$value".',
      );
    }
  }

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

    final count = regex.allMatches(content).length;

    if (count != 1) {
      throw StateError(
        '$path\n'
        'Pola ditemukan $count kali, '
        'seharusnya 1 kali.\n'
        'Pola: $pattern',
      );
    }

    content = content.replaceFirst(
      regex,
      replacement,
    );
  }

  // ===================================================
  // VALIDATE REMOVAL
  // ===================================================

  void forbid(String pattern) {
    if (RegExp(pattern).hasMatch(content)) {
      throw StateError(
        '$path: referensi lama masih ditemukan.\n'
        'Pola: $pattern',
      );
    }
  }

  // ===================================================
  // BACKUP
  // ===================================================

  void backup(Directory directory) {
    final name = path.replaceAll(
      RegExp(r'[/\\]'),
      '__',
    );

    File(
      '${directory.path}${Platform.pathSeparator}$name',
    ).writeAsStringSync(original);
  }

  // ===================================================
  // SAVE
  // ===================================================

  void save() {
    final output = original.contains('\r\n')
        ? content.replaceAll('\n', '\r\n')
        : content;

    File(path).writeAsStringSync(output);
  }

  // ===================================================
  // RESTORE
  // ===================================================

  void restore() {
    File(path).writeAsStringSync(original);
  }
}

// =====================================================
// 1. MIGRATE SETTINGS PAGE
// =====================================================

void _migrateSettingsPage(_Source file) {
  file.require('class SettingsPage extends ConsumerWidget');
  file.require('appSettingsProvider');
  file.require('settingsUiProvider');

  // Hapus parameter constructor yang tidak digunakan.

  file.replaceOnce(
    r'required\s+this\.controller\s*,?',
    '',
  );

  file.replaceOnce(
    r'required\s+this\.textScale\s*,?',
    '',
  );

  file.replaceOnce(
    r'required\s+this\.onTextScaleChanged\s*,?',
    '',
  );

  // Hapus field lama.

  file.replaceOnce(
    r'^[ \t]*final\s+PlanController\s+'
    r'controller\s*;[ \t]*\n',
    '',
  );

  file.replaceOnce(
    r'^[ \t]*final\s+double\s+'
    r'textScale\s*;[ \t]*\n',
    '',
  );

  file.replaceOnce(
    r'^[ \t]*final\s+ValueChanged\s*<\s*double\s*>\s+'
    r'onTextScaleChanged\s*;[ \t]*\n',
    '',
  );

  // Hapus import PlanController.

  file.replaceOnce(
    r"^import '../../../state/"
    r"plan_controller\.dart';[ \t]*\n",
    '',
  );

  // Hapus komentar kompatibilitas lama.

  file.content = file.content.replaceAll(
    '  // Dipertahankan agar kompatibel dengan\n'
    '  // pemanggilan SettingsPage pada FinanceShell.\n',
    '',
  );

  // Pastikan seluruh fungsi tetap tersedia.

  file.require('_themeSettings');
  file.require('_fontSettings');
  file.require('_confirmResetPlan');
  file.require('TransactionExportCard');
  file.require('TransactionImportCard');

  file.forbid(r'\bPlanController\b');
  file.forbid(r'\bonTextScaleChanged\b');
  file.forbid(r'\btextScale\b');
}

// =====================================================
// 2. MIGRATE FINANCE SHELL
// =====================================================

void _migrateFinanceShell(_Source file) {
  file.require(
    'class FinanceShell extends ConsumerStatefulWidget',
  );

  file.require('SettingsPage(');
  file.require('appSettingsProvider');

  // Hapus parameter PlanController pada FinanceShell.

  file.replaceOnce(
    r'required\s+this\.planController\s*,?',
    '',
  );

  // Hapus field PlanController.

  file.replaceOnce(
    r'^[ \t]*final\s+PlanController\s+'
    r'planController\s*;[ \t]*\n',
    '',
  );

  // Hapus import PlanController.

  file.replaceOnce(
    r"^import '../../../state/"
    r"plan_controller\.dart';[ \t]*\n",
    '',
  );

  // Hapus variabel textScale yang sudah dibaca
  // langsung dari appSettingsProvider oleh SettingsPage.

  file.replaceOnce(
    r'final\s+textScale\s*=\s*ref\s*\.\s*read\s*'
    r'\(\s*appSettingsProvider\s*,?\s*\)\s*'
    r'\.\s*fontScale\s*;\s*',
    '',
  );

  // Hapus callback font lama.
  // SettingsPage telah menggunakan Riverpod.

  file.replaceOnce(
    r'final\s+onTextScaleChanged\s*=\s*ref\s*'
    r'\.\s*read\s*'
    r'\(\s*appSettingsProvider\.notifier\s*,?\s*\)'
    r'\s*\.\s*setFontScale\s*;\s*',
    '',
  );

  // Sebelumnya:
  //
  // SettingsPage(
  //   controller: widget.planController,
  //   textScale: textScale,
  //   onTextScaleChanged: onTextScaleChanged,
  // )
  //
  // Sekarang:
  //
  // const SettingsPage()

  file.replaceOnce(
    r'SettingsPage\s*\(\s*'
    r'controller\s*:\s*widget\.planController\s*,\s*'
    r'textScale\s*:\s*textScale\s*,\s*'
    r'onTextScaleChanged\s*:\s*onTextScaleChanged\s*,?'
    r'\s*\)',
    'const SettingsPage()',
  );

  // Validasi.

  file.forbid(r'\bwidget\.planController\b');
  file.forbid(r'\bPlanController\b');
  file.forbid(r'\bonTextScaleChanged\b');

  file.require('const SettingsPage()');
  file.require('financePlanProvider');
}

// =====================================================
// 3. MIGRATE MAIN.DART
// =====================================================

void _migrateMain(_Source file) {
  file.require('FinanceShell(');
  file.require('legacyPlanControllerProvider');

  // Hapus hanya argumen yang dikirim ke FinanceShell.
  //
  // PlanController di dalam FinPlanApp tetap ada
  // untuk inisialisasi, fallback, dan dispose.

  file.replaceOnce(
    r'planController\s*:\s*'
    r'widget\.planController\s*,?',
    '',
  );

  // Fallback harus tetap tersedia.

  file.require('legacyPlanControllerProvider');
  file.require('settingsPlanControllerProvider');
  file.require('widget.planController.dispose()');
  file.require('PlanController(');
}

// =====================================================
// MAIN
// =====================================================

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln(
      'ERROR: Jalankan dari folder utama FinPlan.',
    );
    exitCode = 1;
    return;
  }

  final paths = <String>[
    'lib/features/settings/presentation/settings_page.dart',
    'lib/features/dashboard/presentation/finance_shell.dart',
    'lib/main.dart',
  ];

  final sources = <_Source>[];

  try {
    // ================================================
    // LOAD FILES
    // ================================================

    for (final path in paths) {
      if (!File(path).existsSync()) {
        throw StateError('File tidak ditemukan: $path');
      }

      sources.add(_Source(path));
    }

    // ================================================
    // CHECK IF ALREADY MIGRATED
    // ================================================

    final alreadyMigrated =
        !sources[0].content.contains(
          'required this.controller',
        ) &&
        !sources[1].content.contains(
          'required this.planController',
        ) &&
        !sources[2].content.contains(
          'planController: widget.planController',
        );

    if (alreadyMigrated) {
      stdout.writeln(
        'Settings UI sudah tampak bermigrasi.',
      );
      stdout.writeln(
        'Tidak ada perubahan yang dilakukan.',
      );
      return;
    }

    // ================================================
    // MIGRATE IN MEMORY
    // ================================================

    _migrateSettingsPage(sources[0]);
    _migrateFinanceShell(sources[1]);
    _migrateMain(sources[2]);

    stdout.writeln(
      'VALIDATION PASSED: 3 file cocok.',
    );

    // ================================================
    // BACKUP
    // ================================================

    final backupRoot = Directory('.git').existsSync()
        ? Directory(
            '.git/finplan_backups/settings_ui_v1',
          )
        : Directory.systemTemp.createTempSync(
            'finplan_settings_ui_v1_',
          );

    backupRoot.createSync(recursive: true);

    for (final file in sources) {
      file.backup(backupRoot);
    }

    // ================================================
    // WRITE FILES
    // ================================================

    try {
      for (final file in sources) {
        file.save();
        stdout.writeln('UPDATED: ${file.path}');
      }
    } catch (error) {
      for (final file in sources) {
        file.restore();
      }

      rethrow;
    }

    // ================================================
    // SUCCESS
    // ================================================

    stdout.writeln();
    stdout.writeln(
      '======================================',
    );
    stdout.writeln(
      'SETTINGS UI MIGRATION BERHASIL',
    );
    stdout.writeln(
      '======================================',
    );
    stdout.writeln(
      'SettingsPage sekarang memakai Riverpod '
      'tanpa parameter controller.',
    );
    stdout.writeln(
      'PlanController legacy tetap tersedia.',
    );
    stdout.writeln(
      'Backup: ${backupRoot.path}',
    );
    stdout.writeln(
      'Data lokal tidak diubah oleh script.',
    );
  } catch (error) {
    stderr.writeln();
    stderr.writeln('MIGRASI DIBATALKAN: $error');
    stderr.writeln(
      'Jika validasi gagal, file aplikasi '
      'tidak diubah.',
    );

    exitCode = 1;
  }
}