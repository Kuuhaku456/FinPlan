import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../models/savings_goal.dart';
import '../state/savings_controller.dart';
import '../state/savings_notifier.dart';

// ==========================================
// FINPLAN COLORS
// ==========================================

const _darkGreen = Color(0xFF064E3B);
const _green = Color(0xFF059669);
const _mint = Color(0xFFA7F3D0);
const _red = Color(0xFFEF4444);
const _amber = Color(0xFFF59E0B);

// ==========================================
// ENUM & MODELS
// ==========================================

enum _SavingsFilter {
  active,
  archived,
}

enum _GoalAction {
  view,
  archive,
  restore,
  delete,
}

class _SavingsInput {
  const _SavingsInput(
    this.amount,
    this.note,
  );

  final int amount;
  final String note;
}

// ==========================================
// SAVINGS PAGE - RIVERPOD
// ==========================================

class SavingsPage extends ConsumerStatefulWidget {
  const SavingsPage({
    super.key,
    required this.controller,
    required this.onCreateGoal,
    required this.onOpenGoal,
  });

  // Dipertahankan untuk kompatibilitas
  // dengan navigasi yang sudah ada.
  final SavingsController controller;

  final VoidCallback onCreateGoal;
  final ValueChanged<String> onOpenGoal;

  @override
  ConsumerState<SavingsPage> createState() {
    return _SavingsPageState();
  }
}

class _SavingsPageState
    extends ConsumerState<SavingsPage> {
  _SavingsFilter _filter =
      _SavingsFilter.active;

  // ========================================
  // INITIALIZATION
  // ========================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final state = ref.read(
        savingsStateProvider,
      );

      if (!state.hasLoaded && !state.isLoading) {
        ref
            .read(savingsStateProvider.notifier)
            .loadGoals();
      }
    });
  }

  // ========================================
  // SNACKBAR
  // ========================================

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ========================================
  // INPUT SETOR / AMBIL TABUNGAN
  // ========================================

  Future<_SavingsInput?> _askAmount({
    required SavingsGoal goal,
    required bool deposit,
  }) async {
    final amountController =
        TextEditingController();

    final noteController =
        TextEditingController();

    final result =
        await showDialog<_SavingsInput>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, updateDialog) {
            final amount = parseRupiah(
              amountController.text,
            );

            final exceedsBalance =
                !deposit &&
                amount > goal.savedAmount;

            final canSubmit =
                amount > 0 && !exceedsBalance;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(24),
              ),

              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: deposit
                        ? _mint
                        : const Color(0xFFFEE2E2),

                    child: Icon(
                      deposit
                          ? Icons.add_rounded
                          : Icons.remove_rounded,

                      color: deposit
                          ? _darkGreen
                          : _red,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      deposit
                          ? 'Setor Tabungan'
                          : 'Ambil Tabungan',

                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      '${goal.emoji} ${goal.name}',

                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Saldo: ${rupiah(goal.savedAmount)}',

                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller:
                          amountController,

                      autofocus: true,

                      keyboardType:
                          TextInputType.number,

                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly,
                      ],

                      onChanged: (_) {
                        updateDialog(() {});
                      },

                      decoration:
                          InputDecoration(
                        labelText: 'Nominal',
                        prefixText: 'Rp ',

                        prefixIcon:
                            const Icon(
                          Icons.payments_outlined,
                        ),

                        errorText:
                            exceedsBalance
                                ? 'Melebihi saldo tabungan'
                                : null,
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller:
                          noteController,

                      maxLength: 100,

                      decoration:
                          const InputDecoration(
                        labelText:
                            'Catatan (opsional)',

                        prefixIcon: Icon(
                          Icons.edit_note_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },

                  child: const Text('Batal'),
                ),

                FilledButton(
                  onPressed: canSubmit
                      ? () {
                          Navigator.pop(
                            dialogContext,

                            _SavingsInput(
                              amount,

                              noteController
                                  .text
                                  .trim(),
                            ),
                          );
                        }
                      : null,

                  child: Text(
                    deposit
                        ? 'Setor'
                        : 'Ambil',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    noteController.dispose();

    return result;
  }

  // ========================================
  // SETOR / AMBIL MELALUI RIVERPOD
  // ========================================

  Future<void> _changeBalance(
    SavingsGoal goal, {
    required bool deposit,
  }) async {
    final state = ref.read(
      savingsStateProvider,
    );

    if (state.isSaving || goal.isArchived) {
      return;
    }

    final input = await _askAmount(
      goal: goal,
      deposit: deposit,
    );

    if (!mounted || input == null) {
      return;
    }

    try {
      final notifier = ref.read(
        savingsStateProvider.notifier,
      );

      if (deposit) {
        await notifier.addSavings(
          goal.id,
          input.amount,
          note: input.note,
        );
      } else {
        await notifier.withdrawSavings(
          goal.id,
          input.amount,
          note: input.note,
        );
      }

      if (!mounted) return;

      _message(
        deposit
            ? 'Berhasil menabung ${rupiah(input.amount)}'
            : 'Berhasil mengambil ${rupiah(input.amount)}',
      );
    } catch (error) {
      if (!mounted) return;

      _message(
        'Transaksi gagal: $error',
      );
    }
  }

  // ========================================
  // HANDLE ACTION
  // ========================================

  Future<void> _handleAction(
    _GoalAction action,
    SavingsGoal goal,
  ) async {
    if (action == _GoalAction.view) {
      widget.onOpenGoal(goal.id);
      return;
    }

    if (action == _GoalAction.delete) {
      await _confirmDelete(goal);
      return;
    }

    try {
      final notifier = ref.read(
        savingsStateProvider.notifier,
      );

      if (action == _GoalAction.archive) {
        await notifier.archiveGoal(
          goal.id,
        );

        if (!mounted) return;

        _message(
          'Kantong berhasil diarsipkan.',
        );
      } else if (action ==
          _GoalAction.restore) {
        await notifier.restoreGoal(
          goal.id,
        );

        if (!mounted) return;

        _message(
          'Kantong berhasil dipulihkan.',
        );
      }
    } catch (error) {
      if (!mounted) return;

      _message(
        'Gagal memperbarui kantong: $error',
      );
    }
  }

  // ========================================
  // DELETE GOAL
  // ========================================

  Future<void> _confirmDelete(
    SavingsGoal goal,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Hapus Kantong?',
          ),

          content: Column(
            mainAxisSize:
                MainAxisSize.min,

            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                '${goal.emoji} ${goal.name}',

                style: const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Tabungan tercatat: '
                '${rupiah(goal.savedAmount)}',
              ),

              const SizedBox(height: 12),

              const Text(
                'Kantong dan seluruh riwayatnya '
                'akan dihapus permanen.',
              ),

              const SizedBox(height: 8),

              const Text(
                'Uang di rekening bank sebenarnya '
                'tidak terpengaruh.',

                style: TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child: const Text('Batal'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _red,
              ),

              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    try {
      final deleted = await ref
          .read(savingsStateProvider.notifier)
          .deleteGoal(goal.id);

      if (!mounted) return;

      _message(
        deleted
            ? 'Kantong berhasil dihapus.'
            : 'Kantong tidak ditemukan.',
      );
    } catch (error) {
      if (!mounted) return;

      _message(
        'Gagal menghapus: $error',
      );
    }
  }

  // ========================================
  // SUMMARY METRIC
  // ========================================

  Widget _summaryMetric(
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              size: 19,
              color: _mint,
            ),

            const SizedBox(width: 7),

            Text(
              value,

              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        Text(
          label,
          textAlign: TextAlign.center,

          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ========================================
  // SUMMARY CARD
  // ========================================

  Widget _summaryCard(
    SavingsViewState state,
  ) {
    final summary = state.summary;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(26),

        gradient:
            const LinearGradient(
          colors: [
            _darkGreen,
            _green,
          ],

          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(
              alpha: 0.16,
            ),

            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .account_balance_wallet_outlined,

                color: Colors.white70,
                size: 20,
              ),

              SizedBox(width: 8),

              Text(
                'Total Tabungan',

                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          FittedBox(
            fit: BoxFit.scaleDown,

            alignment:
                Alignment.centerLeft,

            child: Text(
              rupiah(summary.totalSaved),

              style: const TextStyle(
                color: Colors.white,
                fontSize: 31,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Target ${rupiah(summary.totalTarget)}',

            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 23),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progress',

                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),

              Text(
                '${summary.progressPercent.toStringAsFixed(1)}%',

                style: const TextStyle(
                  color: _mint,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),

            child: LinearProgressIndicator(
              value: summary.progress
                  .clamp(0.0, 1.0)
                  .toDouble(),

              minHeight: 10,

              backgroundColor:
                  Colors.white24,

              color: _mint,
            ),
          ),

          const SizedBox(height: 23),

          const Divider(
            color: Colors.white24,
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  Icons.savings_outlined,

                  '${summary.activeGoals}',

                  'Kantong Aktif',
                ),
              ),

              Container(
                height: 38,
                width: 1,
                color: Colors.white24,
              ),

              Expanded(
                child: _summaryMetric(
                  Icons
                      .emoji_events_outlined,

                  '${summary.completedGoals}',

                  'Target Tercapai',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========================================
  // FILTER ACTIVE / ARCHIVED
  // ========================================

  Widget _filterWidget(
    SavingsViewState state,
  ) {
    return SizedBox(
      width: double.infinity,

      child: SegmentedButton<
          _SavingsFilter>(
        showSelectedIcon: false,

        segments: [
          ButtonSegment(
            value: _SavingsFilter.active,

            icon: const Icon(
              Icons.wallet_outlined,
              size: 18,
            ),

            label: Text(
              'Aktif (${state.activeGoals.length})',
            ),
          ),

          ButtonSegment(
            value:
                _SavingsFilter.archived,

            icon: const Icon(
              Icons.archive_outlined,
              size: 18,
            ),

            label: Text(
              'Arsip (${state.archivedGoals.length})',
            ),
          ),
        ],

        selected: {_filter},

        onSelectionChanged:
            (selection) {
          if (selection.isEmpty) {
            return;
          }

          setState(() {
            _filter =
                selection.first;
          });
        },
      ),
    );
  }

  // ========================================
  // STATUS BADGE
  // ========================================

  Widget _statusBadge(
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),

      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.12,
        ),

        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Text(
        label,

        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  // ========================================
  // DEADLINE BADGE
  // ========================================

  Widget _deadlineBadge(
    SavingsGoal goal,
  ) {
    final days = goal.daysRemaining;

    String label;

    if (goal.isCompleted) {
      label = 'Target tercapai';
    } else if (days == null) {
      label = 'Tanpa deadline';
    } else if (days < 0) {
      label =
          'Lewat ${days.abs()} hari';
    } else if (days == 0) {
      label = 'Hari ini';
    } else {
      label = '$days hari lagi';
    }

    final scheme =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),

      decoration: BoxDecoration(
        color: scheme
            .surfaceContainerHighest,

        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 12,
            color:
                scheme.onSurfaceVariant,
          ),

          const SizedBox(width: 5),

          Text(
            label,

            style: TextStyle(
              fontSize: 11,
              color:
                  scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // GOAL MENU
  // ========================================

  Widget _goalMenu(
    SavingsGoal goal,
  ) {
    return PopupMenuButton<
        _GoalAction>(
      tooltip: 'Opsi kantong',

      icon: const Icon(
        Icons.more_vert_rounded,
      ),

      onSelected: (action) {
        _handleAction(action, goal);
      },

      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _GoalAction.view,

          child: ListTile(
            dense: true,
            contentPadding:
                EdgeInsets.zero,

            leading: Icon(
              Icons.visibility_outlined,
            ),

            title:
                Text('Lihat Detail'),
          ),
        ),

        if (!goal.isArchived)
          const PopupMenuItem(
            value:
                _GoalAction.archive,

            child: ListTile(
              dense: true,
              contentPadding:
                  EdgeInsets.zero,

              leading: Icon(
                Icons.archive_outlined,
              ),

              title:
                  Text('Arsipkan'),
            ),
          ),

        if (goal.isArchived)
          const PopupMenuItem(
            value:
                _GoalAction.restore,

            child: ListTile(
              dense: true,
              contentPadding:
                  EdgeInsets.zero,

              leading: Icon(
                Icons.unarchive_outlined,
              ),

              title:
                  Text('Pulihkan'),
            ),
          ),

        const PopupMenuDivider(),

        const PopupMenuItem(
          value:
              _GoalAction.delete,

          child: ListTile(
            dense: true,
            contentPadding:
                EdgeInsets.zero,

            leading: Icon(
              Icons.delete_outline_rounded,
              color: _red,
            ),

            title: Text(
              'Hapus',

              style: TextStyle(
                color: _red,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========================================
  // GOAL CARD
  // ========================================

  Widget _goalCard(
    SavingsGoal goal,
    bool isSaving,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final statusColor =
        goal.isCompleted
            ? _green
            : goal.isOverdue
                ? _amber
                : scheme.primary;

    return Material(
      color:
          scheme.surfaceContainerLow,

      borderRadius:
          BorderRadius.circular(23),

      child: InkWell(
        borderRadius:
            BorderRadius.circular(23),

        onTap: () {
          widget.onOpenGoal(goal.id);
        },

        child: Container(
          padding:
              const EdgeInsets.all(17),

          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(23),

            border: Border.all(
              color:
                  scheme.outlineVariant,
            ),
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // HEADER
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,

                    alignment:
                        Alignment.center,

                    decoration:
                        BoxDecoration(
                      color: scheme
                          .primaryContainer,

                      borderRadius:
                          BorderRadius
                              .circular(17),
                    ),

                    child: Text(
                      goal.emoji,

                      style:
                          const TextStyle(
                        fontSize: 28,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [
                        Text(
                          goal.name,

                          maxLines: 1,

                          overflow:
                              TextOverflow
                                  .ellipsis,

                          style: theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          'Target ${rupiah(goal.targetAmount)}',

                          style: theme
                              .textTheme
                              .bodySmall,
                        ),
                      ],
                    ),
                  ),

                  _goalMenu(goal),
                ],
              ),

              const SizedBox(
                height: 19,
              ),

              // NOMINAL DAN PERSENTASE
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,

                children: [
                  Expanded(
                    child: Text(
                      rupiah(
                        goal.savedAmount,
                      ),

                      maxLines: 1,

                      overflow:
                          TextOverflow.ellipsis,

                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontSize: 23,
                            fontWeight:
                                FontWeight.w900,
                          ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Text(
                    '${goal.progressPercent.toStringAsFixed(1)}%',

                    style:
                        const TextStyle(
                      color: _green,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 13,
              ),

              // PROGRESS
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),

                child:
                    LinearProgressIndicator(
                  value: goal.progress
                      .clamp(0.0, 1.0)
                      .toDouble(),

                  minHeight: 9,
                  color: _green,

                  backgroundColor: scheme
                      .surfaceContainerHighest,
                ),
              ),

              const SizedBox(
                height: 13,
              ),

              // STATUS DAN DEADLINE
              Wrap(
                spacing: 8,
                runSpacing: 8,

                children: [
                  _statusBadge(
                    goal.statusLabel,
                    statusColor,
                  ),

                  if (goal.deadline !=
                      null)
                    _deadlineBadge(goal),
                ],
              ),

              const SizedBox(
                height: 17,
              ),

              // ACTIONS
              if (!goal.isArchived)
                Row(
                  children: [
                    Expanded(
                      child:
                          FilledButton.icon(
                        onPressed: isSaving
                            ? null
                            : () {
                                _changeBalance(
                                  goal,
                                  deposit:
                                      true,
                                );
                              },

                        icon:
                            const Icon(
                          Icons.add_rounded,
                          size: 19,
                        ),

                        label:
                            const Text(
                          'Setor',
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child:
                          OutlinedButton.icon(
                        onPressed: isSaving ||
                                goal.savedAmount <=
                                    0
                            ? null
                            : () {
                                _changeBalance(
                                  goal,
                                  deposit:
                                      false,
                                );
                              },

                        icon:
                            const Icon(
                          Icons
                              .remove_rounded,
                          size: 19,
                        ),

                        label:
                            const Text(
                          'Ambil',
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width:
                      double.infinity,

                  child:
                      OutlinedButton.icon(
                    onPressed: () {
                      widget.onOpenGoal(
                        goal.id,
                      );
                    },

                    icon: const Icon(
                      Icons.history_rounded,
                    ),

                    label: const Text(
                      'Lihat Detail & Riwayat',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================
  // EMPTY STATE
  // ========================================

  Widget _emptyState() {
    final scheme =
        Theme.of(context).colorScheme;

    final archived = _filter ==
        _SavingsFilter.archived;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          24,
          24,
          24,
          100,
        ),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              width: 96,
              height: 96,

              decoration:
                  BoxDecoration(
                color:
                    scheme.primaryContainer,

                shape: BoxShape.circle,
              ),

              child: Icon(
                archived
                    ? Icons.archive_outlined
                    : Icons.savings_outlined,

                size: 46,

                color: scheme
                    .onPrimaryContainer,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              archived
                  ? 'Belum Ada Arsip'
                  : 'Mulai Menabung! 🎯',

              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              archived
                  ? 'Kantong yang diarsipkan '
                      'akan muncul di sini.'
                  : 'Buat kantong pertamamu '
                      'untuk mencapai target keuangan.',

              textAlign:
                  TextAlign.center,

              style: TextStyle(
                fontSize: 13,
                color: scheme
                    .onSurfaceVariant,
              ),
            ),

            if (!archived) ...[
              const SizedBox(
                height: 22,
              ),

              FilledButton.icon(
                onPressed:
                    widget.onCreateGoal,

                icon: const Icon(
                  Icons.add_rounded,
                ),

                label: const Text(
                  'Buat Kantong',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========================================
  // ERROR STATE
  // ========================================

  Widget _errorState() {
    final scheme =
        Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              Icons
                  .error_outline_rounded,

              size: 54,
              color: scheme.error,
            ),

            const SizedBox(
              height: 15,
            ),

            const Text(
              'Gagal Memuat Kantong',

              style: TextStyle(
                fontWeight:
                    FontWeight.w800,

                fontSize: 18,
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            OutlinedButton.icon(
              onPressed: () {
                ref
                    .read(
                      savingsStateProvider
                          .notifier,
                    )
                    .loadGoals();
              },

              icon: const Icon(
                Icons.refresh_rounded,
              ),

              label:
                  const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // ERROR BANNER
  // ========================================

  Widget _errorBanner(
    String message,
  ) {
    final scheme =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(12),

      decoration:
          BoxDecoration(
        color:
            scheme.errorContainer,

        borderRadius:
            BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,

            color:
                scheme.onErrorContainer,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              message,

              style: TextStyle(
                color: scheme
                    .onErrorContainer,

                fontSize: 12,
              ),
            ),
          ),

          IconButton(
            tooltip: 'Tutup pesan',

            onPressed: () {
              ref
                  .read(
                    savingsStateProvider
                        .notifier,
                  )
                  .clearError();
            },

            icon: Icon(
              Icons.close_rounded,

              size: 18,

              color: scheme
                  .onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // MAIN BUILD
  // ========================================

  @override
  Widget build(
    BuildContext context,
  ) {
    // Riverpod memantau state tabungan.
    final state = ref.watch(
      savingsStateProvider,
    );

    final scheme =
        Theme.of(context).colorScheme;

    // Filter aktif atau arsip.
    final goals =
        _filter == _SavingsFilter.active
            ? state.activeGoals
            : state.archivedGoals;

    final initialLoading =
        state.isLoading &&
        !state.hasLoaded;

    final initialError =
        state.error != null &&
        !state.hasLoaded;

    return Scaffold(
      backgroundColor:
          scheme.surface,

      appBar: AppBar(
        title: const Text(
          'Kantong Tabungan',

          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Perbarui',

            onPressed: state.isLoading
                ? null
                : () {
                    ref
                        .read(
                          savingsStateProvider
                              .notifier,
                        )
                        .refresh();
                  },

            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      // ====================================
      // FLOATING ACTION BUTTON
      // ====================================

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: state.isSaving
            ? null
            : widget.onCreateGoal,

        backgroundColor: _green,
        foregroundColor: Colors.white,

        icon: const Icon(
          Icons.add_rounded,
        ),

        label: const Text(
          'Kantong Baru',
        ),
      ),

      // ====================================
      // BODY
      // ====================================

      body: RefreshIndicator(
        color: _green,

        onRefresh: () {
          return ref
              .read(
                savingsStateProvider.notifier,
              )
              .refresh();
        },

        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          slivers: [
            // ==============================
            // HEADER & SUMMARY
            // ==============================

            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  4,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Tabungan Saya',

                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w800,
                          ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    _summaryCard(state),

                    const SizedBox(
                      height: 26,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Kantong Kamu',

                            style: Theme.of(
                              context,
                            )
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                ),
                          ),
                        ),

                        IconButton.filledTonal(
                          tooltip:
                              'Tambah kantong',

                          onPressed: state
                                  .isSaving
                              ? null
                              : widget
                                  .onCreateGoal,

                          icon: const Icon(
                            Icons.add_rounded,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    _filterWidget(state),

                    const SizedBox(
                      height: 12,
                    ),
                  ],
                ),
              ),
            ),

            // ==============================
            // ERROR BANNER
            // ==============================

            if (state.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),

                  child: _errorBanner(
                    state.error!,
                  ),
                ),
              ),

            // ==============================
            // LOADING
            // ==============================

            if (initialLoading)
              const SliverFillRemaining(
                hasScrollBody: false,

                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              )

            // ==============================
            // ERROR STATE
            // ==============================

            else if (initialError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _errorState(),
              )

            // ==============================
            // EMPTY STATE
            // ==============================

            else if (goals.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(),
              )

            // ==============================
            // GOAL LIST
            // ==============================

            else
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  4,
                  18,
                  110,
                ),

                sliver: SliverList.builder(
                  itemCount: goals.length,

                  itemBuilder: (
                    context,
                    index,
                  ) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 13,
                      ),

                      child: _goalCard(
                        goals[index],
                        state.isSaving,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}