import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'plan_controller.dart';

/// Key lama sengaja dipertahankan supaya ukuran teks yang pernah disimpan
/// pengguna tidak hilang saat FinPlan mulai menggunakan Riverpod.
const String kFontScaleKey = 'finplan.font_scale.v1';

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

/// Nilai awal dibaca sebelum runApp(), sehingga tidak ada kilatan tema
/// terang ketika pengguna sebelumnya memilih dark mode.
final initialAppSettingsProvider = Provider<AppSettingsState>(
  (ref) => const AppSettingsState(
    themeMode: ThemeMode.system,
    fontScale: 1.0,
  ),
);

/// Bridge sementara ke controller dan penyimpanan lama.
/// Nantinya dapat diganti repository khusus Settings tanpa mengubah UI.
final settingsPlanControllerProvider = Provider<PlanController>(
  (ref) => throw StateError('PlanController belum diinisialisasi.'),
);

final settingsPreferencesProvider = Provider<SharedPreferencesAsync>(
  (ref) => throw StateError('Preferences belum diinisialisasi.'),
);

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettingsState>(
  AppSettingsController.new,
);

class AppSettingsController extends Notifier<AppSettingsState> {
  Future<void> _pendingFontSave = Future<void>.value();

  @override
  AppSettingsState build() => ref.watch(initialAppSettingsProvider);

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.themeMode == mode) return;

    final previous = state;
    state = state.copyWith(themeMode: mode);

    try {
      await ref.read(settingsPlanControllerProvider).changeThemeMode(mode);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> toggleTheme(Brightness currentBrightness) {
    return setThemeMode(
      currentBrightness == Brightness.dark
          ? ThemeMode.light
          : ThemeMode.dark,
    );
  }

  /// Perubahan font langsung terlihat di UI; penyimpanan dijalankan
  /// berurutan agar interaksi slider tidak menyebabkan race condition.
  void setFontScale(double value) {
    if (!value.isFinite) return;

    final clamped = value.clamp(1.0, 1.5).toDouble();
    final next = ((clamped * 20).round() / 20.0).clamp(1.0, 1.5).toDouble();
    if (state.fontScale == next) return;

    state = state.copyWith(fontScale: next);
    final preferences = ref.read(settingsPreferencesProvider);

    _pendingFontSave = _pendingFontSave.then((_) async {
      try {
        await preferences.setDouble(kFontScaleKey, next);
      } catch (_) {
        // Pilihan font tetap berlaku pada sesi aktif meski gagal disimpan.
      }
    });

    unawaited(_pendingFontSave);
  }
}
