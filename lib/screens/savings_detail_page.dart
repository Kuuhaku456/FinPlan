import 'dart:math';

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
const Color _orange = Color(0xFFF59E0B);

// =====================================================
// FORMAT TANGGAL
// =====================================================

const List<String> _months = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String _formatDate(DateTime date) {
  return '${date.day} '
      '${_months[date.month - 1]} '
      '${date.year}';
}

// =====================================================
// INPUT FORMAT RUPIAH
// =====================================================

class _RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      formatted.write(digits[i]);

      final remaining = digits.length - i - 1;

      if (remaining > 0 && remaining % 3 == 0) {
        formatted.write('.');
      }
    }

    final result = formatted.toString();

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(
        offset: result.length,
      ),
    );
  }
}

// =====================================================
// SAVINGS DETAIL PAGE
// =====================================================

class SavingsDetailPage extends StatefulWidget {
  const SavingsDetailPage({
    super.key,
    required this.controller,
    required this.goalId,
    required this.onEditGoal,
  });

  final SavingsController controller;
  final String goalId;
  final ValueChanged<String> onEditGoal;

  @override
  State<SavingsDetailPage> createState() {
    return _SavingsDetailPageState();
  }
}

class _SavingsDetailPageState
    extends State<SavingsDetailPage> {
  // ===================================================
  // INITIAL STATE
  // ===================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _refreshData();
    });
  }

  @override
  void didUpdateWidget(
    covariant SavingsDetailPage oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.goalId != widget.goalId ||
        oldWidget.controller != widget.controller) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _refreshData();
      });
    }
  }

  // ===================================================
  // REFRESH
  // ===================================================

  Future<void> _refreshData() async {
    if (!mounted) return;

    await widget.controller.loadGoals();

    if (!mounted) return;

    final goal = widget.controller.goalById(
      widget.goalId,
    );

    if (goal == null) return;

    try {
      await widget.controller.loadMovementHistory(
        widget.goalId,
      );
    } catch (_) {
      // Kesalahan ditangani oleh controller.
    }
  }

  // ===================================================
  // BUKA FORM SETOR / AMBIL
  // ===================================================

  Future<void> _openMovementSheet(
    SavingsMovementType type,
  ) async {
    final goal = widget.controller.goalById(
      widget.goalId,
    );

    if (goal == null || goal.isArchived) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface,
      builder: (_) {
        return _SavingsMovementSheet(
          controller: widget.controller,
          goalId: widget.goalId,
          type: type,
        );
      },
    );

    if (!mounted || saved != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          type == SavingsMovementType.deposit
              ? 'Setoran berhasil dicatat.'
              : 'Pengambilan berhasil dicatat.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await _refreshData();
  }

  // ===================================================
  // KARTU PROGRESS UTAMA
  // ===================================================

  Widget _heroCard(SavingsGoal goal) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _darkGreen,
            _green,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER KANTONG

          Row(
            children: [
              Container(
                width: 57,
                height: 57,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(
                  goal.emoji,
                  style: const TextStyle(
                    fontSize: 30,
                  ),
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Text(
                  goal.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
              ),

              if (goal.isCompleted)
                const Icon(
                  Icons.verified_rounded,
                  color: _mint,
                ),
            ],
          ),

          const SizedBox(height: 26),

          // SALDO DAN LINGKARAN PROGRESS

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Terkumpul',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 7),

                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        rupiah(goal.savedAmount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 9),

                    Text(
                      'Target ${rupiah(goal.targetAmount)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              SizedBox(
                width: 103,
                height: 103,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 103,
                      height: 103,
                      child: CircularProgressIndicator(
                        value: goal.progress,
                        strokeWidth: 11,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation(
                          _mint,
                        ),
                      ),
                    ),

                    Text(
                      '${goal.progressPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 23),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.13,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Icon(
                  goal.isCompleted
                      ? Icons.emoji_events_outlined
                      : Icons.flag_outlined,
                  size: 20,
                  color: Colors.white,
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Text(
                    goal.isCompleted
                        ? '🎉 Target tercapai!'
                        : 'Sisa ${rupiah(goal.remainingAmount)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // KARTU INFORMASI
  // ===================================================

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: scheme.outlineVariant.withValues(
              alpha: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 21,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 5),

            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================
  // INFORMASI TARGET
  // ===================================================

  Widget _targetInfo(SavingsGoal goal) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _infoCard(
              icon: Icons.flag_outlined,
              label: 'Target',
              value: rupiah(goal.targetAmount),
              color: _green,
            ),

            const SizedBox(width: 11),

            _infoCard(
              icon: Icons.savings_outlined,
              label: 'Belum Terkumpul',
              value: rupiah(goal.remainingAmount),
              color: _orange,
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (goal.deadline != null)
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: scheme.primary,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    _formatDate(goal.deadline!),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                if (goal.daysRemaining != null)
                  Text(
                    goal.daysRemaining! >= 0
                        ? '${goal.daysRemaining} hari'
                        : 'Terlewat',
                    style: TextStyle(
                      color: goal.isOverdue
                          ? _red
                          : scheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),

        if (goal.description.trim().isNotEmpty) ...[
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              goal.description,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
          ),
        ],
      ],
    );
  }

  // ===================================================
  // ESTIMASI MENABUNG
  // ===================================================

  Widget _monthlyEstimate(SavingsGoal goal) {
    final scheme = Theme.of(context).colorScheme;

    final remainingDays = goal.daysRemaining ?? 0;

    String title;
    String description;
    String? amountText;

    if (goal.isCompleted) {
      title = 'Target Tercapai 🎉';
      description = 'Kerja bagus! Tujuanmu sudah tercapai.';
    } else if (remainingDays <= 0) {
      title = 'Deadline Terlewat';
      description = 'Coba perbarui tanggal target.';
    } else {
      final months = max(
        1,
        (remainingDays / 30.44).ceil(),
      );

      final monthlyAmount =
          (goal.remainingAmount / months).ceil();

      title = 'Saran Tabungan / Bulan';
      description = 'Perkiraan untuk $months bulan.';
      amountText = rupiah(monthlyAmount);
    }

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            goal.isCompleted
                ? Icons.emoji_events_outlined
                : Icons.auto_graph_rounded,
            color: scheme.onPrimaryContainer,
            size: 27,
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),

                if (amountText != null) ...[
                  const SizedBox(height: 7),

                  Text(
                    amountText,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],

                const SizedBox(height: 5),

                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // ITEM RIWAYAT
  // ===================================================

  Widget _movementTile(SavingsMovement movement) {
    final scheme = Theme.of(context).colorScheme;

    final isDeposit = movement.isDeposit;
    final color = isDeposit ? _green : _red;

    final title = movement.note.trim().isEmpty
        ? movement.type.label
        : movement.note;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isDeposit
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              color: color,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _formatDate(movement.date),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Text(
            '${isDeposit ? '+' : '-'}'
            '${rupiah(movement.amount)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // KOSONG / ERROR
  // ===================================================

  Widget _emptyHistory() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        100,
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 43,
            color: scheme.onSurfaceVariant,
          ),

          const SizedBox(height: 12),

          const Text(
            'Belum Ada Aktivitas',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Riwayat setoran dan pengambilan '
            'akan muncul di sini.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _missingGoal() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.savings_outlined,
              size: 55,
            ),

            const SizedBox(height: 14),

            const Text(
              'Kantong Tidak Ditemukan',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 18),

            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(String error) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: scheme.onErrorContainer,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ),

          IconButton(
            onPressed: widget.controller.clearError,
            icon: Icon(
              Icons.close_rounded,
              color: scheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // BOTTOM BUTTONS
  // ===================================================

  Widget _bottomActions(SavingsController controller) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        18,
        9,
        18,
        14,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: controller.isSaving
                  ? null
                  : () {
                      _openMovementSheet(
                        SavingsMovementType.withdrawal,
                      );
                    },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(
                Icons.remove_rounded,
              ),
              label: const Text('Ambil'),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: FilledButton.icon(
              onPressed: controller.isSaving
                  ? null
                  : () {
                      _openMovementSheet(
                        SavingsMovementType.deposit,
                      );
                    },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(
                Icons.add_rounded,
              ),
              label: const Text('Setor'),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // BUILD
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;

        final goal = controller.goalById(
          widget.goalId,
        );

        final scheme = Theme.of(context).colorScheme;

        if (goal == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Detail Kantong'),
            ),
            body: controller.isLoading ||
                    !controller.hasLoaded
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _missingGoal(),
          );
        }

        final history = controller.historyForGoal(
          goal.id,
        );

        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
            title: Text(
              goal.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Edit kantong',
                onPressed: goal.isArchived
                    ? null
                    : () {
                        widget.onEditGoal(goal.id);
                      },
                icon: const Icon(
                  Icons.edit_outlined,
                ),
              ),

              IconButton(
                tooltip: 'Perbarui',
                onPressed: _refreshData,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
              ),
            ],
          ),

          bottomNavigationBar: goal.isArchived
              ? null
              : _bottomActions(controller),

          body: RefreshIndicator(
            color: _green,
            onRefresh: _refreshData,
            child: CustomScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      18,
                      12,
                      18,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _heroCard(goal),

                        const SizedBox(height: 15),

                        _targetInfo(goal),

                        if (goal.deadline != null) ...[
                          const SizedBox(height: 15),
                          _monthlyEstimate(goal),
                        ],

                        if (goal.isArchived) ...[
                          const SizedBox(height: 15),

                          Container(
                            padding:
                                const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.archive_outlined,
                                ),

                                SizedBox(width: 10),

                                Expanded(
                                  child: Text(
                                    'Kantong diarsipkan. '
                                    'Pulihkan dari halaman Tabungan.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (controller.error != null) ...[
                          const SizedBox(height: 15),
                          _errorBanner(
                            controller.error!,
                          ),
                        ],

                        const SizedBox(height: 27),

                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Riwayat Tabungan',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.w800,
                                  fontSize: 19,
                                ),
                              ),
                            ),

                            Text(
                              '${history.length} aktivitas',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                          ],
                        ),

                        const SizedBox(height: 13),

                        if (controller.isLoadingHistory(
                          goal.id,
                        ))
                          const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                ),

                if (history.isEmpty)
                  SliverToBoxAdapter(
                    child: _emptyHistory(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      0,
                      18,
                      110,
                    ),
                    sliver: SliverList.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        return _movementTile(
                          history[index],
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
}

// =====================================================
// FORM SETOR / AMBIL
// =====================================================

class _SavingsMovementSheet extends StatefulWidget {
  const _SavingsMovementSheet({
    required this.controller,
    required this.goalId,
    required this.type,
  });

  final SavingsController controller;
  final String goalId;
  final SavingsMovementType type;

  @override
  State<_SavingsMovementSheet> createState() {
    return _SavingsMovementSheetState();
  }
}

class _SavingsMovementSheetState
    extends State<_SavingsMovementSheet> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late DateTime _selectedDate;

  bool _submitting = false;
  String? _error;

  bool get _isDeposit {
    return widget.type == SavingsMovementType.deposit;
  }

  @override
  void initState() {
    super.initState();

    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  // ===================================================
  // PILIH TANGGAL
  // ===================================================

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedDate = picked;
    });
  }

  // ===================================================
  // VALIDASI
  // ===================================================

  String? _validateAmount(String? value) {
    final amount = parseRupiah(value ?? '');

    if (amount <= 0) {
      return 'Nominal harus lebih dari Rp0.';
    }

    final goal = widget.controller.goalById(
      widget.goalId,
    );

    if (goal == null) {
      return 'Kantong tidak ditemukan.';
    }

    if (goal.isArchived) {
      return 'Kantong sedang diarsipkan.';
    }

    if (!_isDeposit && amount > goal.savedAmount) {
      return 'Nominal melebihi saldo kantong.';
    }

    return null;
  }

  // ===================================================
  // SIMPAN AKTIVITAS
  // ===================================================

  Future<void> _saveMovement() async {
    if (_submitting || widget.controller.isSaving) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amount = parseRupiah(
      _amountController.text,
    );

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_isDeposit) {
        await widget.controller.addSavings(
          widget.goalId,
          amount,
          note: _noteController.text.trim(),
          date: _selectedDate,
        );
      } else {
        await widget.controller.withdrawSavings(
          widget.goalId,
          amount,
          note: _noteController.text.trim(),
          date: _selectedDate,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  // ===================================================
  // UI BOTTOM SHEET
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final goal = widget.controller.goalById(
      widget.goalId,
    );

    final color = _isDeposit ? _green : _red;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // HEADER

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _isDeposit
                          ? Icons.add_rounded
                          : Icons.remove_rounded,
                      color: color,
                      size: 26,
                    ),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Text(
                      _isDeposit
                          ? 'Setor Tabungan'
                          : 'Ambil Tabungan',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 21,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 21),

              // SALDO

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius:
                      BorderRadius.circular(19),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo Saat Ini',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),

                    const SizedBox(height: 7),

                    Text(
                      rupiah(goal?.savedAmount ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 23,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // NOMINAL

              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                  _RupiahInputFormatter(),
                ],
                autovalidateMode:
                    AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  labelText: 'Nominal',
                  hintText: '100.000',
                  prefixText: 'Rp ',
                  prefixIcon: Icon(
                    Icons.payments_outlined,
                  ),
                ),
                validator: _validateAmount,
              ),

              const SizedBox(height: 15),

              // TANGGAL

              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(15),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Aktivitas',
                    prefixIcon: Icon(
                      Icons.calendar_today_outlined,
                    ),
                    suffixIcon: Icon(
                      Icons.edit_calendar_outlined,
                    ),
                  ),
                  child: Text(
                    _formatDate(_selectedDate),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // CATATAN

              TextFormField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  prefixIcon: Icon(
                    Icons.edit_note_outlined,
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),

                Text(
                  _error!,
                  style: TextStyle(
                    color: scheme.error,
                    fontSize: 12,
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // TOMBOL SIMPAN

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _submitting || widget.controller.isSaving
                          ? null
                          : _saveMovement,
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(54),
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isDeposit
                              ? Icons.add_rounded
                              : Icons.remove_rounded,
                        ),
                  label: Text(
                    _submitting
                        ? 'Menyimpan...'
                        : _isDeposit
                            ? 'Simpan Setoran'
                            : 'Simpan Pengambilan',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 13),

              Text(
                'Pencatatan ini hanya mengubah saldo '
                'virtual FinPlan, bukan saldo rekening bank.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}