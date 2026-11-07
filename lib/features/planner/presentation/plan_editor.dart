import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/finance_plan.dart';
import '../providers/plan_editor_provider.dart';

import '../presentation/widgets/expneses_step.dart';
import '../presentation/widgets/food_bufget_step.dart';
import '../presentation/widgets/plan_summary_step.dart';
import '../presentation/widgets/plan_income_step.dart';
import '../presentation/widgets/savings_step.dart';
import '../presentation/widgets/transport_step.dart';

// =====================================================
// PLAN EDITOR
// =====================================================

class PlanEditor extends StatefulWidget {
  const PlanEditor({
    super.key,
    required this.initial,
    required this.onSave,
    this.onboarding = false,
  });

  final FinancePlan initial;
  final Future<void> Function(FinancePlan) onSave;
  final bool onboarding;

  @override
  State<PlanEditor> createState() {
    return _PlanEditorScopeState();
  }
}

// =====================================================
// PROVIDER SCOPE
// =====================================================

/// StatefulWidget ini hanya menjaga konfigurasi
/// sesi editor agar tidak berubah saat widget rebuild.
///
/// Tidak menggunakan setState().
/// Seluruh state formulir tetap dikelola Riverpod.
class _PlanEditorScopeState extends State<PlanEditor> {
  late final PlanEditorConfig _config;

  @override
  void initState() {
    super.initState();

    _config = PlanEditorConfig(
      initial: widget.initial,
      onboarding: widget.onboarding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        planEditorConfigProvider.overrideWithValue(
          _config,
        ),
      ],
      child: _PlanEditorContent(
        onSave: widget.onSave,
        onboarding: widget.onboarding,
      ),
    );
  }
}

// =====================================================
// PLAN EDITOR CONTENT
// =====================================================

class _PlanEditorContent extends ConsumerWidget {
  const _PlanEditorContent({
    required this.onSave,
    required this.onboarding,
  });

  final Future<void> Function(FinancePlan) onSave;
  final bool onboarding;

  // ===================================================
  // STEP TITLES
  // ===================================================

  static const _titles = [
    'Profil & Pemasukan',
    'Anggaran Makan',
    'Transportasi',
    'Kebutuhan',
    'Tabungan',
    'Ringkasan',
  ];

  // ===================================================
  // STEP ICONS
  // ===================================================

  static const _icons = [
    Icons.account_balance_wallet_outlined,
    Icons.restaurant_outlined,
    Icons.directions_transit_outlined,
    Icons.shopping_bag_outlined,
    Icons.savings_outlined,
    Icons.pie_chart_outline_rounded,
  ];

  // ===================================================
  // BUILD
  // ===================================================

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    // ================================================
    // RIVERPOD STATE
    // ================================================

    final step = ref.watch(
      planEditorProvider.select(
        (draft) => draft.step,
      ),
    );

    final isSaving = ref.watch(
      planEditorProvider.select(
        (draft) => draft.isSaving,
      ),
    );

    final notifier = ref.read(
      planEditorProvider.notifier,
    );

    final scheme = Theme.of(context).colorScheme;

    // ================================================
    // UI
    // ================================================

    return Column(
      children: [
        // ============================================
        // STEP HEADER
        // ============================================

        Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            14,
            18,
            10,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _icons[step],
                      color: scheme.onPrimaryContainer,
                      size: 25,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Langkah ${step + 1} dari 6',
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          _titles[step],
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ======================================
              // PROGRESS INDICATOR
              // ======================================

              Row(
                children: [
                  for (var index = 0;
                      index < 6;
                      index++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == 5 ? 0 : 5,
                        ),
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: index <= step
                                ? scheme.primary
                                : scheme
                                    .surfaceContainerHighest,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // ============================================
        // STEP CONTENT
        // ============================================

        Expanded(
          child: ListView(
            key: ValueKey(
              'plan_editor_step_$step',
            ),
            padding: const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              25,
            ),
            children: [
              _buildStep(step),
            ],
          ),
        ),

        // ============================================
        // BOTTOM NAVIGATION
        // ============================================

        Container(
          padding: const EdgeInsets.fromLTRB(
            18,
            11,
            18,
            15,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // ====================================
                // BACK BUTTON
                // ====================================

                if (step > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isSaving
                          ? null
                          : notifier.goBack,
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(51),
                      ),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                      ),
                      label: const Text(
                        'Kembali',
                      ),
                    ),
                  ),

                  const SizedBox(width: 11),
                ],

                // ====================================
                // NEXT / SAVE BUTTON
                // ====================================

                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: isSaving
                        ? null
                        : () {
                            _next(
                              context,
                              ref,
                              step,
                            );
                          },
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(51),
                    ),
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            step == 5
                                ? Icons
                                    .check_circle_outline_rounded
                                : Icons
                                    .arrow_forward_rounded,
                          ),
                    label: Text(
                      isSaving
                          ? 'Menyimpan...'
                          : step == 5
                              ? 'Simpan Rencana'
                              : 'Selanjutnya',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===================================================
  // PILIH WIDGET BERDASARKAN STEP
  // ===================================================

  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return const ProfileIncomeStep();

      case 1:
        return const FoodBudgetStep();

      case 2:
        return const TransportStep();

      case 3:
        return const ExpensesStep();

      case 4:
        return const SavingsStep();

      case 5:
        return const PlanSummaryStep();

      default:
        return const SizedBox.shrink();
    }
  }

  // ===================================================
  // NEXT / SAVE
  // ===================================================

  Future<void> _next(
    BuildContext context,
    WidgetRef ref,
    int step,
  ) async {
    final notifier = ref.read(
      planEditorProvider.notifier,
    );

    // ================================================
    // NAVIGASI ANTAR LANGKAH
    // ================================================

    if (step < 5) {
      final error = notifier.nextStep();

      if (error != null && context.mounted) {
        _showMessage(
          context,
          error,
        );
      }

      return;
    }

    // ================================================
    // SIMPAN RENCANA
    // ================================================

    try {
      await notifier.save(onSave);

      if (context.mounted && !onboarding) {
        _showMessage(
          context,
          'Rencana keuangan berhasil disimpan.',
        );
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        _showMessage(
          context,
          error.message,
        );
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(
          context,
          'Gagal menyimpan rencana. Coba lagi.',
        );
      }
    }
  }

  // ===================================================
  // SNACKBAR
  // ===================================================

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}