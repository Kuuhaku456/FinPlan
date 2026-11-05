
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/finance_plan.dart';

/// Repository untuk menyimpan dan membaca
/// rencana keuangan pengguna secara lokal.
///
/// Pada MVP ini, shared_preferences digunakan
/// untuk menyimpan pengaturan dan rencana
/// keuangan yang dapat dibuat ulang.
///
/// Untuk transaksi finansial aktual,
/// nantinya gunakan database transaksional.

class PlanRepository {
  PlanRepository({
    SharedPreferencesAsync? preferences,
  }) : _preferences =
           preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  // ==========================================
  // 1. KEY PENYIMPANAN
  // ==========================================

  static const String _planKey = 'finplan.plan.v1';

  static const String _darkKey =
      'finplan.dark_mode.v1';

  // Preferensi 3 pilihan: system, light, dark.
  // Kunci lama tetap dipertahankan untuk migrasi pengguna lama.
  static const String _themeModeKey = 'finplan.theme_mode.v1';

  // ==========================================
  // 2. MEMBACA RENCANA KEUANGAN
  // ==========================================

  Future<FinancePlan?> loadPlan() async {
    try {
      final String? raw = await _preferences.getString(
        _planKey,
      );

      // Jika belum ada data yang disimpan
      if (raw == null) {
        return null;
      }

      // Mengubah JSON menjadi object
      final object = jsonDecode(raw);

      if (object is! Map<String, dynamic>) {
        return null;
      }

      // Mengubah object menjadi FinancePlan
      return FinancePlan.fromJson(object);
    } catch (e) {
      // Jika data rusak atau gagal dibaca
      return null;
    }
  }

  // ==========================================
  // 3. MENYIMPAN RENCANA KEUANGAN
  // ==========================================

  Future<void> savePlan(FinancePlan plan) async {
    // Mengubah FinancePlan menjadi JSON
    final String jsonData = jsonEncode(
      plan.toJson(),
    );

    // Menyimpan JSON ke perangkat
    await _preferences.setString(
      _planKey,
      jsonData,
    );
  }

  // ==========================================
  // 4. MEMBACA PENGATURAN DARK MODE
  // ==========================================

  Future<bool> loadDarkMode() async {
    final bool? darkMode = await _preferences.getBool(
      _darkKey,
    );

    return darkMode ?? false;
  }

  /// Untuk instalasi baru, ikuti tema HP. Untuk pengguna lama,
  /// pertahankan pilihan terang/gelap yang pernah disimpan.
  Future<String> loadThemePreference() async {
    final stored = await _preferences.getString(_themeModeKey);
    if (stored == 'system' || stored == 'light' || stored == 'dark') {
      return stored!;
    }

    final legacy = await _preferences.getBool(_darkKey);
    if (legacy != null) return legacy ? 'dark' : 'light';
    return 'system';
  }

  Future<void> saveThemePreference(String value) async {
    if (value != 'system' && value != 'light' && value != 'dark') {
      throw ArgumentError.value(value, 'value', 'Mode tema tidak dikenal');
    }
    await _preferences.setString(_themeModeKey, value);
  }

  // ==========================================
  // 5. MENYIMPAN PENGATURAN DARK MODE
  // ==========================================

  Future<void> saveDarkMode(bool enabled) async {
    await _preferences.setBool(
      _darkKey,
      enabled,
    );
    await _preferences.setString(
      _themeModeKey,
      enabled ? 'dark' : 'light',
    );
  }

  // ==========================================
  // 6. MENGHAPUS RENCANA KEUANGAN
  // ==========================================

  Future<void> clearPlan() async {
    await _preferences.remove(
      _planKey,
    );
  }
}
