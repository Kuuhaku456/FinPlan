import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../models/savings_goal.dart';
import '../state/savings_controller.dart';

// =====================================================
// WARNA FINPLAN
// =====================================================

const Color _darkGreen = Color(0xFF064E3B);
const Color _green = Color(0xFF059669);
const Color _mint = Color(0xFFA7F3D0);
const Color _red = Color(0xFFEF4444);
const Color _amber = Color(0xFFF59E0B);

// =====================================================
// FILTER DAN AKSI
// =====================================================

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

class SavingsPage extends StatefulWidget {
  const SavingsPage({
    super.key,
    required this.controller,
    required this.onCreateGoal,
    required this.onOpenGoal,
  });

  final SavingsController controller;
  final VoidCallback onCreateGoal;
  final ValueChanged<String> onOpenGoal;

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  _SavingsFilter _filter = _SavingsFilter.active;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!widget.controller.hasLoaded) {
        widget.controller.loadGoals();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SavingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        widget.controller.loadGoals();
      });
    }
  }

  // ===================================================
  // NOTIFIKASI
  // ===================================================

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

  // ===================================================
  // INPUT SETOR / AMBIL
  // ===================================================

  Future<_SavingsInput?> _askAmount({
    required SavingsGoal goal,
    required bool isDeposit,
  }) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<_SavingsInput>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, updateDialog) {
            final amount = parseRupiah(
              amountController.text,
            );

            final exceedsBalance =
                !isDeposit && amount > goal.savedAmount;

            final valid = amount > 0 && !exceedsBalance;

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
                      color: isDeposit ? _darkGreen : _red,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      isDeposit ? 'Setor Tabungan' : 'Ambil Tabungan',
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
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

                    TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) {
                        updateDialog(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Nominal',
                        prefixText: 'Rp ',
                        prefixIcon: const Icon(
                          Icons.payments_outlined,
                        ),
                        errorText: exceedsBalance
                            ? 'Melebihi saldo tabungan'
                            : null,
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: noteController,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
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
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Batal'),
                ),

                FilledButton(
                  onPressed: valid
                      ? () {
                          Navigator.of(dialogContext).pop(
                            _SavingsInput(
                              amount: amount,
                              note: noteController.text.trim(),
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

    amountController.dispose();
    noteController.dispose();

    return result;
  }

  Future<void> _changeBalance(
    SavingsGoal goal, {
    required bool isDeposit,
  }) async {
    if (widget.controller.isSaving || goal.isArchived) {
      return;
    }

    final input = await _askAmount(
      goal: goal,
      isDeposit: isDeposit,
    );

    if (input == null || !mounted) return;

    try {
      if (isDeposit) {
        await widget.controller.addSavings(
          goal.id,
          input.amount,
          note: input.note,
        );
      } else {
        await widget.controller.withdrawSavings(
          goal.id,
          input.amount,
          note: input.note,
        );
      }

      if (!mounted) return;

      _showMessage(
        isDeposit
            ? 'Berhasil menabung ${rupiah(input.amount)}'
            : 'Berhasil mengambil ${rupiah(input.amount)}',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Transaksi gagal: $error',
      );
    }
  }

  // ===================================================
  // AKSI ARSIP / RESTORE / HAPUS
  // ===================================================

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
      if (action == _GoalAction.archive) {
        await widget.controller.archiveGoal(goal.id);

        if (!mounted) return;

        _showMessage('Kantong berhasil diarsipkan.');
      } else if (action == _GoalAction.restore) {
        await widget.controller.restoreGoal(goal.id);

        if (!mounted) return;

        _showMessage('Kantong berhasil dipulihkan.');
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Gagal memperbarui kantong: $error',
      );
    }
  }

  Future<void> _confirmDelete(SavingsGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Kantong?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                '${goal.emoji} ${goal.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
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
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    try {
      final deleted =
          await widget.controller.deleteGoal(goal.id);

      if (!mounted) return;

      _showMessage(
        deleted
            ? 'Kantong berhasil dihapus.'
            : 'Kantong tidak ditemukan.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage('Gagal menghapus: $error');
    }
  }

  // ===================================================
  // HALAMAN UTAMA
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final scheme = Theme.of(context).colorScheme;

        final goals = _filter == _SavingsFilter.active
            ? controller.activeGoals
            : controller.archivedGoals;

        final initialLoading =
            controller.isLoading && !controller.hasLoaded;

        final initialError =
            controller.hasError && !controller.hasLoaded;

        return Scaffold(
          backgroundColor: scheme.surface,
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
                onPressed: controller.isLoading
                    ? null
                    : controller.refresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
              ),
            ],
          ),
          floatingActionButton:
              FloatingActionButton.extended(
            onPressed: controller.isSaving
                ? null
                : widget.onCreateGoal,
            backgroundColor: _green,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Kantong Baru'),
          ),
          body: RefreshIndicator(
            onRefresh: controller.refresh,
            color: _green,
            child: CustomScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              slivers: [
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
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),

                        const SizedBox(height: 16),

                        _summaryCard(controller),

                        const SizedBox(height: 26),

                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Kantong Kamu',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                              ),
                            ),

                            IconButton.filledTonal(
                              tooltip: 'Tambah kantong',
                              onPressed: widget.onCreateGoal,
                              icon: const Icon(
                                Icons.add_rounded,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        _filterWidget(controller),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                if (controller.error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      child: _errorBanner(
                        controller.error!,
                      ),
                    ),
                  ),

                if (initialLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (initialError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _errorState(),
                  )
                else if (goals.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      4,
                      18,
                      110,
                    ),
                    sliver: SliverList.builder(
                      itemCount: goals.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: 13,
                          ),
                          child: _goalCard(goals[index]),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===================================================
  // KARTU RINGKASAN TOTAL
  // ===================================================

  Widget _summaryCard(SavingsController controller) {
    final summary = controller.summary;

    final progress =
        summary.progress.clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [
            _darkGreen,
            _green,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
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
            alignment: Alignment.centerLeft,
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
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: _mint,
            ),
          ),

          const SizedBox(height: 23),

          const Divider(color: Colors.white24),

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
                  Icons.emoji_events_outlined,
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

  Widget _summaryMetric(
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
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

  // ===================================================
  // FILTER AKTIF / ARSIP
  // ===================================================

  Widget _filterWidget(SavingsController controller) {
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
              'Aktif (${controller.activeGoalCount})',
            ),
          ),

          ButtonSegment<_SavingsFilter>(
            value: _SavingsFilter.archived,
            icon: const Icon(
              Icons.archive_outlined,
              size: 18,
            ),
            label: Text(
              'Arsip (${controller.archivedGoalCount})',
            ),
          ),
        ],
        selected: {_filter},
        onSelectionChanged: (selection) {
          if (selection.isEmpty) return;

          setState(() {
            _filter = selection.first;
          });
        },
      ),
    );
  }

  // ===================================================
  // KARTU KANTONG
  // ===================================================

  Widget _goalCard(SavingsGoal goal) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final statusColor = goal.isCompleted
        ? _green
        : goal.isOverdue
            ? _amber
            : scheme.primary;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: () => widget.onOpenGoal(goal.id),
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
              // HEADER

              Row(
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(17),
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

                  _goalMenu(goal),
                ],
              ),

              const SizedBox(height: 19),

              // NOMINAL DAN PERSENTASE

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
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

              // STATUS DAN DEADLINE

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusBadge(
                    goal.statusLabel,
                    statusColor,
                  ),

                  if (goal.deadline != null)
                    _deadlineBadge(goal),
                ],
              ),

              const SizedBox(height: 17),

              // AKSI CEPAT

              if (!goal.isArchived)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            widget.controller.isSaving
                                ? null
                                : () => _changeBalance(
                                      goal,
                                      isDeposit: true,
                                    ),
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
                        onPressed:
                            widget.controller.isSaving ||
                                    goal.savedAmount <= 0
                                ? null
                                : () => _changeBalance(
                                      goal,
                                      isDeposit: false,
                                    ),
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

  // ===================================================
  // BADGE STATUS
  // ===================================================

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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
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

  Widget _deadlineBadge(SavingsGoal goal) {
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

    final scheme = Theme.of(context).colorScheme;

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

  // ===================================================
  // MENU KANTONG
  // ===================================================

  Widget _goalMenu(SavingsGoal goal) {
    return PopupMenuButton<_GoalAction>(
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
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.visibility_outlined,
            ),
            title: Text('Lihat Detail'),
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
              title: Text('Arsipkan'),
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
              title: Text('Pulihkan'),
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
              style: TextStyle(color: _red),
            ),
          ),
        ),
      ],
    );
  }

  // ===================================================
  // EMPTY STATE
  // ===================================================

  Widget _emptyState() {
    final scheme = Theme.of(context).colorScheme;
    final archived =
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
                archived
                    ? Icons.archive_outlined
                    : Icons.savings_outlined,
                size: 46,
                color: scheme.onPrimaryContainer,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              archived
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
              archived
                  ? 'Kantong yang diarsipkan '
                      'akan muncul di sini.'
                  : 'Buat kantong pertamamu '
                      'untuk mencapai target keuangan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),

            if (!archived) ...[
              const SizedBox(height: 22),

              FilledButton.icon(
                onPressed: widget.onCreateGoal,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Buat Kantong'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===================================================
  // ERROR STATE
  // ===================================================

  Widget _errorState() {
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
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 15),

            OutlinedButton.icon(
              onPressed: widget.controller.loadGoals,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
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
              message,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ),

          IconButton(
            tooltip: 'Tutup pesan',
            onPressed: widget.controller.clearError,
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
}