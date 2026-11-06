import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/money.dart';

import 'data/job_offer_repository.dart';
import 'data/plan_repository.dart';
import 'data/savings_repository.dart';
import 'data/transaction_repository.dart';

import 'models/finance_plan.dart';
import 'models/job_offer.dart';

import 'screens/add_job_offer_page.dart';
import 'screens/add_savings_goal_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/jobs_offer_page.dart';
import 'screens/planner_page.dart';
import 'screens/profile_page.dart';
import 'screens/savings_detail_page.dart';
import 'screens/savings_page.dart';
import 'screens/settings_page.dart';
import 'screens/sisa_uang_page.dart';
import 'screens/transactions_page.dart';
import 'screens/welcome_slides_page.dart';

import 'state/app_settings_controller.dart';
import 'state/finance_plan_notifier.dart';
import 'state/job_offer_controller.dart';
import 'state/plan_controller.dart';
import 'state/savings_controller.dart';
import 'state/savings_notifier.dart';
import 'state/transaction_controller.dart';
import 'state/transaction_notifier.dart';

import 'widgets/plan_editor.dart';
import 'widgets/salary_calculator.dart';

// =====================================================
// FINPLAN CONFIGURATION
// =====================================================

const String kIntroSeenKey = 'finplan.intro_seen.v1';

// =====================================================
// MAIN
// =====================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = SharedPreferencesAsync();

  // ===================================================
  // INITIALIZE PLAN REPOSITORY
  // ===================================================

  final planRepository = PlanRepository();

  final savedPlan = await planRepository.loadPlan();

  // ===================================================
  // LOAD THEME PREFERENCE
  // ===================================================

  ThemeMode themePreference = ThemeMode.system;

  try {
    final savedTheme = await planRepository.loadThemePreference();

    themePreference = switch (savedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  } catch (_) {
    themePreference = ThemeMode.system;
  }

  // ===================================================
  // LOAD INTRO PREFERENCE
  // ===================================================

  bool introSeen = false;

  try {
    introSeen = await preferences.getBool(kIntroSeenKey) ?? false;
  } catch (_) {
    introSeen = false;
  }

  // ===================================================
  // LOAD FONT SCALE
  // ===================================================

  double fontScale = 1.0;

  try {
    final savedScale = await preferences.getDouble(kFontScaleKey);

    if (savedScale != null && savedScale.isFinite) {
      fontScale = savedScale.clamp(1.0, 1.5).toDouble();
    }
  } catch (_) {
    fontScale = 1.0;
  }

  // ===================================================
  // INITIALIZE LEGACY CONTROLLERS
  // ===================================================

  final planController = PlanController(
    planRepository,
    savedPlan,
    themePreference,
  );

  final transactionController = TransactionController(
    TransactionRepository(),
  );

  final savingsController = SavingsController(
    SavingsRepository(
      preferences: preferences,
    ),
  );

  final jobOfferController = JobOfferController(
    JobOfferRepository(
      preferences: preferences,
    ),
  );

  // ===================================================
  // INITIALIZE RIVERPOD
  // ===================================================

  runApp(
    ProviderScope(
      overrides: [
        // App Settings
        initialAppSettingsProvider.overrideWithValue(
          AppSettingsState(
            themeMode: themePreference,
            fontScale: fontScale,
          ),
        ),

        // Settings bridge
        settingsPlanControllerProvider.overrideWithValue(
          planController,
        ),

        settingsPreferencesProvider.overrideWithValue(
          preferences,
        ),

        // Financial Planner bridge
        legacyPlanControllerProvider.overrideWithValue(
          planController,
        ),

        // Transactions bridge
        legacyTransactionControllerProvider.overrideWithValue(
          transactionController,
        ),

        // Savings bridge
        legacySavingsControllerProvider.overrideWithValue(
          savingsController,
        ),
      ],
      child: FinPlanApp(
        planController: planController,
        transactionController: transactionController,
        savingsController: savingsController,
        jobOfferController: jobOfferController,
        preferences: preferences,
        introSeen: introSeen,
      ),
    ),
  );
}

// =====================================================
// FINPLAN APP
// =====================================================

class FinPlanApp extends ConsumerStatefulWidget {
  const FinPlanApp({
    super.key,
    required this.planController,
    required this.transactionController,
    required this.savingsController,
    required this.jobOfferController,
    required this.preferences,
    required this.introSeen,
  });

  final PlanController planController;
  final TransactionController transactionController;
  final SavingsController savingsController;
  final JobOfferController jobOfferController;

  final SharedPreferencesAsync preferences;
  final bool introSeen;

  @override
  ConsumerState<FinPlanApp> createState() => _FinPlanAppState();
}

class _FinPlanAppState extends ConsumerState<FinPlanApp> {
  late bool _introSeen = widget.introSeen;

  // ===================================================
  // FINISH INTRO
  // ===================================================

  Future<void> _finishIntro() async {
    if (!_introSeen && mounted) {
      setState(() {
        _introSeen = true;
      });
    }

    try {
      await widget.preferences.setBool(
        kIntroSeenKey,
        true,
      );
    } catch (_) {
      // Intro tetap bisa dilewati.
    }
  }

  // ===================================================
  // FINPLAN THEME
  // ===================================================

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF059669),
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,

      scaffoldBackgroundColor:
          isDark ? scheme.surface : const Color(0xFFF5FAF7),

      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? scheme.surface : const Color(0xFFF5FAF7),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHigh
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark
            ? scheme.surfaceContainerLow
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ===================================================
  // INITIAL SCREEN
  // ===================================================

  Widget _home(FinancePlan? currentPlan) {
    final settings = ref.read(appSettingsProvider);

    if (!_introSeen) {
      return WelcomeSlidesPage(
        onContinue: () => unawaited(_finishIntro()),
      );
    }

    if (currentPlan == null) {
      return const OnboardingPage();
    }

    return FinanceShell(
      planController: widget.planController,
      transactionController: widget.transactionController,
      savingsController: widget.savingsController,
      jobOfferController: widget.jobOfferController,
      preferences: widget.preferences,
      fontScale: settings.fontScale,
      onFontScaleChanged: (value) {
        ref.read(appSettingsProvider.notifier).setFontScale(value);
      },
    );
  }

  // ===================================================
  // BUILD APP
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      title: 'FinPlan',
      debugShowCheckedModeBanner: false,

      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: settings.themeMode,

      builder: (context, child) {
        final media = MediaQuery.of(context);

        final deviceScale = media.textScaler.scale(16) / 16;

        final effectiveScale =
            (deviceScale * settings.fontScale)
                .clamp(1.0, 2.0)
                .toDouble();

        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(effectiveScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: Consumer(
        builder: (context, ref, _) {
          final plan = ref.watch(financePlanProvider);

          return _home(plan);
        },
      ),
    );
  }

  // ===================================================
  // DISPOSE
  // ===================================================

  @override
  void dispose() {
    unawaited(widget.transactionController.closeDatabase());

    widget.jobOfferController.dispose();
    widget.savingsController.dispose();
    widget.transactionController.dispose();
    widget.planController.dispose();

    super.dispose();
  }
}

// =====================================================
// ONBOARDING PAGE
// =====================================================

class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appSettingsProvider).themeMode;

    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) ==
                Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mulai dengan FinPlan'),
        actions: [
          IconButton(
            tooltip: isDark
                ? 'Aktifkan light mode'
                : 'Aktifkan dark mode',
            onPressed: () async {
              try {
                await ref
                    .read(appSettingsProvider.notifier)
                    .toggleTheme(
                      Theme.of(context).brightness,
                    );
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gagal mengubah tampilan.'),
                    ),
                  );
                }
              }
            },
            icon: Icon(
              isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: PlanEditor(
          initial: FinancePlan.defaults(),
          onboarding: true,
          onSave: ref.read(financePlanProvider.notifier).savePlan,
        ),
      ),
    );
  }
}

// =====================================================
// FINANCE SHELL
// =====================================================

class FinanceShell extends ConsumerStatefulWidget {
  const FinanceShell({
    super.key,
    required this.planController,
    required this.transactionController,
    required this.savingsController,
    required this.jobOfferController,
    required this.preferences,
    required this.fontScale,
    required this.onFontScaleChanged,
  });

  final PlanController planController;
  final TransactionController transactionController;
  final SavingsController savingsController;
  final JobOfferController jobOfferController;

  final SharedPreferencesAsync preferences;

  final double fontScale;

  final ValueChanged<double> onFontScaleChanged;

  @override
  ConsumerState<FinanceShell> createState() =>
      _FinanceShellState();
}

class _FinanceShellState extends ConsumerState<FinanceShell> {
  int _selectedIndex = 0;

  bool _changingTheme = false;

  FinPlanProfile _profile = const FinPlanProfile();

  late final ProfileStore _profileStore = ProfileStore(
    widget.preferences,
  );

  // ===================================================
  // INITIALIZATION
  // ===================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(_loadProfile());
      unawaited(_loadExtras());
    });
  }

  // ===================================================
  // INITIALIZE FEATURE DATA
  // ===================================================

  Future<void> _loadExtras() async {
    // Mengaktifkan sinkronisasi transaksi melalui Riverpod.
    ref.read(transactionStateProvider);

    // Memuat kantong tabungan melalui Riverpod.
    try {
      await ref.read(savingsStateProvider.notifier).loadGoals();
    } catch (_) {
      // Aplikasi tetap berjalan jika tabungan gagal dimuat.
    }

    // Memuat tawaran pekerjaan.
    try {
      await widget.jobOfferController.initialize();
    } catch (_) {
      // Planner tetap dapat dibuka.
    }
  }

  // ===================================================
  // PROFILE
  // ===================================================

  Future<void> _loadProfile() async {
    final profile = await _profileStore.load();

    if (mounted) {
      setState(() {
        _profile = profile;
      });
    }
  }

  // ===================================================
  // CHANGE THEME
  // ===================================================

  Future<void> _toggleTheme() async {
    if (_changingTheme) return;

    final isCurrentlyDark =
        Theme.of(context).brightness == Brightness.dark;

    setState(() {
      _changingTheme = true;
    });

    try {
      await ref.read(appSettingsProvider.notifier).toggleTheme(
            isCurrentlyDark
                ? Brightness.dark
                : Brightness.light,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengganti tema aplikasi.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _changingTheme = false;
        });
      }
    }
  }

  // ===================================================
  // OPEN PROFILE
  // ===================================================

  Future<void> _openProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) {
          return FinPlanProfilePage(
            initialProfile: _profile,
            onSave: _profileStore.save,
          );
        },
      ),
    );

    if (changed == true && mounted) {
      await _loadProfile();
    }
  }

  // ===================================================
  // OPEN SETTINGS
  // ===================================================

  Future<void> _openSettings() async {
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
                textScale: widget.fontScale,
                onTextScaleChanged: widget.onFontScaleChanged,
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================================================
  // OPEN SAVINGS FORM
  // ===================================================

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

  // ===================================================
  // OPEN SAVINGS DETAIL
  // ===================================================

  Future<void> _openSavingsDetail(String goalId) async {
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

  // ===================================================
  // OPEN SAVINGS PAGE
  // ===================================================

  Future<void> _openSavingsPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return SavingsPage(
            controller: widget.savingsController,
            onCreateGoal: () {
              unawaited(_openSavingsForm());
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

  // ===================================================
  // OPEN BUDGET PLANNER
  // ===================================================

  Future<void> _openBudgetPlanner() async {
    final initialPlan = ref.read(financePlanProvider);

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
              title: const Text('Rencana & Anggaran'),
            ),
            body: SafeArea(
              child: Consumer(
                builder: (context, ref, _) {
                  final current =
                      ref.watch(financePlanProvider) ?? initialPlan;

                  return PlannerPage(
                    plan: current,
                    onSave: ref
                        .read(financePlanProvider.notifier)
                        .savePlan,
                    jobOfferController: widget.jobOfferController,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================================================
  // OPEN SALARY CALCULATOR
  // ===================================================

  Future<void> _openSalaryCalculator() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Kalkulator Gaji'),
            ),
            body: SafeArea(
              child: Consumer(
                builder: (context, ref, _) {
                  final salary =
                      ref.watch(financePlanProvider)?.actualIncome ?? 0;

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

  // ===================================================
  // SIMULASI SISA UANG
  // ===================================================

  Future<void> _openSisaUangSimulator() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return const SisaUangPage();
        },
      ),
    );
  }

  // ===================================================
  // ADD JOB OFFER
  // ===================================================

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

  // ===================================================
  // OPEN JOB OFFERS
  // ===================================================

  Future<void> _openJobOffers() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Tawaran Kerja'),
            ),
            body: SafeArea(
              child: JobOffersPage(
                controller: widget.jobOfferController,
                onAdd: () {
                  unawaited(_openJobOfferForm());
                },
                onEdit: (offer) {
                  unawaited(
                    _openJobOfferForm(offer: offer),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================================================
  // HOME DASHBOARD
  // ===================================================

  Widget _home(FinancePlan plan) {
    return DashboardPage(
      plan: plan,
      onOpenPlanner: () {
        setState(() {
          _selectedIndex = 1;
        });
      },
    );
  }

  // ===================================================
  // MAIN NAVIGATION
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(financePlanProvider);

    if (plan == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final pages = <Widget>[
      // HOME
      _home(plan),

      // PLANNER
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

      // TRANSAKSI
      TransactionsPage(
        controller: widget.transactionController,
      ),

      // PROFIL
      FinPlanProfileTab(
        profile: _profile,
        onEditProfile: () {
          unawaited(_openProfile());
        },
        onOpenSettings: () {
          unawaited(_openSettings());
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer,
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
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
            onPressed: _changingTheme ? null : _toggleTheme,
            icon: Icon(
              isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),

      bottomNavigationBar: NavigationBar(
        height: (72 * widget.fontScale)
            .clamp(72.0, 110.0)
            .toDouble(),
        selectedIndex: _selectedIndex,
        indicatorColor:
            Theme.of(context).colorScheme.primaryContainer,
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// =====================================================
// PLANNER HUB PAGE
// =====================================================

class PlannerHubPage extends StatelessWidget {
  const PlannerHubPage({
    super.key,
    required this.plan,
    required this.onOpenBudget,
    required this.onOpenSalary,
    required this.onOpenJobs,
    required this.onOpenSavings,
    required this.onOpenSisaUang,
  });

  final FinancePlan plan;

  final VoidCallback onOpenBudget;
  final VoidCallback onOpenSalary;
  final VoidCallback onOpenJobs;
  final VoidCallback onOpenSavings;
  final VoidCallback onOpenSisaUang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final items = [
      (
        Icons.pie_chart_outline_rounded,
        'Anggaran',
        'Pembagian gaji',
        onOpenBudget,
      ),
      (
        Icons.calculate_rounded,
        'Kalkulator Gaji',
        'Hitung pendapatan',
        onOpenSalary,
      ),
      (
        Icons.work_outline_rounded,
        'Tawaran Kerja',
        'Bandingkan pilihan',
        onOpenJobs,
      ),
      (
        Icons.savings_rounded,
        'Kantong Tabungan',
        'Kejar targetmu',
        onOpenSavings,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale =
            MediaQuery.textScalerOf(context).scale(16) / 16;

        final columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 480
                ? 2
                : (constraints.maxWidth < 345 || scale > 1.3)
                    ? 1
                    : 2;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            32,
          ),
          children: [
            // HEADER
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Atur Keuanganmu',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // KARTU PENGHASILAN
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF064E3B),
                    Color(0xFF059669),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Penghasilan Bulanan',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white70,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      rupiah(plan.actualIncome),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Icon(
                        Icons.flag_outlined,
                        color: Color(0xFFBBF7D0),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Target ideal: ${rupiah(plan.idealIncome)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // SIMULASI SISA UANG
            Material(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onOpenSisaUang,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.hourglass_bottom_rounded,
                          color: scheme.onPrimary,
                          size: 29,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Uang Sampai Gajian',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Simulasi sisa uangmu',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Icon(
                        Icons.arrow_forward_rounded,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            Text(
              'Jelajahi Fitur',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 14),

            // FEATURE GRID
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: columns == 1
                    ? (130 * scale)
                        .clamp(130.0, 195.0)
                        .toDouble()
                    : (175 * scale)
                        .clamp(175.0, 290.0)
                        .toDouble(),
              ),
              itemBuilder: (context, index) {
                final item = items[index];

                return _PlannerMenuTile(
                  icon: item.$1,
                  title: item.$2,
                  description: item.$3,
                  onTap: item.$4,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// =====================================================
// PLANNER MENU TILE
// =====================================================

class _PlannerMenuTile extends StatelessWidget {
  const _PlannerMenuTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 156;

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(
                alpha: 0.5,
              ),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(compact ? 11 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: compact ? 43 : 48,
                        height: compact ? 43 : 48,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          icon,
                          size: compact ? 24 : 27,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        color: scheme.primary,
                        size: 18,
                      ),
                    ],
                  ),

                  const Spacer(),

                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: compact ? 12.5 : 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}