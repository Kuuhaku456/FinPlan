import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../state/plan_controller.dart';

export '../../../core/constants/storage_keys.dart'
    show kFontScaleKey;

// ============================================
// FINPLAN - APP SETTINGS STATE
// ============================================

@immutable
class AppSettingsState {
  const AppSettingsState({
    required this.themeMode,
    required this.fontScale,
  });

  final ThemeMode themeMode;
  final double fontScale;

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    double? fontScale,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
    );
  }
}

// ============================================
// INITIAL APP SETTINGS
// ============================================

/// Nilai awal di-override saat aplikasi dimulai.
///
/// Tujuannya agar aplikasi langsung menggunakan
/// tema yang sebelumnya dipilih pengguna.

final initialAppSettingsProvider =
    Provider<AppSettingsState>(
  (ref) => const AppSettingsState(
    themeMode: ThemeMode.system,
    fontScale: 1.0,
  ),
);

// ============================================
// TEMPORARY LEGACY BRIDGE
// ============================================

/// Digunakan sementara selama PlanController
/// lama belum sepenuhnya dimigrasikan.

final settingsPlanControllerProvider =
    Provider<PlanController>(
  (ref) => throw StateError(
    'PlanController belum diinisialisasi.',
  ),
);

final settingsPreferencesProvider =
    Provider<SharedPreferencesAsync>(
  (ref) => throw StateError(
    'Preferences belum diinisialisasi.',
  ),
);

// ============================================
// SETTINGS PROVIDER
// ============================================

final appSettingsProvider =
    NotifierProvider<
        AppSettingsController,
        AppSettingsState>(
  AppSettingsController.new,
);

// ============================================
// SETTINGS NOTIFIER
// ============================================

class AppSettingsController
    extends Notifier<AppSettingsState> {
  Future<void> _pendingFontSave =
      Future<void>.value();

  @override
  AppSettingsState build() {
    return ref.watch(initialAppSettingsProvider);
  }

  // ==========================================
  // CHANGE THEME
  // ==========================================

  Future<void> setThemeMode(
    ThemeMode mode,
  ) async {
    if (state.themeMode == mode) {
      return;
    }

    final previous = state;

    state = state.copyWith(
      themeMode: mode,
    );

    try {
      await ref
          .read(settingsPlanControllerProvider)
          .changeThemeMode(mode);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  // ==========================================
  // TOGGLE THEME
  // ==========================================

  Future<void> toggleTheme(
    Brightness currentBrightness,
  ) {
    return setThemeMode(
      currentBrightness == Brightness.dark
          ? ThemeMode.light
          : ThemeMode.dark,
    );
  }

  // ==========================================
  // FONT SCALE
  // ==========================================

  void setFontScale(double value) {
    if (!value.isFinite) {
      return;
    }

    final clamped =
        value.clamp(1.0, 1.5).toDouble();

    final next =
        ((clamped * 20).round() / 20.0)
            .clamp(1.0, 1.5)
            .toDouble();

    if (state.fontScale == next) {
      return;
    }

    // Perbarui state melalui Riverpod.
    state = state.copyWith(
      fontScale: next,
    );

    final preferences =
        ref.read(settingsPreferencesProvider);

    // Penyimpanan dilakukan secara berurutan.
    _pendingFontSave =
        _pendingFontSave.then((_) async {
      try {
        await preferences.setDouble(
          kFontScaleKey,
          next,
        );
      } catch (_) {
        // Pengaturan tetap aktif selama sesi ini
        // meskipun penyimpanan gagal.
      }
    });

    unawaited(_pendingFontSave);
  }
}