import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/data/savings_repository.dart';
import '../lib/features/dashboard/providers/finance_shell_provider.dart';
import '../lib/features/planner/presentation/planner_hub_page.dart';
import '../lib/models/finance_plan.dart';
import '../lib/models/savings_goal.dart';
import '../lib/screens/profile_page.dart';
import '../lib/state/savings_controller.dart';
import '../lib/state/savings_notifier.dart';

// ======================================================
// FINPLAN - NAVIGATION WIDGET TEST
// VERSI REVISI
// ======================================================
//
// Pengujian:
// 1. Navigasi menu pertama Planner (Anggaran).
// 2. Navigasi Kantong Tabungan.
// 3. Navigasi Simulasi Sisa Uang.
// 4. Navigasi Profil dan Settings.
// 5. Perpindahan state empat tab.
// 6. Validasi index navigasi.
//
// Menggunakan repository sementara.
// Tidak mengubah data pengguna.
// ======================================================

// ======================================================
// 1. MOCK SAVINGS REPOSITORY
// ======================================================

class _EmptySavingsRepository extends SavingsRepository {
  @override
  Future<List<SavingsGoal>> getAllGoals({
    bool includeArchived = true,
  }) async {
    return <SavingsGoal>[];
  }
}

// ======================================================
// 2. HELPER MEMBUKA PLANNER
// ======================================================

Future<void> _pumpPlanner(
  WidgetTester tester, {
  required VoidCallback onOpenBudget,
  required VoidCallback onOpenSavings,
  required VoidCallback onOpenSisaUang,
}) async {
  final savingsController = SavingsController(
    _EmptySavingsRepository(),
  );

  addTearDown(savingsController.dispose);

  await savingsController.loadGoals();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        legacySavingsControllerProvider.overrideWithValue(
          savingsController,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF064E3B),
        ),
        home: Scaffold(
          body: SafeArea(
            child: PlannerHubPage(
              plan: FinancePlan.defaults(),
              onOpenBudget: onOpenBudget,
              onOpenSalary: () {},
              onOpenJobs: () {},
              onOpenSavings: onOpenSavings,
              onOpenSisaUang: onOpenSisaUang,
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

// ======================================================
// 3. MAIN TEST
// ======================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ====================================================
  // TEST 1: MENU ANGGARAN
  // ====================================================

  testWidgets(
    'Menu pertama Planner membuka fitur Anggaran',
    (tester) async {
      var opened = 0;

      await _pumpPlanner(
        tester,
        onOpenBudget: () {
          opened++;
        },
        onOpenSavings: () {},
        onOpenSisaUang: () {},
      );

      // Pastikan halaman Planner tampil.
      expect(
        find.text('Atur Keuanganmu'),
        findsOneWidget,
      );

      // Cari GridView menu Planner.
      //
      // Tidak mencari teks "Anggaran" secara langsung,
      // karena label dapat berubah.
      final menuGrid = find.byType(GridView);

      // Scroll sampai grid menu ditemukan.
      await tester.scrollUntilVisible(
        menuGrid,
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );

      await tester.pumpAndSettle();

      expect(
        menuGrid,
        findsOneWidget,
      );

      // Cari tombol menu pertama dalam grid.
      //
      // Berdasarkan struktur PlannerHubPage,
      // menu pertama menggunakan callback onOpenBudget.
      final firstMenuButton = find.descendant(
        of: menuGrid,
        matching: find.byType(InkWell),
      ).first;

      await tester.ensureVisible(firstMenuButton);

      await tester.pumpAndSettle();

      // Tekan tombol menu pertama.
      await tester.tap(firstMenuButton);

      await tester.pump();

      // Pastikan callback Anggaran terpanggil.
      expect(opened, 1);
    },
  );

  // ====================================================
  // TEST 2: KANTONG TABUNGAN
  // ====================================================

  testWidgets(
    'Tombol Kantong Tabungan memanggil halaman tabungan',
    (tester) async {
      var opened = 0;

      await _pumpPlanner(
        tester,
        onOpenBudget: () {},
        onOpenSavings: () {
          opened++;
        },
        onOpenSisaUang: () {},
      );

      final savingsButton = find.text(
        'Buka Kantong Tabungan',
      );

      await tester.ensureVisible(savingsButton);

      await tester.pumpAndSettle();

      await tester.tap(savingsButton);

      await tester.pump();

      expect(opened, 1);
    },
  );

  // ====================================================
  // TEST 3: SIMULASI SISA UANG
  // ====================================================

  testWidgets(
    'Tombol Uang Sampai Gajian membuka simulator',
    (tester) async {
      var opened = 0;

      await _pumpPlanner(
        tester,
        onOpenBudget: () {},
        onOpenSavings: () {},
        onOpenSisaUang: () {
          opened++;
        },
      );

      final simulatorButton = find.text(
        'Uang Sampai Gajian',
      );

      await tester.ensureVisible(simulatorButton);

      await tester.pumpAndSettle();

      await tester.tap(simulatorButton);

      await tester.pump();

      expect(opened, 1);
    },
  );

  // ====================================================
  // TEST 4: PROFIL DAN SETTINGS
  // ====================================================

  testWidgets(
    'Halaman Profil dapat membuka edit profil dan pengaturan',
    (tester) async {
      var editOpened = 0;
      var settingsOpened = 0;

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF064E3B),
          ),
          home: Scaffold(
            body: SafeArea(
              child: FinPlanProfileTab(
                profile: const FinPlanProfile(
                  name: 'Filipus',
                  occupation: 'IT Coach',
                ),
                onEditProfile: () {
                  editOpened++;
                },
                onOpenSettings: () {
                  settingsOpened++;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pastikan profil tampil.
      expect(
        find.text('Profil'),
        findsOneWidget,
      );

      expect(
        find.text('Filipus'),
        findsOneWidget,
      );

      // Buka Settings.
      final settingsButton = find.text(
        'Pengaturan',
      );

      await tester.ensureVisible(settingsButton);

      await tester.tap(settingsButton);

      expect(settingsOpened, 1);

      // Buka Edit Profil.
      final editButton = find.byTooltip(
        'Edit profil',
      );

      await tester.tap(editButton);

      expect(editOpened, 1);
    },
  );

  // ====================================================
  // TEST 5: NAVIGASI EMPAT TAB
  // ====================================================

  test(
    'Navigasi mendukung empat tab utama FinPlan',
    () {
      final container = ProviderContainer();

      addTearDown(container.dispose);

      final notifier = container.read(
        financeShellUiProvider.notifier,
      );

      // Home.
      expect(
        container.read(financeShellUiProvider).selectedIndex,
        0,
      );

      // Planner.
      notifier.selectTab(1);

      expect(
        container.read(financeShellUiProvider).selectedIndex,
        1,
      );

      // Transaksi.
      notifier.selectTab(2);

      expect(
        container.read(financeShellUiProvider).selectedIndex,
        2,
      );

      // Profil.
      notifier.selectTab(3);

      expect(
        container.read(financeShellUiProvider).selectedIndex,
        3,
      );

      // Kembali ke Home.
      notifier.selectTab(0);

      expect(
        container.read(financeShellUiProvider).selectedIndex,
        0,
      );
    },
  );

  // ====================================================
  // TEST 6: VALIDASI INDEX
  // ====================================================

  test(
    'Index navigasi tidak valid tidak mengubah tab',
    () {
      final container = ProviderContainer();

      addTearDown(container.dispose);

      final notifier = container.read(
        financeShellUiProvider.notifier,
      );

      // Pilih tab Transaksi.
      notifier.selectTab(2);

      expect(
        container.read(financeShellUiProvider).selectedIndex,
        2,
      );

      // Index negatif.
      notifier.selectTab(-1);

      expect(
        container.read(financeShellUiProvider).selectedIndex,
        2,
      );

      // Index lebih besar dari jumlah tab.
      notifier.selectTab(4);

      expect(
        container.read(financeShellUiProvider).selectedIndex,
        2,
      );

      // Index yang sama.
      notifier.selectTab(2);

      expect(
        container.read(financeShellUiProvider).selectedIndex,
        2,
      );
    },
  );
}