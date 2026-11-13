import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:celeng_id/data/plan_repository.dart';
import 'package:celeng_id/features/settings/providers/app_settings_provider.dart';
import 'package:celeng_id/state/plan_controller.dart';

// =====================================================
// FINPLAN - SETTINGS RIVERPOD V2 TEST
// =====================================================
//
// Fake Repository dan Fake Preferences.
// Tidak memerlukan plugin perangkat.
// Tidak mengubah data FinPlan asli.
// =====================================================

class _MemoryPlanRepository extends Fake implements PlanRepository {
  String savedTheme = 'system';
  bool failOnSave = false;

  final List<String> themeWrites = [];

  @override
  Future<void> saveThemePreference(String value) async {
    if (failOnSave) {
      throw StateError('Gagal menyimpan preferensi tema.');
    }

    if (!const ['system', 'light', 'dark'].contains(value)) {
      throw ArgumentError.value(value, 'value', 'Mode tema tidak valid.');
    }

    savedTheme = value;
    themeWrites.add(value);
  }

  @override
  Future<String> loadThemePreference() async {
    return savedTheme;
  }
}

class _MemoryPreferences extends Fake implements SharedPreferencesAsync {
  final Map<String, double> doubles = {};

  @override
  Future<void> setDouble(String key, double value) async {
    doubles[key] = value;
  }

  @override
  Future<double?> getDouble(String key) async {
    return doubles[key];
  }
}

// =====================================================
// TEST SUITE
// =====================================================

void main() {
  late ProviderContainer container;
  late _MemoryPlanRepository repository;
  late _MemoryPreferences preferences;

  setUp(() {
    repository = _MemoryPlanRepository();
    preferences = _MemoryPreferences();

    container = ProviderContainer(
      overrides: [
        appSettingsV2ModeProvider.overrideWithValue(true),
        settingsThemeRepositoryProvider.overrideWithValue(repository),
        settingsPreferencesProvider.overrideWithValue(preferences),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // ===================================================
  // TEST 1 - INITIAL STATE
  // ===================================================

  test('Pengaturan awal mengikuti sistem', () {
    final state = container.read(appSettingsProvider);

    expect(state.themeMode, ThemeMode.system);
    expect(state.fontScale, 1.0);
    expect(repository.themeWrites, isEmpty);
  });

  // ===================================================
  // TEST 2 - DARK MODE
  // ===================================================

  test('Dark Mode disimpan melalui repository', () async {
    final notifier = container.read(appSettingsProvider.notifier);

    await notifier.setThemeMode(ThemeMode.dark);

    final state = container.read(appSettingsProvider);

    expect(state.themeMode, ThemeMode.dark);
    expect(repository.savedTheme, 'dark');
    expect(repository.themeWrites, ['dark']);
  });

  // ===================================================
  // TEST 3 - SYSTEM MODE
  // ===================================================

  test('Tema sistem bisa dipilih kembali', () async {
    final notifier = container.read(appSettingsProvider.notifier);

    await notifier.setThemeMode(ThemeMode.light);

    await notifier.setThemeMode(ThemeMode.system);

    expect(container.read(appSettingsProvider).themeMode, ThemeMode.system);

    expect(repository.savedTheme, 'system');
  });

  // ===================================================
  // TEST 4 - TOGGLE
  // ===================================================

  test('Toggle tema menggunakan brightness', () async {
    final notifier = container.read(appSettingsProvider.notifier);

    await notifier.toggleTheme(Brightness.light);

    expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);

    await notifier.toggleTheme(Brightness.dark);

    expect(container.read(appSettingsProvider).themeMode, ThemeMode.light);

    expect(repository.savedTheme, 'light');
  });

  // ===================================================
  // TEST 5 - NO DUPLICATE SAVE
  // ===================================================

  test('Tema yang sama tidak disimpan ulang', () async {
    final notifier = container.read(appSettingsProvider.notifier);

    await notifier.setThemeMode(ThemeMode.dark);

    await notifier.setThemeMode(ThemeMode.dark);

    expect(repository.themeWrites, ['dark']);
  });

  // ===================================================
  // TEST 6 - SAVE FAILURE
  // ===================================================

  test('Gagal simpan mengembalikan tema lama', () async {
    repository.failOnSave = true;

    final notifier = container.read(appSettingsProvider.notifier);

    await expectLater(notifier.setThemeMode(ThemeMode.dark), throwsStateError);

    expect(container.read(appSettingsProvider).themeMode, ThemeMode.system);

    expect(repository.savedTheme, 'system');
  });

  // ===================================================
  // TEST 7 - FONT SCALE
  // ===================================================

  test('Ukuran font disimpan ke preferences', () async {
    final notifier = container.read(appSettingsProvider.notifier);

    notifier.setFontScale(1.26);

    await notifier.waitForFontSaves();

    final state = container.read(appSettingsProvider);

    expect(state.fontScale, 1.25);

    expect(preferences.doubles[kFontScaleKey], 1.25);
  });

  // ===================================================
  // TEST 8 - FONT VALIDATION
  // ===================================================

  test('Ukuran font dibatasi 100 sampai 150 persen', () async {
    final notifier = container.read(appSettingsProvider.notifier);

    notifier.setFontScale(4.0);
    expect(container.read(appSettingsProvider).fontScale, 1.5);

    notifier.setFontScale(0.5);
    expect(container.read(appSettingsProvider).fontScale, 1.0);

    notifier.setFontScale(double.nan);
    expect(container.read(appSettingsProvider).fontScale, 1.0);

    await notifier.waitForFontSaves();

    expect(preferences.doubles[kFontScaleKey], 1.0);
  });

  // ===================================================
  // TEST 9 - CONCURRENT THEME WRITES
  // ===================================================

  test('Perubahan tema disimpan berurutan', () async {
    final notifier = container.read(appSettingsProvider.notifier);

    await Future.wait([
      notifier.setThemeMode(ThemeMode.light),
      notifier.setThemeMode(ThemeMode.dark),
    ]);

    expect(repository.themeWrites, ['light', 'dark']);

    expect(repository.savedTheme, 'dark');

    expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
  });

  // ===================================================
  // TEST 10 - LEGACY FALLBACK
  // ===================================================

  test('Mode lama tetap menggunakan PlanController', () async {
    final legacyRepository = _MemoryPlanRepository();

    final legacyController = PlanController(
      legacyRepository,
      null,
      ThemeMode.system,
    );

    final legacyContainer = ProviderContainer(
      overrides: [
        appSettingsV2ModeProvider.overrideWithValue(false),
        settingsPlanControllerProvider.overrideWithValue(legacyController),
      ],
    );

    addTearDown(() {
      legacyContainer.dispose();
      legacyController.dispose();
    });

    final notifier = legacyContainer.read(appSettingsProvider.notifier);

    await notifier.setThemeMode(ThemeMode.dark);

    expect(legacyController.themeMode, ThemeMode.dark);

    expect(legacyRepository.savedTheme, 'dark');

    expect(legacyContainer.read(appSettingsProvider).themeMode, ThemeMode.dark);
  });
}