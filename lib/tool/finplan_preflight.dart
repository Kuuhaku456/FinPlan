
import 'dart:io';

// =====================================================
// FINPLAN - PRE-RELEASE AUDIT
// =====================================================
//
// Tujuan:
// 1. Memeriksa seluruh provider Riverpod V2.
// 2. Mendeteksi controller lama yang masih digunakan.
// 3. Memeriksa kesiapan konfigurasi Android.
// 4. Memeriksa keberadaan unit test.
// 5. Memeriksa pengamanan file signing.
// 6. Membuat laporan audit otomatis.
//
// Jalankan dari root project:
//
// dart run tool/finplan_preflight.dart
//
// Script tidak mengubah source code atau database.
// =====================================================

class AuditFinding {
  const AuditFinding(
    this.status,
    this.title,
    this.description,
  );

  final String status;
  final String title;
  final String description;

  String toReport() {
    return '[$status] $title\n$description\n';
  }
}

class FinPlanAuditor {
  final List<AuditFinding> findings = [];
  final List<String> legacyReferences = [];

  String readFile(String path) {
    final file = File(path);

    if (!file.existsSync()) {
      return '';
    }

    return file.readAsStringSync();
  }

  void add(
    String status,
    String title,
    String description,
  ) {
    findings.add(
      AuditFinding(status, title, description),
    );
  }

  // ===================================================
  // PROJECT STRUCTURE
  // ===================================================

  void checkProjectStructure() {
    final required = <String>[
      'pubspec.yaml',
      'lib/main.dart',
      'lib/models/finance_plan.dart',
      'lib/models/finance_transaction.dart',
      'lib/models/savings_goal.dart',
      'lib/models/job_offer.dart',
      'lib/data/plan_repository.dart',
      'lib/data/transaction_repository.dart',
      'lib/data/savings_repository.dart',
      'lib/data/job_offer_repository.dart',
    ];

    final missing = required
        .where((path) => !File(path).existsSync())
        .toList();

    if (missing.isEmpty) {
      add(
        'OK',
        'Struktur utama FinPlan',
        'Seluruh file dasar ditemukan.',
      );
    } else {
      add(
        'ERROR',
        'Struktur utama FinPlan',
        'File tidak ditemukan:\n'
            '${missing.join('\n')}',
      );
    }
  }

  // ===================================================
  // RIVERPOD PROVIDERS
  // ===================================================

  void checkRiverpod() {
    final modules = <String, Map<String, String>>{
      'Tawaran Kerja': {
        'file': 'lib/state/job_offer_notifier.dart',
        'provider': 'jobOffersProvider',
      },
      'Transaksi V2': {
        'file': 'lib/state/transaction_riverpod_v2.dart',
        'provider': 'transactionV2Provider',
      },
      'Transaksi UI Bridge': {
        'file': 'lib/state/transaction_notifier.dart',
        'provider': 'transactionStateProvider',
      },
      'Kantong Tabungan V2': {
        'file': 'lib/state/savings_riverpod_v2.dart',
        'provider': 'savingsV2Provider',
      },
      'Kantong Tabungan UI Bridge': {
        'file': 'lib/state/savings_notifier.dart',
        'provider': 'savingsStateProvider',
      },
      'Finance Plan V2': {
        'file': 'lib/state/finance_plan_riverpod_v2.dart',
        'provider': 'financePlanV2Provider',
      },
      'Finance Plan UI Bridge': {
        'file': 'lib/state/finance_plan_notifier.dart',
        'provider': 'financePlanProvider',
      },
      'Settings': {
        'file':
            'lib/features/settings/providers/'
                'app_settings_provider.dart',
        'provider': 'appSettingsProvider',
      },
    };

    for (final entry in modules.entries) {
      final path = entry.value['file']!;
      final provider = entry.value['provider']!;

      if (!File(path).existsSync()) {
        add(
          'MISSING',
          entry.key,
          'File belum ada: $path',
        );
        continue;
      }

      final source = readFile(path);

      if (source.contains(provider)) {
        add(
          'OK',
          entry.key,
          '$provider ditemukan.',
        );
      } else {
        add(
          'REVIEW',
          entry.key,
          '$provider tidak ditemukan di $path',
        );
      }
    }
  }

  // ===================================================
  // FEATURE FLAGS
  // ===================================================

  void checkFeatureFlags() {
    final flags = <String, String>{
      'FINPLAN_TX_V2':
          'lib/state/transaction_notifier.dart',
      'FINPLAN_SAVINGS_V2':
          'lib/state/savings_notifier.dart',
      'FINPLAN_PLAN_V2':
          'lib/state/finance_plan_notifier.dart',
      'FINPLAN_SETTINGS_V2':
          'lib/features/settings/providers/'
              'app_settings_provider.dart',
    };

    for (final entry in flags.entries) {
      final source = readFile(entry.value);

      if (source.contains(entry.key)) {
        add(
          'OK',
          'Feature flag ${entry.key}',
          'Flag tersedia.',
        );
      } else {
        add(
          'REVIEW',
          'Feature flag ${entry.key}',
          'Flag tidak ditemukan.',
        );
      }
    }
  }

  // ===================================================
  // LEGACY CONTROLLER AUDIT
  // ===================================================

  void checkLegacyControllers() {
    final legacyTypes = <String>[
      'PlanController',
      'TransactionController',
      'SavingsController',
      'JobOfferController',
    ];

    final folders = <String>[
      'lib/screens',
      'lib/features',
      'lib/widgets',
    ];

    for (final folder in folders) {
      final directory = Directory(folder);

      if (!directory.existsSync()) continue;

      for (final entity in directory.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File ||
            !entity.path.endsWith('.dart')) {
          continue;
        }

        final lines = entity.readAsLinesSync();

        for (var index = 0;
            index < lines.length;
            index++) {
          final line = lines[index].trim();

          if (line.startsWith('//') ||
              line.startsWith('*')) {
            continue;
          }

          for (final type in legacyTypes) {
            if (line.contains(type)) {
              legacyReferences.add(
                '${entity.path}:${index + 1} '
                '[$type]',
              );
            }
          }
        }
      }
    }

    if (legacyReferences.isEmpty) {
      add(
        'OK',
        'Penggunaan controller pada UI',
        'Tidak ditemukan referensi tipe '
            'controller lama.',
      );
    } else {
      add(
        'REVIEW',
        'Penggunaan controller pada UI',
        '${legacyReferences.length} referensi '
            'masih ditemukan.\n'
            'Controller lama belum aman dihapus.',
      );
    }
  }

  // ===================================================
  // TEST FILES
  // ===================================================

  void checkTests() {
    final expectedTests = <String>[
      'test/job_offer_notifier_test.dart',
      'test/transaction_riverpod_v2_test.dart',
      'test/transaction_v2_bridge_test.dart',
      'test/savings_riverpod_v2_test.dart',
      'test/finance_plan_riverpod_v2_test.dart',
      'test/app_settings_riverpod_v2_test.dart',
    ];

    final present = <String>[];
    final missing = <String>[];

    for (final path in expectedTests) {
      if (File(path).existsSync()) {
        present.add(path);
      } else {
        missing.add(path);
      }
    }

    add(
      missing.isEmpty ? 'OK' : 'REVIEW',
      'Unit test Riverpod V2',
      '${present.length}/${expectedTests.length} '
          'file test ditemukan.'
          '${missing.isEmpty ? '' : '\nBelum ada:\n'
              '${missing.join('\n')}'}',
    );
  }

  // ===================================================
  // PUBSPEC CHECK
  // ===================================================

  void checkPubspec() {
    final content = readFile('pubspec.yaml');

    final version = RegExp(
      r'^version:\s*(.+)$',
      multiLine: true,
    ).firstMatch(content);

    final package = RegExp(
      r'^name:\s*(.+)$',
      multiLine: true,
    ).firstMatch(content);

    add(
      version == null ? 'REVIEW' : 'OK',
      'Versi aplikasi',
      'Package: ${package?.group(1) ?? 'Tidak ada'}\n'
          'Version: ${version?.group(1) ?? 'Tidak ada'}',
    );

    if (content.contains('flutter_riverpod:')) {
      add(
        'OK',
        'Dependency Riverpod',
        'flutter_riverpod tersedia di pubspec.yaml.',
      );
    } else {
      add(
        'ERROR',
        'Dependency Riverpod',
        'flutter_riverpod tidak ditemukan.',
      );
    }
  }

  // ===================================================
  // ANDROID RELEASE
  // ===================================================

  void checkAndroidRelease() {
    final kotlin = File(
      'android/app/build.gradle.kts',
    );
    final groovy = File(
      'android/app/build.gradle',
    );

    final gradle = kotlin.existsSync()
        ? kotlin
        : groovy.existsSync()
            ? groovy
            : null;

    if (gradle == null) {
      add(
        'REVIEW',
        'Android Gradle',
        'File konfigurasi Android tidak ditemukan.',
      );
      return;
    }

    final source = gradle.readAsStringSync();

    if (source.contains('com.example.')) {
      add(
        'REVIEW',
        'Application ID',
        'Masih ditemukan com.example.\n'
            'Periksa applicationId sebelum rilis.',
      );
    } else {
      add(
        'OK',
        'Application ID',
        'Tidak ditemukan pola com.example.',
      );
    }

    final debugSigning = RegExp(
      r'signingConfig\s*=?\s*'
      r'signingConfigs\.getByName\(["\x27]debug',
    );

    if (debugSigning.hasMatch(source)) {
      add(
        'REVIEW',
        'Release signing',
        'Ditemukan referensi debug signing.\n'
            'Periksa apakah dipakai oleh build release.',
      );
    } else {
      add(
        'REVIEW',
        'Release signing',
        'Konfigurasi signing perlu diverifikasi '
            'sebelum membangun AAB.',
      );
    }

    final hasTargetSdk =
        source.contains('targetSdk') ||
            source.contains('targetSdkVersion');

    add(
      hasTargetSdk ? 'OK' : 'REVIEW',
      'Android target SDK',
      hasTargetSdk
          ? 'Konfigurasi targetSdk ditemukan. '
              'Nilainya tetap perlu diperiksa.'
          : 'Konfigurasi targetSdk tidak ditemukan.',
    );
  }

  // ===================================================
  // GIT SECURITY
  // ===================================================

  void checkGitSecurity() {
    final ignore = readFile('.gitignore');

    final signingPatterns = <String>[
      '*.jks',
      '*.keystore',
      'key.properties',
    ];

    final missing = signingPatterns.where(
      (pattern) => !ignore.contains(pattern),
    ).toList();

    if (missing.isEmpty) {
      add(
        'OK',
        'Git signing exclusions',
        'Pola dasar file signing ditemukan.',
      );
    } else {
      add(
        'REVIEW',
        'Git signing exclusions',
        'Pastikan file signing tidak masuk Git.\n'
            'Pola belum ditemukan:\n'
            '${missing.join('\n')}',
      );
    }

    // Deteksi file backup migrasi.
    final backupFiles = <String>[];

    final lib = Directory('lib');

    if (lib.existsSync()) {
      for (final entity in lib.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File &&
            entity.path.endsWith(
              '.before_riverpod.bak',
            )) {
          backupFiles.add(entity.path);
        }
      }
    }

    if (backupFiles.isNotEmpty) {
      add(
        'REVIEW',
        'Backup migrasi',
        '${backupFiles.length} backup ditemukan.\n'
            'Jangan commit backup tersebut ke Git.',
      );
    } else {
      add(
        'OK',
        'Backup migrasi',
        'Tidak ditemukan backup migrasi '
            'di dalam folder lib.',
      );
    }
  }

  // ===================================================
  // GENERATE REPORT
  // ===================================================

  void generateReport() {
    final now = DateTime.now();

    final report = StringBuffer();

    report.writeln(
      '===========================================',
    );
    report.writeln('FINPLAN - PRE-RELEASE AUDIT');
    report.writeln('===========================================');
    report.writeln('Tanggal: $now');
    report.writeln();

    for (final finding in findings) {
      report.writeln(finding.toReport());
    }

    report.writeln();
    report.writeln('===========================================');
    report.writeln('LEGACY CONTROLLER REFERENCES');
    report.writeln('===========================================');

    if (legacyReferences.isEmpty) {
      report.writeln('Tidak ditemukan.');
    } else {
      for (final reference in legacyReferences) {
        report.writeln(reference);
      }
    }

    report.writeln();
    report.writeln('===========================================');
    report.writeln('RECOMMENDED NEXT STEPS');
    report.writeln('===========================================');
    report.writeln('1. Perbaiki flutter analyze.');
    report.writeln('2. Jalankan seluruh flutter test.');
    report.writeln('3. Verifikasi integrasi provider V2.');
    report.writeln('4. Hapus controller lama hanya jika');
    report.writeln('   seluruh referensinya sudah tidak ada.');
    report.writeln('5. Verifikasi Android signing.');
    report.writeln('6. Uji seluruh fitur di HP.');
    report.writeln('7. Bangun Android App Bundle (AAB).');

    final output = report.toString();

    final file = File(
      'finplan_preflight_report.txt',
    );

    file.writeAsStringSync(output);

    stdout.write(output);

    stdout.writeln();
    stdout.writeln(
      'Laporan tersimpan: ${file.path}',
    );
  }

  // ===================================================
  // RUN ALL CHECKS
  // ===================================================

  void run() {
    checkProjectStructure();
    checkRiverpod();
    checkFeatureFlags();
    checkLegacyControllers();
    checkTests();
    checkPubspec();
    checkAndroidRelease();
    checkGitSecurity();
    generateReport();
  }
}

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln(
      'ERROR: Jalankan dari folder utama FinPlan.',
    );
    exitCode = 1;
    return;
  }

  final auditor = FinPlanAuditor();
  auditor.run();
}