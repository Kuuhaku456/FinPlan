
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/money.dart';
import '../lib/data/savings_repository.dart';
import '../lib/features/planner/presentation/planner_hub_page.dart';
import '../lib/models/finance_plan.dart';
import '../lib/models/savings_goal.dart';
import '../lib/state/savings_controller.dart';
import '../lib/state/savings_notifier.dart';
import '../lib/widgets/savings_overview_card.dart';

// Repository sementara khusus pengujian.
// Tidak menggunakan data tabungan asli atau plugin perangkat.
class _MemorySavingsRepository extends SavingsRepository {
  _MemorySavingsRepository([List<SavingsGoal> initialGoals = const []])
      : _goals = {
          for (final goal in initialGoals) goal.id: goal,
        };

  final Map<String, SavingsGoal> _goals;

  @override
  Future<List<SavingsGoal>> getAllGoals({
    bool includeArchived = true,
  }) async {
    return _goals.values
        .where((goal) => includeArchived || !goal.isArchived)
        .toList();
  }

  @override
  Future<SavingsGoal> createGoal(SavingsGoal goal) async {
    if (_goals.containsKey(goal.id)) {
      throw StateError('Kantong sudah ada.');
    }

    _goals[goal.id] = goal;
    return goal;
  }

  @override
  Future<SavingsGoal> addSavings(
    String goalId,
    int amount, {
    String note = '',
    DateTime? date,
  }) async {
    final current = _goals[goalId];

    if (current == null) {
      throw StateError('Kantong tidak ditemukan.');
    }

    final updated = current.addSavings(
      amount,
      note: note,
      date: date,
    );

    _goals[goalId] = updated;
    return updated;
  }

  @override
  Future<SavingsGoal> archiveGoal(String goalId) async {
    final current = _goals[goalId];

    if (current == null) {
      throw StateError('Kantong tidak ditemukan.');
    }

    final updated = current.archive();
    _goals[goalId] = updated;

    return updated;
  }

  @override
  Future<SavingsGoal> restoreGoal(String goalId) async {
    final current = _goals[goalId];

    if (current == null) {
      throw StateError('Kantong tidak ditemukan.');
    }

    final updated = current.restore();
    _goals[goalId] = updated;

    return updated;
  }
}

// Helper untuk menampilkan kartu tabungan saat pengujian.
Future<void> _pumpSavingsCard(
  WidgetTester tester,
  SavingsController controller, {
  required VoidCallback onOpenSavings,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        legacySavingsControllerProvider.overrideWithValue(controller),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.green,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SavingsOverviewCard(
              onOpenSavings: onOpenSavings,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // ==========================================================
  // TEST 1: KONDISI TABUNGAN KOSONG
  // ==========================================================

  testWidgets(
    'Kantong kosong bisa dimuat dan tombol buka berfungsi',
    (tester) async {
      final controller = SavingsController(
        _MemorySavingsRepository(),
      );

      addTearDown(controller.dispose);

      var opened = 0;

      await _pumpSavingsCard(
        tester,
        controller,
        onOpenSavings: () => opened++,
      );

      expect(
        find.text('Data tabungan belum dimuat.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Muat Tabungan'));
      await tester.pumpAndSettle();

      expect(
        find.text('Belum ada kantong tabungan aktif.'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('Buka Kantong Tabungan'),
      );

      expect(opened, 1);
    },
  );

  // ==========================================================
  // TEST 2: SETORAN DAN UPDATE PROGRESS
  // ==========================================================

  testWidgets(
    'Setoran memperbarui saldo, progress, dan daftar kantong',
    (tester) async {
      final goal = SavingsGoal(
        id: 'dana-darurat',
        name: 'Dana Darurat',
        emoji: '🛟',
        targetAmount: 1000000,
        savedAmount: 250000,
      );

      final controller = SavingsController(
        _MemorySavingsRepository([goal]),
      );

      addTearDown(controller.dispose);

      await controller.loadGoals();

      await _pumpSavingsCard(
        tester,
        controller,
        onOpenSavings: () {},
      );

      expect(
        find.text(rupiah(250000)),
        findsOneWidget,
      );

      expect(
        find.text('Dari target ${rupiah(1000000)}'),
        findsOneWidget,
      );

      expect(find.text('25.0%'), findsOneWidget);

      expect(
        find.text('🛟 Dana Darurat'),
        findsOneWidget,
      );

      // Tambahkan setoran Rp150.000.
      await controller.addSavings(
        goal.id,
        150000,
        note: 'Setoran tambahan',
      );

      await tester.pumpAndSettle();

      // Saldo menjadi Rp400.000 dari Rp1.000.000.
      expect(
        find.text(rupiah(400000)),
        findsOneWidget,
      );

      expect(find.text('40.0%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
    },
  );

  // ==========================================================
  // TEST 3: ARSIP DAN RESTORE
  // ==========================================================

  testWidgets(
    'Arsip menghapus kantong dari ringkasan lalu bisa dipulihkan',
    (tester) async {
      final goal = SavingsGoal(
        id: 'nikah',
        name: 'Dana Pernikahan',
        targetAmount: 5000000,
        savedAmount: 1000000,
      );

      final controller = SavingsController(
        _MemorySavingsRepository([goal]),
      );

      addTearDown(controller.dispose);

      await controller.loadGoals();

      await _pumpSavingsCard(
        tester,
        controller,
        onOpenSavings: () {},
      );

      expect(
        find.text('🎯 Dana Pernikahan'),
        findsOneWidget,
      );

      // Arsipkan.
      await controller.archiveGoal(goal.id);
      await tester.pumpAndSettle();

      expect(
        find.text('Belum ada kantong tabungan aktif.'),
        findsOneWidget,
      );

      expect(
        find.text('🎯 Dana Pernikahan'),
        findsNothing,
      );

      // Pulihkan kembali.
      await controller.restoreGoal(goal.id);
      await tester.pumpAndSettle();

      expect(
        find.text('🎯 Dana Pernikahan'),
        findsOneWidget,
      );

      expect(
        find.text(rupiah(1000000)),
        findsOneWidget,
      );
    },
  );

  // ==========================================================
  // TEST 4: INTEGRASI HALAMAN PLANNER
  // ==========================================================

  testWidgets(
    'Planner menampilkan ringkasan dan membuka menu tabungan',
    (tester) async {
      final controller = SavingsController(
        _MemorySavingsRepository(),
      );

      addTearDown(controller.dispose);

      await controller.loadGoals();

      final plan = FinancePlan.defaults();

      var opened = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            legacySavingsControllerProvider.overrideWithValue(
              controller,
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: PlannerHubPage(
                plan: plan,
                onOpenBudget: () {},
                onOpenSalary: () {},
                onOpenJobs: () {},
                onOpenSavings: () => opened++,
                onOpenSisaUang: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        find.text('Atur Keuanganmu'),
        findsOneWidget,
      );

      expect(
        find.text(rupiah(plan.totalMonthlyIncome)),
        findsOneWidget,
      );

      expect(
        find.byType(SavingsOverviewCard),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.text('Lihat Semua'),
      );

      await tester.tap(
        find.text('Lihat Semua'),
      );

      expect(opened, 1);
    },
  );
}
