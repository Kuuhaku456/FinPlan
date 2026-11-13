import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/plan_repository.dart';
import '../../../state/plan_controller.dart';

// =====================================================
// FINPLAN - APP SETTINGS RIVERPOD V2
// =====================================================
//
// Fitur:
// - System Theme
// - Light Mode
// - Dark Mode
// - Font Scale 100% - 150%
// - Penyimpanan preferensi
// - Dukungan mode legacy
// - Dukungan unit test
//
// Tidak mengubah data transaksi, tabungan,
// atau Finance Plan.
//
// =====================================================

// Alias storage key untuk kompatibilitas.
export '../../../core/constants/storage_keys.dart' show kFontScaleKey;

// =====================================================
// APP SETTINGS STATE
// =====================================================

@immutable
class AppSettingsState {
  const AppSettingsState({required this.themeMode, required this.fontScale});

  final ThemeMode themeMode;
  final double fontScale;

  AppSettingsState copyWith({ThemeMode? themeMode, double? fontScale}) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
    );
  }
}

// =====================================================
// RIVERPOD V2 MODE PROVIDER
// =====================================================

// Aktifkan dengan:
// flutter run --dart-define=FINPLAN_SETTINGS_V2=true
//
// Tanpa flag, tetap menggunakan PlanController lama.

final appSettingsV2ModeProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('FINPLAN_SETTINGS_V2', defaultValue: false);
});

// =====================================================
// INITIAL APP SETTINGS
// =====================================================

// Di-override pada main.dart menggunakan tema
// dan ukuran font yang sebelumnya tersimpan.

final initialAppSettingsProvider = Provider<AppSettingsState>((ref) {
  return const AppSettingsState(themeMode: ThemeMode.system, fontScale: 1.0);
});

// =====================================================
// SHARED PREFERENCES PROVIDER
// =====================================================

// Di-override pada main.dart.
// Digunakan untuk menyimpan ukuran font.

final settingsPreferencesProvider = Provider<SharedPreferencesAsync>((ref) {
  throw StateError('SharedPreferencesAsync belum diinisialisasi.');
});

// =====================================================
// THEME REPOSITORY PROVIDER
// =====================================================

// Riverpod V2 menyimpan tema secara langsung
// melalui PlanRepository.
//
// Menggunakan storage key yang sudah ada:
// finplan.theme_mode.v1

final settingsThemeRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(preferences: ref.read(settingsPreferencesProvider));
});

// =====================================================
// LEGACY PLAN CONTROLLER PROVIDER
// =====================================================

// Dipertahankan supaya kode main.dart dan
// mode lama tetap kompatibel.

final settingsPlanControllerProvider = Provider<PlanController>((ref) {
  throw StateError('PlanController belum diinisialisasi.');
});

// =====================================================
// MAIN APP SETTINGS PROVIDER
// =====================================================

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettingsState>(
      AppSettingsController.new,
    );

// =====================================================
// APP SETTINGS CONTROLLER
// =====================================================

class AppSettingsController extends Notifier<AppSettingsState> {
  // Antrean penyimpanan tema.
  Future<void> _themeQueue = Future<void>.value();

  // Antrean penyimpanan ukuran font.
  Future<void> _fontQueue = Future<void>.value();

  // ===================================================
  // INITIAL STATE
  // ===================================================

  @override
  AppSettingsState build() {
    return ref.watch(initialAppSettingsProvider);
  }

  // ===================================================
  // SAVE THEME
  // ===================================================

  Future<void> _saveTheme(ThemeMode mode) async {
    final previous = _themeQueue;
    final completed = Completer<void>();

    // Operasi berikutnya menunggu operasi ini.
    _themeQueue = completed.future;

    try {
      await previous;

      final useV2 = ref.read(appSettingsV2ModeProvider);

      if (useV2) {
        // ============================================
        // RIVERPOD V2
        // ============================================

        await ref
            .read(settingsThemeRepositoryProvider)
            .saveThemePreference(mode.name);
      } else {
        // ============================================
        // LEGACY
        // ============================================

        await ref.read(settingsPlanControllerProvider).changeThemeMode(mode);
      }
    } finally {
      completed.complete();
    }
  }

  // ===================================================
  // SET THEME MODE
  // ===================================================

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.themeMode == mode) {
      return;
    }

    // Simpan nilai lama untuk rollback.
    final previousMode = state.themeMode;

    // Perbarui UI secara langsung.
    state = state.copyWith(themeMode: mode);

    try {
      await _saveTheme(mode);
    } catch (_) {
      // Jika penyimpanan gagal, kembalikan tema.
      //
      // Rollback hanya dilakukan jika pengguna
      // belum memilih tema lain.

      if (ref.mounted && state.themeMode == mode) {
        state = state.copyWith(themeMode: previousMode);
      }

      rethrow;
    }
  }

  // ===================================================
  // TOGGLE THEME
  // ===================================================

  Future<void> toggleTheme(Brightness currentBrightness) {
    final nextMode = currentBrightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;

    return setThemeMode(nextMode);
  }

  // ===================================================
  // SET FONT SCALE
  // ===================================================

  void setFontScale(double value) {
    // Menolak nilai yang tidak valid.
    if (!value.isFinite) {
      return;
    }

    // Batasi 100% sampai 150%.
    final clamped = value.clamp(1.0, 1.5).toDouble();

    // Pembulatan kelipatan 5%.
    final next = ((clamped * 20).round() / 20.0).clamp(1.0, 1.5).toDouble();

    // Tidak menyimpan apabila nilainya sama.
    if (state.fontScale == next) {
      return;
    }

    // Perbarui tampilan terlebih dahulu.
    state = state.copyWith(fontScale: next);

    final preferences = ref.read(settingsPreferencesProvider);

    // ================================================
    // SAVE FONT SCALE
    // ================================================

    // Operasi dijalankan berurutan supaya
    // perubahan slider tidak saling menimpa.

    _fontQueue = _fontQueue.then((_) async {
      try {
        await preferences.setDouble(kFontScaleKey, next);
      } catch (_) {
        // Jika penyimpanan gagal,
        // perubahan tetap aktif selama sesi.
      }
    });

    unawaited(_fontQueue);
  }

  // ===================================================
  // WAIT FOR FONT SAVES
  // ===================================================

  // Digunakan untuk memastikan seluruh operasi
  // penyimpanan font selesai.
  //
  // Method ini juga dibutuhkan oleh unit test.

  Future<void> waitForFontSaves() {
    return _fontQueue;
  }

  // ===================================================
  // WAIT FOR THEME SAVES
  // ===================================================

  Future<void> waitForThemeSaves() {
    return _themeQueue;
  }
}
