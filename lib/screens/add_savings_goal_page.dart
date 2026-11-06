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

// ==========================================
// EMOJI OPTIONS
// ==========================================

const _goalEmojis = [
  '🎯',
  '💍',
  '🏠',
  '🚗',
  '✈️',
  '📱',
  '💻',
  '🛡️',
  '🎓',
  '🏖️',
  '🎁',
  '🏦',
  '🚲',
  '🏥',
  '🍼',
  '🧳',
  '❤️',
  '💡',
  '🎮',
  '💰',
];

// ==========================================
// DATE FORMAT
// ==========================================

const _months = [
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

// ==========================================
// RUPIAH FORMATTER
// ==========================================

String _formatDigits(String input) {
  final digits = input.replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );

  if (digits.isEmpty) return '';

  final result = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    result.write(digits[i]);

    final remaining = digits.length - i - 1;

    if (remaining > 0 && remaining % 3 == 0) {
      result.write('.');
    }
  }

  return result.toString();
}

class _SavingsRupiahFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _formatDigits(
      newValue.text,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
  }
}

// ==========================================
// ADD / EDIT SAVINGS GOAL PAGE
// ==========================================

class AddSavingsGoalPage
    extends ConsumerStatefulWidget {
  const AddSavingsGoalPage({
    super.key,
    required this.controller,
    this.goalId,
  });

  // Dipertahankan agar main.dart
  // tetap kompatibel selama migrasi.
  final SavingsController controller;

  final String? goalId;

  @override
  ConsumerState<AddSavingsGoalPage> createState() {
    return _AddSavingsGoalPageState();
  }
}

class _AddSavingsGoalPageState
    extends ConsumerState<AddSavingsGoalPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  final _descriptionController =
      TextEditingController();

  final _targetController =
      TextEditingController();

  final _initialAmountController =
      TextEditingController();

  String _selectedEmoji = '🎯';

  DateTime? _deadline;

  bool _isSaving = false;
  bool _isLoadingExisting = false;

  String? _loadError;
  String? _saveError;

  SavingsGoal? _existingGoal;

  bool get _isEditing => widget.goalId != null;

  // ========================================
  // INITIALIZATION
  // ========================================

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final existing = ref
          .read(savingsStateProvider.notifier)
          .goalById(widget.goalId!);

      if (existing != null) {
        _populateForm(existing);
      } else {
        _isLoadingExisting = true;

        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            if (mounted) {
              _loadExistingGoal();
            }
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _initialAmountController.dispose();

    super.dispose();
  }

  // ========================================
  // POPULATE FORM FOR EDIT
  // ========================================

  void _populateForm(SavingsGoal goal) {
    _existingGoal = goal;

    _nameController.text = goal.name;

    _descriptionController.text =
        goal.description;

    _targetController.text = _formatDigits(
      goal.targetAmount.toString(),
    );

    _selectedEmoji = goal.emoji;
    _deadline = goal.deadline;
  }

  // ========================================
  // LOAD EXISTING GOAL
  // ========================================

  Future<void> _loadExistingGoal() async {
    if (!_isEditing) return;

    try {
      final notifier = ref.read(
        savingsStateProvider.notifier,
      );

      await notifier.loadGoals();

      if (!mounted) return;

      final goal = notifier.goalById(
        widget.goalId!,
      );

      setState(() {
        _isLoadingExisting = false;

        if (goal == null) {
          _loadError =
              ref.read(savingsStateProvider).error ??
                  'Kantong tidak ditemukan.';
        } else {
          _populateForm(goal);
          _loadError = null;
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingExisting = false;
        _loadError = 'Gagal memuat kantong.';
      });
    }
  }

  // ========================================
  // DATE PICKER
  // ========================================

  Future<void> _pickDeadline() async {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final lastDate = DateTime(
      today.year + 30,
      12,
      31,
    );

    final initialDate = _deadline != null &&
            !_deadline!.isBefore(today) &&
            !_deadline!.isAfter(lastDate)
        ? _deadline!
        : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: lastDate,
      helpText: 'Pilih Tanggal Target',
    );

    if (picked != null && mounted) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  // ========================================
  // VALIDATION
  // ========================================

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Nama kantong wajib diisi.';
    }

    if (name.length > 40) {
      return 'Nama maksimal 40 karakter.';
    }

    return null;
  }

  String? _validateTarget(String? value) {
    final amount = parseRupiah(value ?? '');

    if (amount <= 0) {
      return 'Target harus lebih dari Rp0.';
    }

    return null;
  }

  // ========================================
  // SAVE GOAL USING RIVERPOD
  // ========================================

  Future<void> _saveGoal() async {
    if (_isSaving ||
        ref.read(savingsStateProvider).isSaving) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();

    final description =
        _descriptionController.text.trim();

    final targetAmount = parseRupiah(
      _targetController.text,
    );

    final initialAmount = parseRupiah(
      _initialAmountController.text,
    );

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final notifier = ref.read(
        savingsStateProvider.notifier,
      );

      if (_isEditing) {
        // =================================
        // EDIT EXISTING GOAL
        // =================================

        final existing = notifier.goalById(
              widget.goalId!,
            ) ??
            _existingGoal;

        if (existing == null) {
          throw StateError(
            'Kantong tidak ditemukan.',
          );
        }

        final updatedGoal = existing.copyWith(
          name: name,
          emoji: _selectedEmoji,
          description: description,
          targetAmount: targetAmount,
          deadline: _deadline,
        );

        // Saldo dan riwayat lama tetap ada.
        await notifier.updateGoal(
          updatedGoal,
        );
      } else {
        // =================================
        // CREATE NEW GOAL
        // =================================

        final newGoal = SavingsGoal.create(
          name: name,
          emoji: _selectedEmoji,
          description: description,
          targetAmount: targetAmount,
          initialAmount: initialAmount,
          deadline: _deadline,
        );

        await notifier.createGoal(
          newGoal,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _saveError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ========================================
  // SECTION CARD
  // ========================================

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(
            alpha: 0.55,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: scheme.primary,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          ...children,
        ],
      ),
    );
  }

  // ========================================
  // LIVE PREVIEW
  // ========================================

  Widget _previewCard() {
    final name =
        _nameController.text.trim().isEmpty
            ? 'Kantong Impian'
            : _nameController.text.trim();

    final target = parseRupiah(
      _targetController.text,
    );

    final saved = _isEditing
        ? (_existingGoal?.savedAmount ?? 0)
        : parseRupiah(
            _initialAmountController.text,
          );

    final progress = target <= 0
        ? 0.0
        : (saved / target).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
          Row(
            children: [
              Container(
                width: 59,
                height: 59,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  _selectedEmoji,
                  style: const TextStyle(
                    fontSize: 30,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KANTONG TABUNGAN',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white70,
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text(
            'Target Tabungan',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 6),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(target),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 29,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 20),

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
                '${(progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: _mint,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white24,
              color: _mint,
            ),
          ),

          const SizedBox(height: 11),

          Text(
            'Terkumpul ${rupiah(saved)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // BASIC INFORMATION
  // ========================================

  Widget _basicInformation() {
    return _sectionCard(
      title: 'Informasi Kantong',
      icon: Icons.edit_note_rounded,
      children: [
        TextFormField(
          controller: _nameController,
          maxLength: 40,
          autovalidateMode:
              AutovalidateMode.onUserInteraction,
          textCapitalization:
              TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama Kantong',
            hintText: 'Contoh: Dana Pernikahan',
            prefixIcon: Icon(
              Icons.savings_outlined,
            ),
          ),
          validator: _validateName,
          onChanged: (_) {
            setState(() {});
          },
        ),

        const SizedBox(height: 11),

        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          maxLength: 180,
          decoration: const InputDecoration(
            labelText: 'Deskripsi (Opsional)',
            hintText: 'Ceritakan tujuan tabunganmu',
            alignLabelWithHint: true,
            prefixIcon: Icon(
              Icons.description_outlined,
            ),
          ),
        ),
      ],
    );
  }

  // ========================================
  // EMOJI SELECTOR
  // ========================================

  Widget _emojiSelector() {
    final scheme = Theme.of(context).colorScheme;

    return _sectionCard(
      title: 'Pilih Ikon',
      icon: Icons.emoji_emotions_outlined,
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: _goalEmojis.map((emoji) {
            final selected = _selectedEmoji == emoji;

            return InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () {
                setState(() {
                  _selectedEmoji = emoji;
                });
              },
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(15),
                  border: Border.all(
                    color: selected
                        ? scheme.primary
                        : Colors.transparent,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  emoji,
                  style: const TextStyle(
                    fontSize: 25,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ========================================
  // TARGET SECTION
  // ========================================

  Widget _targetSection() {
    const presets = [
      500000,
      1000000,
      5000000,
      10000000,
    ];

    final selectedTarget = parseRupiah(
      _targetController.text,
    );

    return _sectionCard(
      title: 'Target Tabungan',
      icon: Icons.flag_outlined,
      children: [
        TextFormField(
          controller: _targetController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
            _SavingsRupiahFormatter(),
          ],
          autovalidateMode:
              AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            labelText: 'Nominal Target',
            hintText: 'Contoh: 5.000.000',
            prefixText: 'Rp ',
            prefixIcon: Icon(
              Icons.payments_outlined,
            ),
          ),
          validator: _validateTarget,
          onChanged: (_) {
            setState(() {});
          },
        ),

        const SizedBox(height: 14),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((value) {
            final selected =
                selectedTarget == value;

            final label = value >= 1000000
                ? '${value ~/ 1000000}jt'
                : '${value ~/ 1000}rb';

            return ChoiceChip(
              label: Text(label),
              selected: selected,
              showCheckmark: false,
              selectedColor: _mint,
              onSelected: (_) {
                setState(() {
                  _targetController.text =
                      _formatDigits(
                    value.toString(),
                  );
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ========================================
  // INITIAL AMOUNT
  // ========================================

  Widget _initialAmountSection() {
    return _sectionCard(
      title: 'Saldo Awal',
      icon: Icons.account_balance_wallet_outlined,
      children: [
        TextFormField(
          controller: _initialAmountController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
            _SavingsRupiahFormatter(),
          ],
          decoration: const InputDecoration(
            labelText: 'Tabungan yang Sudah Ada',
            hintText: '0',
            prefixText: 'Rp ',
            prefixIcon: Icon(
              Icons.savings_rounded,
            ),
          ),
          onChanged: (_) {
            setState(() {});
          },
        ),
      ],
    );
  }

  // ========================================
  // DEADLINE SECTION
  // ========================================

  Widget _deadlineSection() {
    final scheme = Theme.of(context).colorScheme;

    return _sectionCard(
      title: 'Tanggal Target',
      icon: Icons.calendar_month_outlined,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickDeadline,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: scheme.outlineVariant,
                ),
                borderRadius:
                    BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    color: scheme.primary,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      _deadline == null
                          ? 'Pilih Tanggal (Opsional)'
                          : _formatDate(_deadline!),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  Icon(
                    Icons.edit_calendar_outlined,
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_deadline != null) ...[
          const SizedBox(height: 7),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _deadline = null;
                });
              },
              icon: const Icon(
                Icons.close_rounded,
                size: 17,
              ),
              label: const Text('Hapus Tanggal'),
            ),
          ),
        ],
      ],
    );
  }

  // ========================================
  // EDIT INFORMATION
  // ========================================

  Widget _editInfo() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: scheme.onPrimaryContainer,
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              'Perubahan target tidak menghapus '
              'saldo dan riwayat tabungan.',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // LOAD ERROR
  // ========================================

  Widget _buildLoadError() {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: scheme.error,
            ),

            const SizedBox(height: 16),

            Text(
              _loadError ?? 'Gagal memuat kantong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 19),

            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoadingExisting = true;
                  _loadError = null;
                });

                _loadExistingGoal();
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

  // ========================================
  // SAVE BUTTON
  // ========================================

  Widget _saveButton(bool isSaving) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        14,
      ),
      child: SizedBox(
        height: 55,
        child: FilledButton.icon(
          onPressed: _isSaving || isSaving
              ? null
              : _saveGoal,
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  _isEditing
                      ? Icons.save_outlined
                      : Icons.add_circle_outline_rounded,
                ),
          label: Text(
            _isSaving
                ? 'Menyimpan...'
                : _isEditing
                    ? 'Simpan Perubahan'
                    : 'Buat Kantong',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  // ========================================
  // BUILD - RIVERPOD
  // ========================================

  @override
  Widget build(BuildContext context) {
    // Hanya pantau status penyimpanan.
    final isSaving = ref.watch(
      savingsStateProvider.select(
        (state) => state.isSaving,
      ),
    );

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,

      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Edit Kantong'
              : 'Buat Kantong Baru',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      bottomNavigationBar:
          _isLoadingExisting || _loadError != null
              ? null
              : _saveButton(isSaving),

      body: _isLoadingExisting
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _loadError != null
              ? _buildLoadError()
              : SafeArea(
                  child: Form(
                    key: _formKey,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 700,
                        ),
                        child: ListView(
                          padding:
                              const EdgeInsets.fromLTRB(
                            18,
                            12,
                            18,
                            30,
                          ),
                          children: [
                            // HEADER
                            Text(
                              _isEditing
                                  ? 'Edit Target 🎯'
                                  : 'Target Baru ✨',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                            ),

                            const SizedBox(height: 17),

                            // LIVE PREVIEW
                            _previewCard(),

                            const SizedBox(height: 24),

                            // BASIC INFORMATION
                            _basicInformation(),

                            const SizedBox(height: 17),

                            // EMOJI
                            _emojiSelector(),

                            const SizedBox(height: 17),

                            // TARGET
                            _targetSection(),

                            // INITIAL BALANCE
                            if (!_isEditing) ...[
                              const SizedBox(height: 17),
                              _initialAmountSection(),
                            ],

                            const SizedBox(height: 17),

                            // DEADLINE
                            _deadlineSection(),

                            // EDIT INFORMATION
                            if (_isEditing) ...[
                              const SizedBox(height: 16),
                              _editInfo(),
                            ],

                            // ERROR
                            if (_saveError != null) ...[
                              const SizedBox(height: 17),

                              Container(
                                padding:
                                    const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer,
                                  borderRadius:
                                      BorderRadius.circular(15),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color:
                                          scheme.onErrorContainer,
                                    ),

                                    const SizedBox(width: 10),

                                    Expanded(
                                      child: Text(
                                        _saveError!,
                                        style: TextStyle(
                                          color: scheme
                                              .onErrorContainer,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}