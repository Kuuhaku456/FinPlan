import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../models/savings_goal.dart';

import '../state/savings_controller.dart';
import '../state/savings_notifier.dart';

import '../features/savings/presentation/widgets/savings_summary_card.dart';

// =====================================================
// FINPLAN - SAVINGS PAGE
// =====================================================

const Color _darkGreen = Color(0xFF064E3B);
const Color _green = Color(0xFF059669);
const Color _mint = Color(0xFFA7F3D0);
const Color _red = Color(0xFFEF4444);
const Color _amber = Color(0xFFF59E0B);

// =====================================================
// FILTER
// =====================================================

enum _SavingsFilter {
  active,
  archived,
}

// =====================================================
// GOAL ACTION
// =====================================================

enum _GoalAction {
  view,
  archive,
  restore,
  delete,
}

// =====================================================
// SAVINGS INPUT
// =====================================================

class _SavingsInput {
  const _SavingsInput({
    required this.amount,
    required this.note,
  });

  final int amount;
  final String note;
}

// =====================================================
// SAVINGS PAGE
// =====================================================

class SavingsPage extends ConsumerStatefulWidget {
  const SavingsPage({
    super.key,
    required this.controller,
    required this.onCreateGoal,
    required this.onOpenGoal,
  });

  // Kompatibilitas dengan FinanceShell/main.dart.
  // Pembacaan dan perubahan data menggunakan Riverpod.
  final SavingsController controller;

  final VoidCallback onCreateGoal;

  final ValueChanged<String> onOpenGoal;

  @override
  ConsumerState<SavingsPage> createState() {
    return _SavingsPageState();
  }
}

// =====================================================
// SAVINGS PAGE STATE
// =====================================================

class _SavingsPageState extends ConsumerState<SavingsPage> {
  _SavingsFilter _filter = _SavingsFilter.active;

  // =====================================================
  // INIT STATE
  // =====================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final state = ref.read(savingsStateProvider);

      if (!state.hasLoaded && !state.isLoading) {
        ref
            .read(savingsStateProvider.notifier)
            .loadGoals();
      }
    });
  }

  // =====================================================
  // SNACKBAR
  // =====================================================

  void _showMessage(String message) {
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

  // =====================================================
  // SETOR / AMBIL DIALOG
  // =====================================================

  Future<_SavingsInput?> _askAmount({
    required SavingsGoal goal,
    required bool isDeposit,
  }) async {
    String amountInput = '';
    String noteInput = '';

    return showDialog<_SavingsInput>(
      context: context,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, updateDialog) {
            final amount = parseRupiah(amountInput);

            final exceedsBalance =
                !isDeposit && amount > goal.savedAmount;

            final canSubmit =
                amount > 0 && !exceedsBalance;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),

              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isDeposit
                        ? _mint
                        : const Color(0xFFFEE2E2),

                    child: Icon(
                      isDeposit
                          ? Icons.add_rounded
                          : Icons.remove_rounded,

                      color: isDeposit
                          ? _darkGreen
                          : _red,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      isDeposit
                          ? 'Setor Tabungan'
                          : 'Ambil Tabungan',

                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      '${goal.emoji} ${goal.name}',

                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
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

                    // NOMINAL
                    TextField(
                      autofocus: true,

                      keyboardType: TextInputType.number,

                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],

                      decoration: InputDecoration(
                        labelText: 'Nominal',

                        hintText: 'Contoh: 100000',

                        prefixText: 'Rp ',

                        prefixIcon: const Icon(
                          Icons.payments_outlined,
                        ),

                        errorText: exceedsBalance
                            ? 'Nominal melebihi saldo tabungan.'
                            : null,
                      ),

                      onChanged: (value) {
                        updateDialog(() {
                          amountInput = value;
                        });
                      },
                    ),

                    const SizedBox(height: 14),

                    // CATATAN
                    TextField(
                      maxLength: 100,

                      maxLines: 2,

                      decoration: const InputDecoration(
                        labelText: 'Catatan (Opsional)',

                        hintText: 'Contoh: Tabungan dari gaji',

                        prefixIcon: Icon(
                          Icons.edit_note_outlined,
                        ),
                      ),

                      onChanged: (value) {
                        noteInput = value;
                      },
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },

                  child: const Text('Batal'),
                ),

                FilledButton(
                  onPressed: canSubmit
                      ? () {
                          Navigator.pop(
                            dialogContext,

                            _SavingsInput(
                              amount: amount,
                              note: noteInput.trim(),
                            ),
                          );
                        }
                      : null,

                  child: Text(
                    isDeposit ? 'Setor' : 'Ambil',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =====================================================
  // CHANGE SAVINGS BALANCE
  // =====================================================

  Future<void> _changeBalance(
    SavingsGoal goal, {
    required bool isDeposit,
  }) async {
    final state = ref.read(savingsStateProvider);

    if (state.isSaving || goal.isArchived) {
      return;
    }

    final input = await _askAmount(
      goal: goal,
      isDeposit: isDeposit,
    );

    if (!mounted || input == null) {
      return;
    }

    try {
      final notifier = ref.read(
        savingsStateProvider.notifier,
      );

      if (isDeposit) {
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

      _showMessage(
        isDeposit
            ? 'Berhasil menabung ${rupiah(input.amount)}.'
            : 'Berhasil mengambil ${rupiah(input.amount)}.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Gagal memperbarui tabungan: $error',
      );
    }
  }

  // =====================================================
  // GOAL ACTION HANDLER
  // =====================================================

  Future<void> _handleAction(
    _GoalAction action,
    SavingsGoal goal,
  ) async {
    if (action == _GoalAction.view) {
      widget.onOpenGoal(goal.id);
      return;
    }

    if (ref.read(savingsStateProvider).isSaving) {
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
        await notifier.archiveGoal(goal.id);

        if (mounted) {
          _showMessage(
            'Kantong berhasil diarsipkan.',
          );
        }
      }

      if (action == _GoalAction.restore) {
        await notifier.restoreGoal(goal.id);

        if (mounted) {
          _showMessage(
            'Kantong berhasil dipulihkan.',
          );
        }
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Gagal memperbarui kantong: $error',
      );
    }
  }

  // =====================================================
  // DELETE GOAL
  // =====================================================

  Future<void> _confirmDelete(
    SavingsGoal goal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),

          title: const Text(
            'Hapus Kantong?',
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                '${goal.emoji} ${goal.name}',

                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Saldo tercatat: ${rupiah(goal.savedAmount)}',
              ),

              const SizedBox(height: 12),

              const Text(
                'Kantong dan seluruh riwayat tabungannya akan dihapus permanen.',
              ),

              const SizedBox(height: 10),

              const Text(
                'Tindakan ini tidak mengubah saldo rekening bank atau e-wallet sebenarnya.',

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
                foregroundColor: Colors.white,
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
      final success = await ref
          .read(savingsStateProvider.notifier)
          .deleteGoal(goal.id);

      if (!mounted) return;

      _showMessage(
        success
            ? 'Kantong berhasil dihapus.'
            : 'Kantong tidak ditemukan.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Gagal menghapus kantong: $error',
      );
    }
  }

  // =====================================================
  // FILTER SELECTOR
  // =====================================================

  Widget _buildFilter(
    SavingsViewState state,
  ) {
    return SizedBox(
      width: double.infinity,

      child: SegmentedButton<_SavingsFilter>(
        showSelectedIcon: false,

        segments: [
          ButtonSegment<_SavingsFilter>(
            value: _SavingsFilter.active,

            icon: const Icon(
              Icons.wallet_outlined,
              size: 18,
            ),

            label: Text(
              'Aktif (${state.activeGoals.length})',
            ),
          ),

          ButtonSegment<_SavingsFilter>(
            value: _SavingsFilter.archived,

            icon: const Icon(
              Icons.archive_outlined,
              size: 18,
            ),

            label: Text(
              'Arsip (${state.archivedGoals.length})',
            ),
          ),
        ],

        selected: {
          _filter,
        },

        onSelectionChanged: (selection) {
          if (selection.isEmpty) return;

          setState(() {
            _filter = selection.first;
          });
        },
      ),
    );
  }

  // =====================================================
  // STATUS BADGE
  // =====================================================

  Widget _buildStatusBadge(
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),

        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        label,

        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // =====================================================
  // DEADLINE BADGE
  // =====================================================

  Widget _buildDeadlineBadge(
    SavingsGoal goal,
  ) {
    final scheme = Theme.of(context).colorScheme;

    final days = goal.daysRemaining;

    String label;

    if (goal.isCompleted) {
      label = 'Target tercapai';
    } else if (days == null) {
      label = 'Tanpa deadline';
    } else if (days < 0) {
      label = 'Lewat ${days.abs()} hari';
    } else if (days == 0) {
      label = 'Hari ini';
    } else {
      label = '$days hari lagi';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),

      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 12,
            color: scheme.onSurfaceVariant,
          ),

          const SizedBox(width: 5),

          Text(
            label,

            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // GOAL ACTION MENU
  // =====================================================

  Widget _buildGoalMenu(
    SavingsGoal goal,
    bool isSaving,
  ) {
    return PopupMenuButton<_GoalAction>(
      tooltip: 'Opsi kantong',

      enabled: !isSaving,

      icon: const Icon(
        Icons.more_vert_rounded,
      ),

      onSelected: (action) {
        _handleAction(action, goal);
      },

      itemBuilder: (_) {
        return [
          const PopupMenuItem(
            value: _GoalAction.view,

            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,

              leading: Icon(
                Icons.visibility_outlined,
              ),

              title: Text(
                'Lihat Detail',
              ),
            ),
          ),

          if (!goal.isArchived)
            const PopupMenuItem(
              value: _GoalAction.archive,

              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,

                leading: Icon(
                  Icons.archive_outlined,
                ),

                title: Text(
                  'Arsipkan',
                ),
              ),
            ),

          if (goal.isArchived)
            const PopupMenuItem(
              value: _GoalAction.restore,

              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,

                leading: Icon(
                  Icons.unarchive_outlined,
                ),

                title: Text(
                  'Pulihkan',
                ),
              ),
            ),

          const PopupMenuDivider(),

          const PopupMenuItem(
            value: _GoalAction.delete,

            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,

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
        ];
      },
    );
  }

  // =====================================================
  // SAVINGS GOAL CARD
  // =====================================================

  Widget _buildGoalCard(
    SavingsGoal goal,
    bool isSaving,
  ) {
    final theme = Theme.of(context);

    final scheme = theme.colorScheme;

    final Color statusColor;

    if (goal.isArchived) {
      statusColor = scheme.onSurfaceVariant;
    } else if (goal.isCompleted) {
      statusColor = _green;
    } else if (goal.isOverdue) {
      statusColor = _amber;
    } else {
      statusColor = scheme.primary;
    }

    return Material(
      color: scheme.surfaceContainerLow,

      borderRadius: BorderRadius.circular(23),

      child: InkWell(
        borderRadius: BorderRadius.circular(23),

        onTap: () {
          widget.onOpenGoal(goal.id);
        },

        child: Container(
          padding: const EdgeInsets.all(17),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),

            border: Border.all(
              color: scheme.outlineVariant,
            ),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // =========================================
              // GOAL HEADER
              // =========================================

              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,

                    alignment: Alignment.center,

                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,

                      borderRadius: BorderRadius.circular(17),
                    ),

                    child: Text(
                      goal.emoji,

                      style: const TextStyle(
                        fontSize: 28,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        Text(
                          goal.name,

                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,

                          style: theme.textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'Target ${rupiah(goal.targetAmount)}',

                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  _buildGoalMenu(
                    goal,
                    isSaving,
                  ),
                ],
              ),

              const SizedBox(height: 19),

              // =========================================
              // AMOUNT & PROGRESS PERCENT
              // =========================================

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,

                children: [
                  Expanded(
                    child: Text(
                      rupiah(goal.savedAmount),

                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: theme.textTheme.titleLarge
                          ?.copyWith(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    '${goal.progressPercent.toStringAsFixed(1)}%',

                    style: const TextStyle(
                      color: _green,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 13),

              // =========================================
              // PROGRESS BAR
              // =========================================

              ClipRRect(
                borderRadius: BorderRadius.circular(20),

                child: LinearProgressIndicator(
                  value: goal.progress
                      .clamp(0.0, 1.0)
                      .toDouble(),

                  minHeight: 9,

                  color: _green,

                  backgroundColor:
                      scheme.surfaceContainerHighest,
                ),
              ),

              const SizedBox(height: 13),

              // =========================================
              // STATUS & DEADLINE
              // =========================================

              Wrap(
                spacing: 8,
                runSpacing: 8,

                children: [
                  _buildStatusBadge(
                    goal.statusLabel,
                    statusColor,
                  ),

                  if (goal.deadline != null)
                    _buildDeadlineBadge(goal),
                ],
              ),

              const SizedBox(height: 17),

              // =========================================
              // ACTION BUTTONS
              // =========================================

              if (!goal.isArchived)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isSaving
                            ? null
                            : () {
                                _changeBalance(
                                  goal,
                                  isDeposit: true,
                                );
                              },

                        icon: const Icon(
                          Icons.add_rounded,
                          size: 19,
                        ),

                        label: const Text('Setor'),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isSaving ||
                                goal.savedAmount <= 0
                            ? null
                            : () {
                                _changeBalance(
                                  goal,
                                  isDeposit: false,
                                );
                              },

                        icon: const Icon(
                          Icons.remove_rounded,
                          size: 19,
                        ),

                        label: const Text('Ambil'),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,

                  child: OutlinedButton.icon(
                    onPressed: () {
                      widget.onOpenGoal(goal.id);
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

  // =====================================================
  // EMPTY STATE
  // =====================================================

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;

    final isArchived =
        _filter == _SavingsFilter.archived;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          24,
          24,
          24,
          100,
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Container(
              width: 96,
              height: 96,

              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),

              child: Icon(
                isArchived
                    ? Icons.archive_outlined
                    : Icons.savings_outlined,

                size: 46,
                color: scheme.onPrimaryContainer,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              isArchived
                  ? 'Belum Ada Arsip'
                  : 'Mulai Menabung! 🎯',

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              isArchived
                  ? 'Kantong yang diarsipkan akan muncul di sini.'
                  : 'Buat kantong pertamamu untuk mencapai target keuangan.',

              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),

            if (!isArchived) ...[
              const SizedBox(height: 22),

              FilledButton.icon(
                onPressed: widget.onCreateGoal,

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

  // =====================================================
  // ERROR STATE
  // =====================================================

  Widget _buildErrorState() {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 54,
              color: scheme.error,
            ),

            const SizedBox(height: 15),

            const Text(
              'Gagal Memuat Kantong',

              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 15),

            OutlinedButton.icon(
              onPressed: () {
                ref
                    .read(savingsStateProvider.notifier)
                    .loadGoals();
              },

              icon: const Icon(
                Icons.refresh_rounded,
              ),

              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ERROR BANNER
  // =====================================================

  Widget _buildErrorBanner(String error) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: scheme.errorContainer,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: scheme.onErrorContainer,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              error,

              style: TextStyle(
                fontSize: 12,
                color: scheme.onErrorContainer,
              ),
            ),
          ),

          IconButton(
            tooltip: 'Tutup pesan',

            onPressed: () {
              ref
                  .read(savingsStateProvider.notifier)
                  .clearError();
            },

            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: scheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savingsStateProvider);

    final theme = Theme.of(context);

    final scheme = theme.colorScheme;

    final goals = _filter == _SavingsFilter.active
        ? state.activeGoals
        : state.archivedGoals;

    final initialLoading =
        state.isLoading && !state.hasLoaded;

    final initialError =
        state.error != null && !state.hasLoaded;

    return Scaffold(
      backgroundColor: scheme.surface,

      // =================================================
      // APP BAR
      // =================================================

      appBar: AppBar(
        title: const Text(
          'Kantong Tabungan',

          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Perbarui',

            onPressed: state.isLoading
                ? null
                : () {
                    ref
                        .read(savingsStateProvider.notifier)
                        .refresh();
                  },

            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      // =================================================
      // FLOATING ACTION BUTTON
      // =================================================

      floatingActionButton: FloatingActionButton.extended(
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

      // =================================================
      // BODY
      // =================================================

      body: RefreshIndicator(
        color: _green,

        onRefresh: () {
          return ref
              .read(savingsStateProvider.notifier)
              .refresh();
        },

        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          slivers: [
            // =============================================
            // HEADER & SUMMARY
            // =============================================

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
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

                      style: theme
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),

                    const SizedBox(height: 16),

                    // SUMMARY CARD BARU
                    SavingsSummaryCard(
                      summary: state.summary,
                    ),

                    const SizedBox(height: 26),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Kantong Kamu',

                            style: theme
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),

                        IconButton.filledTonal(
                          tooltip: 'Tambah kantong',

                          onPressed: state.isSaving
                              ? null
                              : widget.onCreateGoal,

                          icon: const Icon(
                            Icons.add_rounded,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _buildFilter(state),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // =============================================
            // ERROR BANNER
            // =============================================

            if (state.error != null && state.hasLoaded)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),

                  child: _buildErrorBanner(
                    state.error!,
                  ),
                ),
              ),

            // =============================================
            // INITIAL LOADING
            // =============================================

            if (initialLoading)
              const SliverFillRemaining(
                hasScrollBody: false,

                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )

            // =============================================
            // INITIAL ERROR
            // =============================================

            else if (initialError)
              SliverFillRemaining(
                hasScrollBody: false,

                child: _buildErrorState(),
              )

            // =============================================
            // EMPTY STATE
            // =============================================

            else if (goals.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,

                child: _buildEmptyState(),
              )

            // =============================================
            // SAVINGS GOALS
            // =============================================

            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  4,
                  18,
                  110,
                ),

                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 13,
                        ),

                        child: _buildGoalCard(
                          goals[index],
                          state.isSaving,
                        ),
                      );
                    },

                    childCount: goals.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}