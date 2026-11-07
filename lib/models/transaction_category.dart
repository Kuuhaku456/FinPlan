// ==========================================
// FINPLAN - TRANSACTION CATEGORY MODEL
// ==========================================
//
// Kategori digunakan untuk mengelompokkan
// pengeluaran dan kebutuhan pengguna.
//
// Kategori ini nantinya digunakan pada:
// - Form tambah transaksi
// - Form edit transaksi
// - Analisis pengeluaran
// - Dashboard kategori
// - Laporan keuangan
// ==========================================

enum TransactionCategory {
  food,
  transport,
  bills,
  groceries,
  housing,
  healthcare,
  education,
  entertainment,
  shopping,
  worship,
  savings,
  other,
}

// ==========================================
// CATEGORY EXTENSION
// ==========================================

extension TransactionCategoryExtension on TransactionCategory {
  // ========================================
  // 1. NAMA KATEGORI
  // ========================================

  String get label {
    switch (this) {
      case TransactionCategory.food:
        return 'Makanan & Minuman';

      case TransactionCategory.transport:
        return 'Transportasi';

      case TransactionCategory.bills:
        return 'Tagihan';

      case TransactionCategory.groceries:
        return 'Kebutuhan Harian';

      case TransactionCategory.housing:
        return 'Tempat Tinggal';

      case TransactionCategory.healthcare:
        return 'Kesehatan';

      case TransactionCategory.education:
        return 'Pendidikan';

      case TransactionCategory.entertainment:
        return 'Hiburan';

      case TransactionCategory.shopping:
        return 'Belanja';

      case TransactionCategory.worship:
        return 'Perpuluhan & Persembahan';

      case TransactionCategory.savings:
        return 'Tabungan';

      case TransactionCategory.other:
        return 'Lainnya';
    }
  }

  // ========================================
  // 2. EMOJI KATEGORI
  // ========================================

  String get emoji {
    switch (this) {
      case TransactionCategory.food:
        return '🍔';

      case TransactionCategory.transport:
        return '🚆';

      case TransactionCategory.bills:
        return '🧾';

      case TransactionCategory.groceries:
        return '🛒';

      case TransactionCategory.housing:
        return '🏠';

      case TransactionCategory.healthcare:
        return '🏥';

      case TransactionCategory.education:
        return '📚';

      case TransactionCategory.entertainment:
        return '🎮';

      case TransactionCategory.shopping:
        return '🛍️';

      case TransactionCategory.worship:
        return '⛪';

      case TransactionCategory.savings:
        return '💰';

      case TransactionCategory.other:
        return '📦';
    }
  }

  // ========================================
  // 3. KETERANGAN KATEGORI
  // ========================================

  String get description {
    switch (this) {
      case TransactionCategory.food:
        return 'Makan, minum, restoran, dan jajanan';

      case TransactionCategory.transport:
        return 'KRL, MRT, TransJakarta, ojek, dan transportasi lainnya';

      case TransactionCategory.bills:
        return 'Listrik, air, internet, pulsa, dan tagihan bulanan';

      case TransactionCategory.groceries:
        return 'Belanja kebutuhan rumah tangga dan kebutuhan sehari-hari';

      case TransactionCategory.housing:
        return 'Sewa, kos, kontrakan, dan kebutuhan tempat tinggal';

      case TransactionCategory.healthcare:
        return 'Obat, konsultasi dokter, dan biaya kesehatan';

      case TransactionCategory.education:
        return 'Sekolah, kuliah, kursus, dan buku';

      case TransactionCategory.entertainment:
        return 'Film, permainan, rekreasi, dan hiburan';

      case TransactionCategory.shopping:
        return 'Pakaian, aksesori, dan barang pribadi';

      case TransactionCategory.worship:
        return 'Perpuluhan, persembahan, dan donasi keagamaan';

      case TransactionCategory.savings:
        return 'Alokasi atau pemindahan uang ke tabungan';

      case TransactionCategory.other:
        return 'Pengeluaran lain yang tidak termasuk kategori tersedia';
    }
  }

  // ========================================
  // 4. NAMA UNTUK DATABASE
  // ========================================

  String get databaseValue => name;

  // ========================================
  // 5. MEMBACA KATEGORI DARI DATABASE
  // ========================================

  static TransactionCategory fromDatabase(
    Object? value,
  ) {
    final categoryName = value?.toString();

    for (final category in TransactionCategory.values) {
      if (category.name == categoryName) {
        return category;
      }
    }

    // Transaksi lama yang belum memiliki
    // kategori otomatis masuk kategori Lainnya.
    return TransactionCategory.other;
  }
}