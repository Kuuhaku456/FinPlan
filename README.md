# 💚 FinPlan

### Your Personal Finance Partner

**Rencanakan penghasilan, pahami kebutuhan, catat transaksi, dan capai tujuan keuangan dalam satu aplikasi.**

![Flutter](https://img.shields.io/badge/Flutter-Mobile%20App-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-Language-0175C2?logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)
![Status](https://img.shields.io/badge/Status-Active%20Development-059669)

FinPlan adalah aplikasi pengelolaan dan perencanaan keuangan pribadi berbasis **Flutter**. Fokusnya bukan hanya mencatat uang masuk dan keluar, tetapi juga membantu pengguna membuat anggaran yang sesuai dengan kehidupan sehari-hari, menabung untuk berbagai tujuan, dan mengevaluasi pilihan keuangan.

Setiap orang mempunyai rutinitas berbeda. Karena itu, anggaran makan, perjalanan, kebutuhan tambahan, dan target tabungan di FinPlan dibuat **fleksibel dan dapat disesuaikan**.

> **Status:** proyek masih dalam pengembangan dan pengujian. Informasi fitur di bawah menggambarkan implementasi yang tersedia di source code; belum seluruh alur diverifikasi pada semua perangkat Android. Aplikasi belum dinyatakan siap rilis publik.

---

## 🆕 Pembaruan Terbaru — November 2026

Pembaruan ini mencakup pengembangan fitur sekaligus penataan ulang arsitektur project.

| Area | Perubahan |
| --- | --- |
| **Struktur project** | Mulai memisahkan modul **Dashboard, Planner, dan Settings** ke dalam `lib/features/`, masing-masing dengan bagian `presentation/` dan `providers/`. |
| **Manajemen state** | Mulai menggunakan **Riverpod** (`Notifier`, `ConsumerWidget`, dan provider) untuk memisahkan UI dengan pengelolaan data. Beberapa `ChangeNotifier` lama masih digunakan selama migrasi. |
| **Dashboard** | Komponen alokasi anggaran, tren transaksi bulanan, ringkasan pengeluaran, dan tabungan ditata menjadi widget yang lebih mudah dikelola. |
| **Planner** | Form perencanaan dipisahkan menurut langkah: profil dan pemasukan, kebutuhan, makan harian, transportasi, tabungan, serta ringkasan. |
| **Transaksi** | Penguatan pengelolaan daftar transaksi, ringkasan periode, dan integrasi statistik transaksi untuk dashboard. |
| **Kantong Tabungan** | Pemisahan state tampilan dan logika data; tetap mendukung target, setoran, penarikan, serta arsip/pulihkan. |
| **Tawaran Kerja** | Form **Tawaran Baru** dibuat lebih terstruktur dalam bagian penghasilan, jadwal kerja, transportasi, biaya tambahan, dan preferensi pribadi. Data tawaran dapat dikelola dan disimpan secara lokal. |
| **Tampilan & Settings** | Pengaturan tema, skala teks, dan komponen halaman pengaturan mulai dipisahkan dari kode halaman utama. |
| **Pengujian** | Menambahkan/mengembangkan pengujian logika rencana, anggaran, transaksi, tren bulanan, serta ringkasan tabungan. |

### Catatan pengembangan

- **Migrasi bertahap:** folder `screens/`, `state/`, dan `widgets/` belum dihapus. Sebagian halaman sudah memiliki implementasi/modul baru di `features/` atau versi Riverpod.
- **Tawaran Baru:** komponen input berbentuk panel yang dapat dibuka/tutup sedang diuji untuk mengatasi *runtime assertion* saat panel dibuka, terutama pada layar Android. Hasil `flutter analyze` atau `flutter test` yang lolos tidak otomatis menjamin masalah UI ini telah selesai.
- **Android release:** proses build APK perlu memastikan SDK Android dan plugin kompatibel, khususnya `compileSdk` sesuai kebutuhan plugin. APK yang berhasil dibangun tetap perlu diuji secara langsung di perangkat.

---

## ✨ Fitur Utama

### 🏠 1. Dashboard Keuangan

- Ringkasan pemasukan, anggaran, pengeluaran, dan tabungan.
- Diagram pembagian gaji/anggaran untuk membantu membaca alokasi dana.
- Kartu ringkasan pengeluaran dan tren transaksi bulanan.
- Ringkasan progres kantong tabungan.

### 🧩 2. Planner — Rencana & Anggaran

Perencanaan keuangan yang menyesuaikan rutinitas pengguna:

- **Pendapatan:** gaji utama dan pemasukan tambahan.
- **Kebutuhan:** pengeluaran rutin dan kategori kebutuhan khusus.
- **Makan:** nominal dapat berbeda untuk setiap hari, Senin–Minggu.
- **Transportasi:** rencana perjalanan pergi dan pulang, termasuk kombinasi beberapa moda.
- **Tabungan:** target menabung serta dana cadangan dalam rencana keuangan.
- **Pembagian gaji:** ringkasan alokasi dan sisa dana berdasarkan input pengguna.

### 💸 3. Pencatatan Transaksi

- Menambahkan **pemasukan** dan **pengeluaran**, dengan nominal Rupiah dan tanggal transaksi.
- Menentukan kategori, sumber dana (bank, dompet digital, tunai, atau akun tambahan), dan catatan.
- Melihat ringkasan transaksi sesuai periode/bulan.
- Mengedit dan menghapus transaksi dengan konfirmasi.
- Menampilkan daftar panjang secara bertahap (*pagination*).
- Menggunakan **SQLite** untuk penyimpanan transaksi pada perangkat.

### 🎯 4. Kantong Tabungan

- Membuat beberapa target tabungan dengan nama, emoji, deskripsi, target nominal, dan tenggat opsional.
- Melihat persentase progres setiap target.
- Menambah dan mengambil uang secara manual.
- Menelusuri riwayat pergerakan saldo.
- Mengarsipkan dan memulihkan kantong yang tidak aktif.

### 🧮 5. Simulasi Tawaran Kerja — *Is This Job Worth It?*

Membantu pengguna menganalisis tawaran pekerjaan berdasarkan data yang diisi:

1. **Penghasilan:** gaji, pemasukan lain, tunjangan, atau potongan.
2. **Jadwal kerja:** jumlah hari bekerja, kehadiran di kantor, dan waktu kerja.
3. **Transportasi:** ongkos, jarak, serta durasi perjalanan.
4. **Biaya tambahan:** makan saat bekerja, parkir, dan kebutuhan lainnya.
5. **Kebutuhan hidup:** dibandingkan dengan rencana pengeluaran.
6. **Preferensi:** target uang tersisa, kenyamanan perjalanan, prospek kerja, dan faktor pribadi.

Hasil simulasi dapat menampilkan penilaian **Tier S–D**:

| Tier | Interpretasi |
| :---: | --- |
| **S** | Sangat sesuai dengan target yang dimasukkan. |
| **A** | Menarik, dengan sebagian besar kebutuhan terpenuhi. |
| **B** | Cukup layak, masih ada kompromi. |
| **C** | Perlu dipertimbangkan kembali. |
| **D** | Kurang sesuai dengan kebutuhan/prioritas. |

Pada rancangan penilaian, kebutuhan dan target keuangan memperoleh bobot terbesar; waktu perjalanan, jam kerja, pengembangan karier, dan kenyamanan juga diperhitungkan.

> **Disclaimer:** peringkat ini adalah **hasil simulasi**, bukan jaminan bahwa suatu pekerjaan layak atau aman, dan tidak menggantikan pertimbangan pribadi maupun nasihat profesional.

### 💼 6. Pengelolaan Tawaran Kerja

- Menyimpan beberapa tawaran pekerjaan di perangkat.
- Melihat kembali, memperbarui, dan menghapus tawaran.
- Mengarsipkan dan memulihkan tawaran untuk menjaga daftar tetap rapi.

### 📆 7. Simulasi Sisa Uang

Menghitung perkiraan penggunaan saldo tersisa sampai tanggal gajian berikutnya, dengan pertimbangan makan, transportasi, dan kebutuhan tambahan.

### ⚙️ 8. Profil, Tema, dan Aksesibilitas

- Profil pengguna dan foto profil lokal.
- **Light Mode**, **Dark Mode**, atau **mengikuti tema perangkat**.
- Pengaturan ukuran teks untuk membantu keterbacaan.
- Desain antarmuka hijau khas FinPlan.

---

## 📱 Alur dan Navigasi

1. **Welcome Slides** ditampilkan saat pertama kali menggunakan aplikasi.
2. **Onboarding** mengumpulkan informasi awal untuk penyusunan rencana keuangan.
3. Pengguna masuk ke **Dashboard** dan dapat melanjutkan ke fitur lain.

Navigasi utama aplikasi menggunakan empat tab:

| Tab | Fungsi |
| --- | --- |
| **Home** | Dashboard, informasi anggaran, pengeluaran, dan tabungan. |
| **Planner** | Pembagian gaji, rencana kebutuhan, kantong tabungan, tawaran kerja, dan simulasi sisa uang. |
| **Transaksi** | Pemasukan, pengeluaran, riwayat, dan ringkasan transaksi. |
| **Profil** | Data pengguna, foto profil, dan akses menuju **Settings**. |

---

## 🏗️ Arsitektur dan Struktur Project

FinPlan sedang beralih dari struktur berdasarkan jenis file (`screens/`, `state/`, `widgets/`) menuju struktur **berdasarkan fitur** (`features/`). Tujuannya agar layar, state, dan komponen untuk fitur yang sama berada lebih dekat satu sama lain.

### Struktur `lib/` terbaru

```text
lib/
├── main.dart                         # Entry point, inisialisasi, dan navigasi
├── core/
│   ├── constants/
│   │   └── storage_keys.dart         # Kunci penyimpanan aplikasi
│   ├── theme/
│   │   ├── app_colors.dart           # Palet warna
│   │   └── app_theme.dart            # Light/Dark Theme
│   └── money.dart                    # Utilitas nominal/Rupiah
├── data/
│   ├── plan_repository.dart          # Simpan dan baca rencana
│   ├── transaction_repository.dart   # Akses database transaksi
│   ├── savings_repository.dart       # Penyimpanan kantong tabungan
│   └── job_offer_repository.dart     # Penyimpanan tawaran pekerjaan
├── models/
│   ├── finance_plan.dart
│   ├── finance_transaction.dart
│   ├── savings_goal.dart
│   └── job_offer.dart
├── features/                          # Modul yang sudah mulai dipisah
│   ├── dashboard/
│   │   ├── presentation/
│   │   │   ├── dashboard_page.dart
│   │   │   ├── finance_shell.dart
│   │   │   └── widgets/
│   │   └── providers/
│   ├── planner/
│   │   ├── presentation/
│   │   │   ├── planner_page.dart
│   │   │   ├── planner_hub_page.dart
│   │   │   ├── allocation_page.dart
│   │   │   ├── plan_editor.dart
│   │   │   └── widgets/             # Step form dan ringkasan
│   │   └── providers/
│   └── settings/
│       ├── presentation/
│       │   ├── settings_page.dart
│       │   └── widgets/
│       └── providers/
├── screens/                            # Halaman utama dan modul lama
│   ├── welcome_slides_page.dart
│   ├── profile_page.dart
│   ├── transactions_page.dart
│   ├── savings_page.dart
│   ├── savings_detail_page.dart
│   ├── jobs_offer_page.dart
│   ├── add_job_offer_page.dart
│   ├── sisa_uang_page.dart
│   └── ...
├── state/                              # Controller dan notifier bersama
│   ├── plan_controller.dart
│   ├── finance_plan_notifier.dart
│   ├── transaction_controller.dart
│   ├── transaction_notifier.dart
│   ├── savings_controller.dart
│   ├── savings_notifier.dart
│   ├── job_offer_controller.dart
│   └── ...
└── widgets/                            # Widget lintas fitur / lama
    ├── plan_editor.dart
    ├── salary_calculator.dart
    ├── savings_overview_card.dart
    ├── monthly_expense_trend_card.dart
    └── ...
```

> **Perhatian:** struktur ini mencerminkan berkas yang tersedia pada versi pengembangan saat dokumentasi diperbarui. Folder `features/` dan `screens/` masih berjalan berdampingan; beberapa file alternatif/migrasi dapat ada hingga refaktor selesai. Periksa struktur branch yang sedang digunakan sebelum memindahkan atau menghapus file.

### Tanggung jawab folder

| Folder | Tanggung jawab |
| --- | --- |
| `core/` | Konfigurasi bersama, warna, tema, utilitas, dan konstanta. |
| `models/` | Representasi data dan aturan dasar entitas. |
| `data/` | Membaca/menulis data ke SQLite atau penyimpanan lokal. |
| `features/<nama>/presentation/` | Halaman serta widget khusus suatu fitur. |
| `features/<nama>/providers/` | Provider dan state khusus suatu fitur (Riverpod). |
| `screens/` | Halaman yang belum atau tidak dipindahkan ke modul `features/`. |
| `state/` | Controller lama dan notifier bersama selama migrasi. |
| `widgets/` | Widget reusable dan komponen yang belum dimigrasikan. |
| `test/` | Unit test dan widget/integration-style test yang dijalankan dengan `flutter test`. |

### Contoh pengujian

```text
test/
├── finance_plan_notifier_test.dart
├── plan_editor_notifier_test.dart
├── expense_budget_metrics_test.dart
├── monthly_transaction_trends_test.dart
├── savings_overview_integration_test.dart
└── transactions_dashboard_integration_test.dart
```

Nama file pengujian dapat bertambah seiring penambahan fitur.

---

## 🛠️ Teknologi

| Teknologi | Penggunaan |
| --- | --- |
| **Flutter + Dart** | Aplikasi Android dan antarmuka pengguna. |
| **Material Design 3** | Komponen UI, sistem warna, dan tema. |
| **Flutter Riverpod** | Pengelolaan state pada modul yang sedang direfaktor. |
| **ChangeNotifier** | Controller lama yang masih dipakai dalam masa transisi. |
| **SQLite (`sqflite`)** | Penyimpanan transaksi lokal. |
| **Shared Preferences** | Menyimpan preferensi dan sejumlah data lokal. |
| **`intl` dan utilitas Rupiah** | Format nominal dan tanggal. |
| **Image Picker** | Memilih foto profil. |
| **Flutter Test** | Unit test dan pengujian widget. |

> Dependensi dan versinya mengikuti `pubspec.yaml` serta `pubspec.lock` pada branch repository. Daftar ini merupakan ringkasan, bukan pengganti file konfigurasi tersebut.

---

## 🚀 Instalasi dan Menjalankan Aplikasi

### Persyaratan

- Flutter SDK, Dart SDK, dan Android SDK yang telah dikonfigurasi.
- VS Code atau Android Studio.
- Emulator atau perangkat Android untuk menjalankan aplikasi.

### Langkah-langkah

```bash
git clone https://github.com/Kuuhaku456/FinPlan.git
cd FinPlan
flutter pub get
flutter doctor
flutter run
```

### Pemeriksaan dan pengujian

```bash
flutter analyze
flutter test
```

Menjalankan salah satu berkas tes:

```bash
flutter test test/finance_plan_notifier_test.dart
```

### Build APK untuk pengujian perangkat

```bash
flutter build apk --release
```

Jika berhasil, APK biasanya tersedia di:

```text
build/app/outputs/flutter-apk/app-release.apk
```

**Catatan rilis:** APK yang dibuat untuk uji coba **belum otomatis siap dipublikasikan di Google Play**. Periksa `applicationId`, versi aplikasi, ikon, kebijakan privasi, serta **release signing** (jangan gunakan debug key untuk distribusi publik).

### Troubleshooting Android build

- Bila muncul pesan bahwa plugin membutuhkan **Android API 36**, pastikan SDK 36 tersedia dan cek `compileSdk` pada `android/app/build.gradle.kts`. Menaikkan `compileSdk` tidak otomatis mewajibkan perubahan `minSdk` atau `targetSdk`.
- Jika `file_picker` atau plugin lain gagal diselesaikan oleh `flutter pub get`, periksa versi yang benar-benar tersedia dan kompatibel di `pubspec.yaml`; jangan menuliskan nomor versi yang tidak ditemukan oleh package resolver.
- Peringatan Java/Gradle tentang *restricted native access* tidak selalu menjadi penyebab build gagal. Fokus pada blok `FAILURE: Build failed` dan pesan tugas yang benar-benar gagal.
- Jika muncul error UI berupa kotak abu-abu/merah ketika panel **Tawaran Baru** dibuka, catat stack trace dari `flutter run` dan lakukan pengujian langsung di perangkat. Kesalahan UI tersebut berbeda dari kegagalan kompilasi APK.

---

## 🔐 Penyimpanan Data dan Privasi

FinPlan menggunakan pendekatan **local-first**:

- Transaksi disimpan dalam database SQLite pada perangkat.
- Rencana, preferensi, kantong tabungan, dan tawaran kerja menggunakan penyimpanan lokal sesuai repository masing-masing.
- Data **belum disinkronkan otomatis** antarperangkat melalui akun cloud.
- FinPlan bukan aplikasi perbankan dan tidak melakukan transaksi uang atas nama pengguna.

Jangan memasukkan PIN, password, atau informasi rahasia ke dalam kolom catatan. Selalu lakukan pencadangan perangkat sebelum reinstall, reset, atau pindah ponsel. Fitur ekspor/impor atau backup otomatis tidak diasumsikan tersedia sampai implementasinya diverifikasi.

---

## 🧭 Roadmap

- [x] Dashboard dan pembagian anggaran.
- [x] Planner dengan kebutuhan harian dan kategori fleksibel.
- [x] Pencatatan pemasukan dan pengeluaran.
- [x] Kantong tabungan dengan riwayat dan arsip.
- [x] Simulasi serta penyimpanan tawaran kerja.
- [x] Tema terang, gelap, mengikuti sistem, dan skala teks.
- [x] Mulai modularisasi `features/` dan penggunaan Riverpod.
- [x] Menambahkan pengujian logika perencanaan dan ringkasan keuangan.
- [ ] Menyelesaikan migrasi `screens/` dan `state/` lama secara bertahap.
- [ ] Memastikan seluruh panel input **Tawaran Baru** berjalan normal pada perangkat Android.
- [ ] Meningkatkan cakupan widget test, integrasi, serta uji lintas perangkat.
- [ ] Memverifikasi alur pencadangan/ekspor data pengguna.
- [ ] Menyiapkan `applicationId`, keystore release, dan berkas publikasi Play Store.

Checklist menunjukkan progres pengembangan, **bukan jaminan seluruh skenario bebas bug**.

---

## 🤝 Kontribusi dan Masukan

Laporkan bug, ide fitur, atau saran melalui [GitHub Issues](https://github.com/Kuuhaku456/FinPlan/issues). Sertakan langkah reproduksi, versi Flutter, perangkat, dan log error bila memungkinkan.

## 👨‍💻 Pengembang

Dikembangkan oleh **[Filipus Adriel Manik (@Kuuhaku456)](https://github.com/Kuuhaku456)**.

**FinPlan — Plan smarter. Spend wisely. Save with purpose.** 💚

---

<sub>**Lisensi:** repository belum dinyatakan memiliki lisensi open-source. Hubungi pemilik repository untuk izin penggunaan ulang atau redistribusi kode.</sub>
