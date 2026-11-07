import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/plan_editor_provider.dart';
import 'plan_editor_fields.dart';

// =====================================================
// PROFILE & INCOME STEP
// =====================================================

class ProfileIncomeStep extends ConsumerWidget {
  const ProfileIncomeStep({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    // ================================================
    // RIVERPOD STATE
    // ================================================

    final draft = ref.watch(
      planEditorProvider,
    );

    final notifier = ref.read(
      planEditorProvider.notifier,
    );

    final plan = draft.toFinancePlan();

    final scheme = Theme.of(context).colorScheme;

    // ================================================
    // UI
    // ================================================

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ============================================
        // PENGHASILAN UTAMA
        // ============================================

        PlanEditorSectionCard(
          title: 'Penghasilan Utama',
          icon: Icons.account_balance_wallet_outlined,
          children: [
            TextFormField(
              key: const ValueKey('profile_name'),
              initialValue: draft.name,
              maxLength: 40,
              textCapitalization:
                  TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Panggilan',
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                ),
              ),
              onChanged: notifier.updateName,
            ),

            const SizedBox(height: 12),

            PlanEditorMoneyField(
              key: const ValueKey('main_salary'),
              label: 'Gaji Bersih Bulanan',
              value: draft.salary,
              onChanged: notifier.updateSalary,
            ),
          ],
        ),

        const SizedBox(height: 17),

        // ============================================
        // PEMASUKAN TAMBAHAN
        // ============================================

        PlanEditorSectionCard(
          title: 'Pemasukan Tambahan',
          icon: Icons.add_chart_rounded,
          children: [
            for (final income in draft.additionalIncomes)
              Container(
                key: ValueKey(
                  'income_card_${income.id}',
                ),
                margin: const EdgeInsets.only(
                  bottom: 13,
                ),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(16),
                  color: scheme.surfaceContainerHighest,
                ),
                child: Column(
                  children: [
                    // ==================================
                    // HEADER PEMASUKAN
                    // ==================================

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sumber Pemasukan',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        IconButton(
                          tooltip: 'Hapus pemasukan',
                          onPressed: () {
                            notifier.removeIncome(
                              income.id,
                            );
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                          ),
                        ),
                      ],
                    ),

                    // ==================================
                    // NAMA PEMASUKAN
                    // ==================================

                    TextFormField(
                      key: ValueKey(
                        'income_name_${income.id}',
                      ),
                      initialValue: income.name,
                      decoration: const InputDecoration(
                        labelText: 'Nama',
                        hintText: 'Freelance / Usaha',
                      ),
                      onChanged: (text) {
                        notifier.updateIncome(
                          income.id,
                          name: text,
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // ==================================
                    // NOMINAL PEMASUKAN
                    // ==================================

                    PlanEditorMoneyField(
                      key: ValueKey(
                        'income_amount_${income.id}',
                      ),
                      label: 'Nominal',
                      value: income.amount,
                      onChanged: (amount) {
                        notifier.updateIncome(
                          income.id,
                          amount: amount,
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // ==================================
                    // FREKUENSI PEMASUKAN
                    // ==================================

                    PlanEditorFrequencyField(
                      value: income.frequency,
                      onChanged: (frequency) {
                        notifier.updateIncome(
                          income.id,
                          frequency: frequency,
                        );
                      },
                    ),
                  ],
                ),
              ),

            // ========================================
            // TOMBOL TAMBAH PEMASUKAN
            // ========================================

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: notifier.addIncome,
                icon: const Icon(
                  Icons.add_rounded,
                ),
                label: const Text(
                  'Tambah Pemasukan',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 17),

        // ============================================
        // TOTAL PEMASUKAN
        // ============================================

        Row(
          children: [
            PlanEditorMetricCard(
              label: 'Total Pemasukan',
              amount: plan.totalMonthlyIncome,
              icon: Icons.trending_up_rounded,
              color: scheme.primary,
            ),
          ],
        ),
      ],
    );
  }
}