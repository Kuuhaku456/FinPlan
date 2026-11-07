import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/plan_editor_provider.dart';
import 'plan_editor_fields.dart';

// =====================================================
// EXPENSES STEP
// =====================================================

class ExpensesStep extends ConsumerWidget {
  const ExpensesStep({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    // =================================================
    // RIVERPOD STATE
    // =================================================

    final draft = ref.watch(
      planEditorProvider,
    );

    final notifier = ref.read(
      planEditorProvider.notifier,
    );

    final plan = draft.toFinancePlan();

    final scheme = Theme.of(context).colorScheme;

    // =================================================
    // UI
    // =================================================

    return Column(
      children: [
        // =============================================
        // KEBUTUHAN BULANAN
        // =============================================

        PlanEditorSectionCard(
          title: 'Kebutuhan Bulanan',
          icon: Icons.shopping_bag_outlined,
          children: [
            // TEMPAT TINGGAL

            PlanEditorMoneyField(
              key: const ValueKey('housing'),
              label: 'Tempat Tinggal',
              value: draft.housing,
              onChanged: notifier.updateHousing,
            ),

            const SizedBox(height: 12),

            // TAGIHAN

            PlanEditorMoneyField(
              key: const ValueKey('bills'),
              label: 'Tagihan',
              value: draft.bills,
              onChanged: notifier.updateBills,
            ),

            const SizedBox(height: 12),

            // KEBUTUHAN PRIBADI

            PlanEditorMoneyField(
              key: const ValueKey('personal'),
              label: 'Kebutuhan Pribadi',
              value: draft.personal,
              onChanged: notifier.updatePersonal,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // =============================================
        // KEBUTUHAN TAMBAHAN
        // =============================================

        PlanEditorSectionCard(
          title: 'Kebutuhan Tambahan',
          icon: Icons.category_outlined,
          children: [
            for (final expense in draft.customExpenses)
              Container(
                key: ValueKey(
                  'expense_${expense.id}',
                ),
                margin: const EdgeInsets.only(
                  bottom: 13,
                ),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // ==================================
                    // HEADER
                    // ==================================

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Kebutuhan Custom',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        IconButton(
                          tooltip: 'Hapus kebutuhan',
                          onPressed: () {
                            notifier.removeExpense(
                              expense.id,
                            );
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                          ),
                        ),
                      ],
                    ),

                    // ==================================
                    // NAMA KEBUTUHAN
                    // ==================================

                    TextFormField(
                      key: ValueKey(
                        'expense_name_${expense.id}',
                      ),
                      initialValue: expense.name,
                      decoration: const InputDecoration(
                        labelText: 'Nama Kebutuhan',
                        hintText:
                            'Perpuluhan / Pendidikan',
                      ),
                      onChanged: (name) {
                        notifier.updateExpense(
                          expense.id,
                          name: name,
                        );
                      },
                    ),

                    const SizedBox(height: 11),

                    // ==================================
                    // NOMINAL
                    // ==================================

                    PlanEditorMoneyField(
                      key: ValueKey(
                        'expense_amount_${expense.id}',
                      ),
                      label: 'Nominal',
                      value: expense.amount,
                      onChanged: (amount) {
                        notifier.updateExpense(
                          expense.id,
                          amount: amount,
                        );
                      },
                    ),

                    const SizedBox(height: 11),

                    // ==================================
                    // FREKUENSI
                    // ==================================

                    PlanEditorFrequencyField(
                      value: expense.frequency,
                      onChanged: (frequency) {
                        notifier.updateExpense(
                          expense.id,
                          frequency: frequency,
                        );
                      },
                    ),
                  ],
                ),
              ),

            // ========================================
            // TAMBAH KEBUTUHAN
            // ========================================

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: notifier.addExpense,
                icon: const Icon(
                  Icons.add_rounded,
                ),
                label: const Text(
                  'Tambah Kebutuhan',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // =============================================
        // TOTAL KEBUTUHAN
        // =============================================

        Row(
          children: [
            PlanEditorMetricCard(
              label: 'Total Kebutuhan',
              amount: plan.expenses,
              icon: Icons.receipt_long_outlined,
              color: Colors.orange.shade700,
            ),
          ],
        ),
      ],
    );
  }
}