import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/job_offer.dart';

import '../../../screens/add_job_offer_page.dart';
import '../../../screens/add_savings_goal_page.dart';
import '../../../screens/jobs_offer_page.dart';
import '../../../screens/profile_page.dart';
import '../../../screens/savings_detail_page.dart';
import '../../../screens/savings_page.dart';
import '../../../screens/sisa_uang_page.dart';
import '../../../screens/transactions_page.dart';

import '../../../state/finance_plan_notifier.dart';
import '../../../state/job_offer_controller.dart';
import '../../../state/plan_controller.dart';
import '../../../state/savings_controller.dart';
import '../../../state/savings_notifier.dart';
import '../../../state/transaction_controller.dart';
import '../../../state/transaction_notifier.dart';

import '../../../widgets/salary_calculator.dart';

import '../../planner/presentation/planner_page.dart';
import '../../planner/presentation/planner_hub_page.dart';

import '../../settings/presentation/settings_page.dart';
import '../../settings/providers/app_settings_provider.dart';

import '../providers/finance_shell_provider.dart';

import 'dashboard_page.dart';

// ============================================================
// FINANCE SHELL
// ============================================================

class FinanceShell extends ConsumerStatefulWidget {
  const FinanceShell({
    super.key,
    required this.planController,
    required this.transactionController,
    required this.savingsController,
    required this.jobOfferController,
  });

  final PlanController planController;
  final TransactionController transactionController;
  final SavingsController savingsController;
  final JobOfferController jobOfferController;

  @override
  ConsumerState<FinanceShell> createState() {
    return _FinanceShellState();
  }
}

// ============================================================
// FINANCE SHELL STATE
// ============================================================

class _FinanceShellState extends ConsumerState<FinanceShell> {
  // ==========================================================
  // INITIALIZATION
  // ==========================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(_loadExtras());
    });
  }

  Future<void> _loadExtras() async {
    // Mengaktifkan sinkronisasi transaksi ke Riverpod.
    ref.read(transactionStateProvider);

    // Memuat Kantong Tabungan.
    try {
      await ref
          .read(savingsStateProvider.notifier)
          .loadGoals();
    } catch (_) {
      // Gagal memuat tabungan tidak menghentikan aplikasi.
    }

    if (!mounted) return;

    // Memuat data tawaran kerja.
    try {
      await widget.jobOfferController.initialize();
    } catch (_) {
      // Planner tetap dapat digunakan.
    }
  }

  // ==========================================================
  // LIGHT / DARK MODE
  // ==========================================================

  Future<void> _toggleTheme() async {
    if (ref.read(financeShellUiProvider).isChangingTheme) {
      return;
    }

    ref
        .read(financeShellUiProvider.notifier)
        .setChangingTheme(true);

    try {
      await ref
          .read(appSettingsProvider.notifier)
          .toggleTheme(
            Theme.of(context).brightness,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal mengganti tema aplikasi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        ref
            .read(financeShellUiProvider.notifier)
            .setChangingTheme(false);
      }
    }
  }

  // ==========================================================
  // PROFILE
  // ==========================================================

  Future<void> _openProfile() async {
    final store = ref.read(
      finPlanProfileStoreProvider,
    );

    FinPlanProfile profile;

    try {
      profile = await ref.read(
        finPlanProfileProvider.future,
      );
    } catch (_) {
      profile = const FinPlanProfile();
    }

    if (!mounted) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) {
          return FinPlanProfilePage(
            initialProfile: profile,
            onSave: store.save,
          );
        },
      ),
    );

    if (changed == true && mounted) {
      ref.invalidate(finPlanProfileProvider);
    }
  }

  // ==========================================================
  // SETTINGS
  // ==========================================================

  Future<void> _openSettings() async {
    final textScale = ref.read(
      appSettingsProvider,
    ).fontScale;

    final onTextScaleChanged = ref
        .read(appSettingsProvider.notifier)
        .setFontScale;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Pengaturan'),
            ),
            body: SafeArea(
              child: SettingsPage(
                controller: widget.planController,
                textScale: textScale,
                onTextScaleChanged: onTextScaleChanged,
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // TAMBAH / EDIT KANTONG TABUNGAN
  // ==========================================================

  Future<void> _openSavingsForm({
    String? goalId,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) {
          return AddSavingsGoalPage(
            controller: widget.savingsController,
            goalId: goalId,
          );
        },
      ),
    );
  }

  // ==========================================================
  // DETAIL KANTONG TABUNGAN
  // ==========================================================

  Future<void> _openSavingsDetail(
    String goalId,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) {
          return SavingsDetailPage(
            controller: widget.savingsController,
            goalId: goalId,
            onEditGoal: (id) {
              unawaited(
                _openSavingsForm(goalId: id),
              );
            },
          );
        },
      ),
    );
  }

  // ==========================================================
  // HALAMAN KANTONG TABUNGAN
  // ==========================================================

  Future<void> _openSavingsPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return SavingsPage(
            controller: widget.savingsController,
            onCreateGoal: () {
              unawaited(
                _openSavingsForm(),
              );
            },
            onOpenGoal: (goalId) {
              unawaited(
                _openSavingsDetail(goalId),
              );
            },
          );
        },
      ),
    );
  }

  // ==========================================================
  // BUDGET PLANNER
  // ==========================================================

  Future<void> _openBudgetPlanner() async {
    final initialPlan = ref.read(
      financePlanProvider,
    );

    if (initialPlan == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Rencana keuangan belum tersedia. '
            'Silakan isi data terlebih dahulu.',
          ),
        ),
      );

      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Rencana & Anggaran',
              ),
            ),
            body: SafeArea(
              child: Consumer(
                builder: (context, ref, _) {
                  final current =
                      ref.watch(financePlanProvider) ??
                          initialPlan;

                  return PlannerPage(
                    plan: current,
                    onSave: ref
                        .read(financePlanProvider.notifier)
                        .savePlan,
                    jobOfferController:
                        widget.jobOfferController,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // KALKULATOR GAJI
  // ==========================================================

  Future<void> _openSalaryCalculator() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Kalkulator Gaji',
              ),
            ),
            body: SafeArea(
              child: Consumer(
                builder: (context, ref, _) {
                  final salary = ref
                          .watch(financePlanProvider)
                          ?.totalMonthlyIncome ??
                      0;

                  return SalaryCalculatorSection(
                    initialMonthlySalary: salary,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // SIMULASI SISA UANG
  // ==========================================================

  Future<void> _openSisaUangSimulator() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return const SisaUangPage();
        },
      ),
    );
  }

  // ==========================================================
  // TAMBAH / EDIT TAWARAN KERJA
  // ==========================================================

  Future<void> _openJobOfferForm({
    JobOffer? offer,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) {
          return AddJobOfferPage(
            controller: widget.jobOfferController,
            initialOffer: offer,
          );
        },
      ),
    );
  }

  // ==========================================================
  // HALAMAN TAWARAN KERJA
  // ==========================================================

  Future<void> _openJobOffers() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Tawaran Kerja',
              ),
            ),
            body: SafeArea(
              child: JobOffersPage(
                controller: widget.jobOfferController,
                onAdd: () {
                  unawaited(
                    _openJobOfferForm(),
                  );
                },
                onEdit: (offer) {
                  unawaited(
                    _openJobOfferForm(
                      offer: offer,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // BUILD FINANCE SHELL
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(
      financePlanProvider,
    );

    final shell = ref.watch(
      financeShellUiProvider,
    );

    final fontScale = ref.watch(
      appSettingsProvider,
    ).fontScale;

    final profile = ref.watch(
      finPlanProfileProvider,
    ).when(
      data: (value) => value,
      loading: () => const FinPlanProfile(),
      error: (_, __) => const FinPlanProfile(),
    );

    // ========================================================
    // LOADING FINANCE PLAN
    // ========================================================

    if (plan == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    // ========================================================
    // DAFTAR HALAMAN UTAMA
    // ========================================================

    final pages = <Widget>[
      // ======================================================
      // TAB 1: HOME
      // ======================================================

      DashboardPage(
        plan: plan,
        onOpenPlanner: () {
          ref
              .read(financeShellUiProvider.notifier)
              .selectTab(1);
        },
      ),

      // ======================================================
      // TAB 2: PLANNER
      // ======================================================

      PlannerHubPage(
        plan: plan,
        onOpenBudget: () {
          unawaited(_openBudgetPlanner());
        },
        onOpenSalary: () {
          unawaited(_openSalaryCalculator());
        },
        onOpenJobs: () {
          unawaited(_openJobOffers());
        },
        onOpenSavings: () {
          unawaited(_openSavingsPage());
        },
        onOpenSisaUang: () {
          unawaited(_openSisaUangSimulator());
        },
      ),

      // ======================================================
      // TAB 3: TRANSAKSI
      // ======================================================

      TransactionsPage(
        controller: widget.transactionController,
      ),

      // ======================================================
      // TAB 4: PROFIL
      // ======================================================

      FinPlanProfileTab(
        profile: profile,
        onEditProfile: () {
          unawaited(_openProfile());
        },
        onOpenSettings: () {
          unawaited(_openSettings());
        },
      ),
    ];

    // ========================================================
    // SCAFFOLD
    // ========================================================

    return Scaffold(
      // ======================================================
      // APP BAR
      // ======================================================

      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: scheme.onPrimaryContainer,
                size: 22,
              ),
            ),

            const SizedBox(width: 10),

            const Text(
              'FinPlan',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: isDark
                ? 'Light Mode'
                : 'Dark Mode',
            onPressed: shell.isChangingTheme
                ? null
                : _toggleTheme,
            icon: Icon(
              isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),

      // ======================================================
      // BODY
      // ======================================================

      body: SafeArea(
        child: IndexedStack(
          index: shell.selectedIndex,
          children: pages,
        ),
      ),

      // ======================================================
      // BOTTOM NAVIGATION
      // ======================================================

      bottomNavigationBar: NavigationBar(
        height: (72 * fontScale)
            .clamp(72.0, 110.0)
            .toDouble(),

        selectedIndex: shell.selectedIndex,

        indicatorColor: scheme.primaryContainer,

        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,

        onDestinationSelected: ref
            .read(financeShellUiProvider.notifier)
            .selectTab,

        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon: Icon(
              Icons.home_rounded,
            ),
            label: 'Home',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.grid_view_outlined,
            ),
            selectedIcon: Icon(
              Icons.grid_view_rounded,
            ),
            label: 'Planner',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.receipt_long_outlined,
            ),
            selectedIcon: Icon(
              Icons.receipt_long_rounded,
            ),
            label: 'Transaksi',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.person_outline_rounded,
            ),
            selectedIcon: Icon(
              Icons.person_rounded,
            ),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}