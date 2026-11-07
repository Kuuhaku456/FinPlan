/// ============================================
/// FINPLAN - STORAGE KEYS
/// ============================================
///
/// Semua key penyimpanan ditempatkan di sini.
///
/// Jangan mengubah nilai key yang sudah digunakan,
/// karena data pengguna lama bergantung padanya.
library;

abstract final class StorageKeys {
  static const String fontScale =
      'finplan.font_scale.v1';
}

/// Alias sementara untuk kode lama.
const String kFontScaleKey =
    StorageKeys.fontScale;