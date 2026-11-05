
import 'package:flutter/material.dart';

import '../data/plan_repository.dart';
import '../models/finance_plan.dart';

/// Controller untuk mengelola state
/// rencana keuangan aplikasi FinPlan.
///
/// Menggunakan ChangeNotifier agar
/// tampilan Flutter diperbarui saat
/// terjadi perubahan data.

class PlanController extends ChangeNotifier {
  // ==========================================
  // 1. CONSTRUCTOR
  // ==========================================

  PlanController(
    this._repository,
    this._plan,
    this._themeMode,
  );

  // ==========================================
  // 2. VARIABLE PRIVATE
  // ==========================================

  final PlanRepository _repository;

  FinancePlan? _plan;

  ThemeMode _themeMode;

  // ==========================================
  // 3. GETTER
  // ==========================================

  /// Mengambil rencana keuangan aktif.
  FinancePlan? get plan => _plan;

  /// Pilihan pengguna, bukan sekadar tema yang sedang tampil.
  ThemeMode get themeMode => _themeMode;

  /// Kompatibilitas dengan tombol gelap/terang yang sudah ada.
  bool get darkMode => _themeMode == ThemeMode.dark ||
      (_themeMode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  // ==========================================
  // 4. MENYIMPAN RENCANA KEUANGAN
  // ==========================================

  Future<void> savePlan(FinancePlan newPlan) async {
    // Simpan data ke penyimpanan lokal.
    await _repository.savePlan(newPlan);

    // Perbarui data pada controller.
    _plan = newPlan;

    // Beri tahu widget bahwa data berubah.
    notifyListeners();
  }

  // ==========================================
  // 5. MENGUBAH TEMA APLIKASI
  // ==========================================

  Future<void> changeThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    final previous = _themeMode;
    _themeMode = mode;
    notifyListeners();

    try {
      await _repository.saveThemePreference(mode.name);
    } catch (_) {
      // Jika gagal menyimpan, kembalikan pilihan sebelumnya.
      _themeMode = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> changeDarkMode(bool enabled) =>
      changeThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);

  // ==========================================
  // 6. MENGHAPUS RENCANA KEUANGAN
  // ==========================================

  Future<void> clearPlan() async {
    // Hapus rencana dari penyimpanan lokal.
    await _repository.clearPlan();

    // Kosongkan data aktif.
    _plan = null;

    // Perbarui tampilan aplikasi.
    notifyListeners();
  }
}
