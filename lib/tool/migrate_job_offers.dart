
import 'dart:io';

// =======================================================
// FINPLAN - JOB OFFERS RIVERPOD MIGRATION V2
// =======================================================
//
// Jalankan:
// dart run tool/migrate_job_offers.dart
//
// Memigrasikan:
// 1. main.dart
// 2. finance_shell.dart
// 3. planner_page.dart
// 4. add_job_offer_page.dart
// 5. jobs_offer_page.dart
//
// Perubahan divalidasi sebelum file ditulis.
// Backup dibuat otomatis.
// Data pengguna dan repository tidak diubah.
// =======================================================

class MigrationFile {
  MigrationFile(this.path)
      : original = File(path).readAsStringSync() {
    content = original.replaceAll('\r\n', '\n');
  }

  final String path;
  final String original;

  late String content;

  RegExp _pattern(String expression) {
    return RegExp(
      expression,
      multiLine: true,
      dotAll: true,
    );
  }

  // Pola wajib ditemukan tepat satu kali.
  void replaceOne(
    String expression,
    String Function(Match) replacement,
  ) {
    final pattern = _pattern(expression);
    final matches = pattern.allMatches(content).toList();

    if (matches.length != 1) {
      throw StateError(
        '$path\n'
        'Pola ditemukan ${matches.length} kali '
        '(seharusnya 1).\n'
        'Pola: $expression',
      );
    }

    content = content.replaceFirstMapped(
      pattern,
      replacement,
    );
  }

  // Penggantian sederhana.
  void swap(String expression, String replacement) {
    replaceOne(expression, (_) => replacement);
  }

  // Menghapus pola tertentu.
  void drop(String expression) {
    replaceOne(expression, (_) => '');
  }

  // Mengganti semua kemunculan.
  void replaceAllMatches(
    String expression,
    String Function(Match) replacement,
  ) {
    final pattern = _pattern(expression);
    final matches = pattern.allMatches(content).toList();

    if (matches.isEmpty) {
      throw StateError(
        '$path\nPola tidak ditemukan: $expression',
      );
    }

    content = content.replaceAllMapped(
      pattern,
      replacement,
    );
  }

  // Pastikan referensi lama tidak tersisa.
  void checkAbsent(String expression) {
    if (_pattern(expression).hasMatch(content)) {
      throw StateError(
        '$path masih memiliki referensi lama: '
        '$expression',
      );
    }
  }

  String get output {
    if (original.contains('\r\n')) {
      return content.replaceAll('\n', '\r\n');
    }

    return content;
  }

  void backup() {
    final backupFile = File(
      '$path.before_riverpod.bak',
    );

    if (!backupFile.existsSync()) {
      backupFile.writeAsStringSync(original);
    }
  }

  void write() {
    File(path).writeAsStringSync(output);
  }

  void restore() {
    File(path).writeAsStringSync(original);
  }
}

// =======================================================
// MIGRATION - MAIN
// =======================================================

void migrateMain(MigrationFile source) {
  source.swap(
    r"import 'state/job_offer_controller.dart';",
    "import 'state/job_offer_notifier.dart';",
  );

  // Hapus pembuatan ChangeNotifier lama.
  source.drop(
    r'\s*final jobOfferController\s*=\s*'
    r'JobOfferController\(\s*'
    r'JobOfferRepository\(\s*'
    r'preferences:\s*preferences,\s*'
    r'\),\s*\);',
  );

  // Daftarkan repository lama ke Riverpod.
  source.replaceOne(
    r'legacySavingsControllerProvider'
    r'\.overrideWithValue\(\s*'
    r'savingsController,\s*\),',
    (match) {
      return '''${match.group(0)}

        // Repository Tawaran Kerja (penyimpanan tetap sama).
        jobOfferRepositoryProvider.overrideWithValue(
          JobOfferRepository(preferences: preferences),
        ),''';
    },
  );

  source.drop(
    r'\s*jobOfferController:\s*jobOfferController,',
  );

  source.drop(
    r'\s*required this\.jobOfferController,',
  );

  source.drop(
    r'\s*final JobOfferController jobOfferController;',
  );

  source.drop(
    r'\s*jobOfferController:\s*'
    r'widget\.jobOfferController,',
  );

  source.drop(
    r'\s*widget\.jobOfferController\.dispose\(\);',
  );

  source.checkAbsent(r'jobOfferController');
}

// =======================================================
// MIGRATION - FINANCE SHELL
// =======================================================

void migrateShell(MigrationFile source) {
  source.swap(
    r"import '../../../state/job_offer_controller.dart';",
    "import '../../../state/job_offer_notifier.dart';",
  );

  source.drop(
    r'\s*required this\.jobOfferController,',
  );

  source.drop(
    r'\s*final JobOfferController jobOfferController;',
  );

  source.swap(
    r'widget\.jobOfferController\.initialize\(\)',
    'ref.read(jobOffersProvider.notifier).initialize()',
  );

  // Mendukung penulisan satu baris atau beberapa baris.
  source.drop(
    r'\s*jobOfferController:\s*'
    r'widget\.jobOfferController,',
  );

  source.replaceAllMatches(
    r'\s*controller:\s*widget\.jobOfferController,',
    (_) => '',
  );

  source.checkAbsent(r'jobOfferController');
}

// =======================================================
// MIGRATION - PLANNER
// =======================================================

void migratePlanner(MigrationFile source) {
  source.drop(
    r"import '../../../state/job_offer_controller.dart';\s*",
  );

  source.drop(
    r'\s*this\.jobOfferController,',
  );

  source.drop(
    r'\s*// Kompatibilitas dengan FinanceShell\.\s*'
    r'final JobOfferController\? jobOfferController;',
  );

  source.checkAbsent(r'jobOfferController');
}

// =======================================================
// MIGRATION - ADD JOB OFFER
// =======================================================

void migrateForm(MigrationFile source) {
  source.swap(
    r"import 'package:flutter/material.dart';",
    "import 'package:flutter/material.dart';\n"
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
  );

  source.swap(
    r"import '../state/job_offer_controller.dart';",
    "import '../state/job_offer_notifier.dart';",
  );

  source.swap(
    r'class AddJobOfferPage extends StatefulWidget',
    'class AddJobOfferPage extends ConsumerStatefulWidget',
  );

  source.drop(
    r'\s*required this\.controller,',
  );

  source.drop(
    r'\s*final JobOfferController controller;',
  );

  source.swap(
    r'State<AddJobOfferPage> createState\(\)',
    'ConsumerState<AddJobOfferPage> createState()',
  );

  source.swap(
    r'class _AddJobOfferPageState extends '
    r'State<AddJobOfferPage>',
    'class _AddJobOfferPageState extends '
        'ConsumerState<AddJobOfferPage>',
  );

  // Mutasi data melalui notifier.
  source.replaceAllMatches(
    r'widget\.controller\.(updateOffer|createOffer)',
    (match) {
      return 'ref.read(jobOffersProvider.notifier)'
          '.${match.group(1)}';
    },
  );

  // Membaca state.
  source.replaceAllMatches(
    r'widget\.controller\.(isSaving|errorMessage)',
    (match) {
      return 'ref.read(jobOffersProvider)'
          '.${match.group(1)}';
    },
  );

  // AnimatedBuilder diganti dengan Riverpod watch.
  source.swap(
    r'return AnimatedBuilder\(\s*'
    r'animation:\s*widget\.controller,\s*'
    r'builder:\s*\(context,\s*_\)\s*\{\s*'
    r'final saving\s*=\s*'
    r'_isSubmitting\s*\|\|\s*'
    r'ref\.read\(jobOffersProvider\)\.isSaving;\s*'
    r'return Scaffold\(',
    'final saving = _isSubmitting || '
        'ref.watch(jobOffersProvider).isSaving;\n'
        '    return Scaffold(',
  );

  // Hapus penutup AnimatedBuilder.
  source.swap(
    r'\n\s*\},\s*\);\s*\}\s*\}\s*$',
    '\n  }\n}\n',
  );

  // Bersihkan warning null-aware.
  source.content = source.content.replaceAll(
    "error ?? 'Periksa kembali input pekerjaan.'",
    'error',
  );

  source.checkAbsent(r'widget\.controller');
  source.checkAbsent(r'AnimatedBuilder\(');
}

// =======================================================
// MIGRATION - JOB OFFERS LIST
// =======================================================

void migrateList(MigrationFile source) {
  source.swap(
    r"import 'package:flutter/material.dart';",
    "import 'dart:async';\n\n"
        "import 'package:flutter/material.dart';\n"
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
  );

  source.swap(
    r"import '../state/job_offer_controller.dart';",
    "import '../state/job_offer_notifier.dart';",
  );

  source.swap(
    r'class JobOffersPage extends StatefulWidget',
    'class JobOffersPage extends ConsumerStatefulWidget',
  );

  source.drop(
    r'\s*required this\.controller,',
  );

  source.drop(
    r'\s*final JobOfferController controller;',
  );

  source.swap(
    r'State<JobOffersPage> createState\(\)',
    'ConsumerState<JobOffersPage> createState()',
  );

  source.swap(
    r'class _JobOffersPageState extends '
    r'State<JobOffersPage>',
    'class _JobOffersPageState extends '
        'ConsumerState<JobOffersPage>',
  );

  // Operasi create, archive, restore, delete, refresh.
  source.replaceAllMatches(
    r'widget\.controller\.'
    r'(archiveOffer|restoreOffer|deleteOffer|refresh|loadOffers)',
    (match) {
      return 'ref.read(jobOffersProvider.notifier)'
          '.${match.group(1)}';
    },
  );

  // Semua getter state menggunakan Riverpod.
  source.replaceAllMatches(
    r'widget\.controller\b',
    (_) => 'ref.read(jobOffersProvider)',
  );

  // Future pada initState sengaja tidak ditunggu.
  source.swap(
    r'ref\.read\(jobOffersProvider\.notifier\)'
    r'\.loadOffers\(\);',
    'unawaited(\n'
        '  ref.read(jobOffersProvider.notifier).loadOffers(),\n'
        ');',
  );

  // AnimatedBuilder menjadi ConsumerStatefulWidget.
  source.swap(
    r'return AnimatedBuilder\(\s*'
    r'animation:\s*ref\.read\(jobOffersProvider\),\s*'
    r'builder:\s*\(context,\s*_\)\s*\{',
    'final offerState = ref.watch(jobOffersProvider);',
  );

  source.swap(
    r'if \(ref\.read\(jobOffersProvider\)\.isLoading\s*'
    r'&&\s*!ref\.read\(jobOffersProvider\)\.hasLoaded\)',
    'if (offerState.isLoading && !offerState.hasLoaded)',
  );

  // Hapus penutup AnimatedBuilder.
  source.swap(
    r'\n\s*\},\s*\);\s*\}\s*\}\s*$',
    '\n  }\n}\n',
  );

  source.checkAbsent(r'widget\.controller');
  source.checkAbsent(r'AnimatedBuilder\(');
}

// =======================================================
// PROGRAM UTAMA
// =======================================================

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln(
      'Jalankan dari folder utama project FinPlan.',
    );
    exitCode = 1;
    return;
  }

  final notifier = File(
    'lib/state/job_offer_notifier.dart',
  );

  if (!notifier.existsSync()) {
    stderr.writeln(
      'File job_offer_notifier.dart belum tersedia.',
    );
    exitCode = 1;
    return;
  }

  final notifierCode = notifier.readAsStringSync();

  if (!notifierCode.contains('jobOffersProvider') ||
      !notifierCode.contains('jobOfferRepositoryProvider')) {
    stderr.writeln(
      'Provider Tawaran Kerja belum lengkap.',
    );
    exitCode = 1;
    return;
  }

  final files = <MigrationFile>[];

  try {
    final mainFile = MigrationFile('lib/main.dart');

    final shellFile = MigrationFile(
      'lib/features/dashboard/presentation/finance_shell.dart',
    );

    final plannerFile = MigrationFile(
      'lib/features/planner/presentation/planner_page.dart',
    );

    final formFile = MigrationFile(
      'lib/screens/add_job_offer_page.dart',
    );

    final listFile = MigrationFile(
      'lib/screens/jobs_offer_page.dart',
    );

    files.addAll([
      mainFile,
      shellFile,
      plannerFile,
      formFile,
      listFile,
    ]);

    // Semua perubahan dilakukan di memori dahulu.
    migrateMain(mainFile);
    migrateShell(shellFile);
    migratePlanner(plannerFile);
    migrateForm(formFile);
    migrateList(listFile);

    // Backup seluruh file sebelum melakukan penulisan.
    for (final source in files) {
      source.backup();
    }

    // Simpan lima file.
    try {
      for (final source in files) {
        source.write();
        stdout.writeln('UPDATED: ${source.path}');
      }
    } catch (_) {
      // Jika penulisan gagal, pulihkan file asli.
      for (final source in files) {
        source.restore();
      }
      rethrow;
    }

    stdout.writeln('');
    stdout.writeln(
      'SUCCESS: Migrasi Tawaran Kerja selesai.',
    );
    stdout.writeln(
      'Selanjutnya jalankan dart format, '
      'flutter analyze, dan flutter test.',
    );
  } catch (error) {
    stderr.writeln('');
    stderr.writeln('MIGRASI DIBATALKAN: $error');
    stderr.writeln(
      'Periksa pola yang gagal sebelum '
      'menjalankan ulang.',
    );

    exitCode = 1;
  }
}