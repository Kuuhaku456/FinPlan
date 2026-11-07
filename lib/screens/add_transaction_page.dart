import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../models/finance_transaction.dart';
import '../models/transaction_category.dart';
import '../state/transaction_controller.dart';
import '../state/transaction_notifier.dart';

// ==========================================
// FINPLAN COLORS
// ==========================================

const _darkGreen = Color(0xFF064E3B);
const _green = Color(0xFF059669);

// ==========================================
// FORM UI STATE
// ==========================================

@immutable
class _TransactionFormValues {
  const _TransactionFormValues({
    required this.date,
    required this.type,
    required this.category,
    required this.accountType,
    required this.selectedAccount,
    required this.isCustomAccount,
    this.isSaving = false,
  });

  final DateTime date;
  final TransactionType type;
  final TransactionCategory category;
  final AccountType accountType;
  final String selectedAccount;
  final bool isCustomAccount;
  final bool isSaving;

  _TransactionFormValues copyWith({
    DateTime? date,
    TransactionType? type,
    TransactionCategory? category,
    AccountType? accountType,
    String? selectedAccount,
    bool? isCustomAccount,
    bool? isSaving,
  }) {
    return _TransactionFormValues(
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      accountType: accountType ?? this.accountType,
      selectedAccount:
          selectedAccount ?? this.selectedAccount,
      isCustomAccount:
          isCustomAccount ?? this.isCustomAccount,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

// ==========================================
// ADD / EDIT TRANSACTION PAGE
// ==========================================

class AddTransactionPage
    extends ConsumerStatefulWidget {
  const AddTransactionPage({
    super.key,
    required this.controller,
    this.transaction,
  });

  // Dipertahankan untuk kompatibilitas
  // dengan halaman Transaksi sebelumnya.
  final TransactionController controller;

  final FinanceTransaction? transaction;

  @override
  ConsumerState<AddTransactionPage> createState() {
    return _AddTransactionPageState();
  }
}

class _AddTransactionPageState
    extends ConsumerState<AddTransactionPage> {
  static const String _customValue = '__custom__';

  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();

  final _descriptionController =
      TextEditingController();

  final _customAccountController =
      TextEditingController();

  late final ValueNotifier<_TransactionFormValues>
      _form;

  late final Listenable _formListenable;

  bool get _isEditing => widget.transaction != null;

  static const _months = [
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

  // ========================================
  // ACCOUNT OPTIONS
  // ========================================

  List<String> _accountOptions(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return const [
          'BCA',
          'BRI',
          'BNI',
          'Mandiri',
          'CIMB Niaga',
          'Permata',
          'Jago',
          'Krom Bank',
          'SeaBank',
          'blu',
        ];

      case AccountType.eMoney:
        return const [
          'DANA',
          'GoPay',
          'OVO',
          'ShopeePay',
          'LinkAja',
          'i.saku',
        ];

      case AccountType.cash:
        return const ['Tunai'];

      case AccountType.other:
        return const [];
    }
  }

  // ========================================
  // INITIALIZATION
  // ========================================

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;
    final today = DateTime.now();

    final selectedDate = transaction?.date ??
        DateTime(
          today.year,
          today.month,
          today.day,
        );

    final accountType =
        transaction?.accountType ?? AccountType.bank;

    final options = _accountOptions(accountType);

    String selectedAccount;
    bool isCustomAccount;

    if (transaction != null &&
        options.contains(transaction.accountName)) {
      selectedAccount = transaction.accountName;
      isCustomAccount = false;
    } else if (transaction != null) {
      selectedAccount = _customValue;
      isCustomAccount = true;

      _customAccountController.text =
          transaction.accountName;
    } else if (options.isNotEmpty) {
      selectedAccount = options.first;
      isCustomAccount = false;
    } else {
      selectedAccount = _customValue;
      isCustomAccount = true;
    }

    _amountController.text =
        transaction?.amount.toString() ?? '';

    _descriptionController.text =
        transaction?.description ?? '';

    _form = ValueNotifier(
      _TransactionFormValues(
        date: selectedDate,
        type: transaction?.type ??
            TransactionType.expense,
        category: transaction?.category ??
            TransactionCategory.other,
        accountType: accountType,
        selectedAccount: selectedAccount,
        isCustomAccount: isCustomAccount,
      ),
    );

    // Memperbarui preview tanpa setState().
    _formListenable = Listenable.merge([
      _form,
      _amountController,
      _descriptionController,
      _customAccountController,
    ]);
  }

  @override
  void dispose() {
    _form.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _customAccountController.dispose();

    super.dispose();
  }

  // ========================================
  // FORMAT DATE
  // ========================================

  String _formatDate(DateTime date) {
    return '${date.day} '
        '${_months[date.month - 1]} '
        '${date.year}';
  }

  // ========================================
  // SELECT DATE
  // ========================================

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _form.value.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal transaksi',
    );

    if (selected == null || !mounted) return;

    _form.value = _form.value.copyWith(
      date: selected,
    );
  }

  // ========================================
  // CHANGE ACCOUNT TYPE
  // ========================================

  void _changeAccountType(AccountType type) {
    final options = _accountOptions(type);

    _customAccountController.clear();

    _form.value = _form.value.copyWith(
      accountType: type,
      selectedAccount:
          options.isNotEmpty ? options.first : _customValue,
      isCustomAccount: options.isEmpty,
    );
  }

  // ========================================
  // ACCOUNT NAME
  // ========================================

  String _effectiveAccountName(
    _TransactionFormValues values,
  ) {
    if (values.isCustomAccount ||
        values.accountType == AccountType.other) {
      return _customAccountController.text.trim();
    }

    return values.selectedAccount;
  }

  // ========================================
  // MESSAGE
  // ========================================

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

  // ========================================
  // SAVE TRANSACTION
  // ========================================

  Future<void> _saveTransaction() async {
    final values = _form.value;

    if (values.isSaving ||
        ref.read(transactionStateProvider).isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amount = parseRupiah(
      _amountController.text,
    );

    if (amount <= 0) {
      _showMessage(
        'Nominal harus lebih dari Rp0.',
      );
      return;
    }

    final accountName = _effectiveAccountName(values);

    if (accountName.isEmpty) {
      _showMessage(
        'Nama akun harus diisi.',
      );
      return;
    }

    _form.value = values.copyWith(
      isSaving: true,
    );

    try {
      final notifier = ref.read(
        transactionStateProvider.notifier,
      );

      final description =
          _descriptionController.text.trim();

      // Kategori pengeluaran tidak digunakan
      // untuk transaksi pemasukan.
      final category =
          values.type == TransactionType.income
              ? TransactionCategory.other
              : values.category;

      if (_isEditing) {
        // ==============================
        // EDIT TRANSACTION
        // ==============================

        final updatedTransaction =
            widget.transaction!.copyWith(
          date: values.date,
          amount: amount,
          type: values.type,
          category: category,
          accountType: values.accountType,
          accountName: accountName,
          description: description,
        );

        final success = await notifier.updateTransaction(
          updatedTransaction,
        );

        if (!success) {
          throw StateError(
            'Transaksi tidak ditemukan.',
          );
        }
      } else {
        // ==============================
        // ADD TRANSACTION
        // ==============================

        final transaction = FinanceTransaction(
          date: values.date,
          amount: amount,
          type: values.type,
          category: category,
          accountType: values.accountType,
          accountName: accountName,
          description: description,
        );

        await notifier.addTransaction(
          transaction,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Gagal menyimpan transaksi: $error',
      );
    } finally {
      if (mounted) {
        _form.value = _form.value.copyWith(
          isSaving: false,
        );
      }
    }
  }

  // ========================================
  // CARD COMPONENT
  // ========================================

  Widget _card(Widget child) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant,
        ),
      ),
      child: child,
    );
  }

  // ========================================
  // SECTION TITLE
  // ========================================

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // TRANSACTION PREVIEW
  // ========================================

  Widget _previewCard(
    _TransactionFormValues values,
  ) {
    final isIncome =
        values.type == TransactionType.income;

    final amount = parseRupiah(
      _amountController.text,
    );

    final description =
        _descriptionController.text.trim();

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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.17,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isIncome
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isIncome ? 'Uang Masuk' : 'Uang Keluar',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 19),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${isIncome ? '+' : '-'}${rupiah(amount)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _formatDate(values.date),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          if (!isIncome) ...[
            const SizedBox(height: 9),
            Text(
              '${values.category.emoji} '
              '${values.category.label}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========================================
  // TRANSACTION TYPE SELECTOR
  // ========================================

  Widget _typeSelector(
    _TransactionFormValues values,
  ) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TransactionType>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<TransactionType>(
            value: TransactionType.expense,
            icon: Icon(Icons.arrow_upward_rounded),
            label: Text('Pengeluaran'),
          ),
          ButtonSegment<TransactionType>(
            value: TransactionType.income,
            icon: Icon(Icons.arrow_downward_rounded),
            label: Text('Pemasukan'),
          ),
        ],
        selected: {values.type},
        onSelectionChanged: (selection) {
          if (selection.isEmpty) return;

          _form.value = _form.value.copyWith(
            type: selection.first,
          );
        },
      ),
    );
  }

  // ========================================
  // AMOUNT FIELD
  // ========================================

  Widget _amountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
      decoration: const InputDecoration(
        labelText: 'Nominal Transaksi',
        hintText: 'Contoh: 25000',
        prefixText: 'Rp ',
        prefixIcon: Icon(
          Icons.payments_outlined,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Masukkan nominal transaksi.';
        }

        if (parseRupiah(value) <= 0) {
          return 'Nominal harus lebih dari Rp0.';
        }

        return null;
      },
    );
  }

  // ========================================
  // QUICK AMOUNT SELECTOR
  // ========================================

  Widget _quickAmounts() {
    const amounts = [
      10000,
      25000,
      50000,
      100000,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: amounts.map((amount) {
        final selected =
            parseRupiah(_amountController.text) == amount;

        return ChoiceChip(
          label: Text('${amount ~/ 1000}rb'),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) {
            _amountController.text = amount.toString();
          },
        );
      }).toList(),
    );
  }

  // ========================================
  // DATE FIELD
  // ========================================

  Widget _dateField(
    _TransactionFormValues values,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: scheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tanggal Transaksi',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(values.date),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_calendar_outlined,
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // CATEGORY FIELD
  // ========================================

  Widget _categoryField(
    _TransactionFormValues values,
  ) {
    return DropdownButtonFormField<TransactionCategory>(
      key: ValueKey(
        'category_${values.type.name}',
      ),
      initialValue: values.category,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Kategori Pengeluaran',
        prefixIcon: Icon(
          Icons.category_outlined,
        ),
      ),
      items: [
        for (final category in TransactionCategory.values)
          DropdownMenuItem<TransactionCategory>(
            value: category,
            child: Text(
              '${category.emoji}  ${category.label}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (category) {
        if (category == null) return;

        _form.value = _form.value.copyWith(
          category: category,
        );
      },
    );
  }

  // ========================================
  // ACCOUNT TYPE ICON
  // ========================================

  IconData _accountIcon(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return Icons.account_balance_outlined;

      case AccountType.eMoney:
        return Icons.account_balance_wallet_outlined;

      case AccountType.cash:
        return Icons.payments_outlined;

      case AccountType.other:
        return Icons.more_horiz_rounded;
    }
  }

  // ========================================
  // ACCOUNT TYPE SELECTOR
  // ========================================

  Widget _accountTypeSelector(
    _TransactionFormValues values,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in AccountType.values)
          ChoiceChip(
            avatar: Icon(
              _accountIcon(type),
              size: 17,
            ),
            label: Text(type.label),
            selected: values.accountType == type,
            showCheckmark: false,
            onSelected: (_) {
              _changeAccountType(type);
            },
          ),
      ],
    );
  }

  // ========================================
  // ACCOUNT FIELD
  // ========================================

  Widget _accountField(
    _TransactionFormValues values,
  ) {
    final options = _accountOptions(
      values.accountType,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (options.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey(
              'account_${values.accountType.name}',
            ),
            initialValue: values.isCustomAccount
                ? _customValue
                : values.selectedAccount,
            isExpanded: true,
            decoration: InputDecoration(
              labelText:
                  values.type == TransactionType.income
                      ? 'Akun Penerima'
                      : 'Akun Pembayaran',
              prefixIcon: const Icon(
                Icons.account_balance_wallet_outlined,
              ),
            ),
            items: [
              for (final account in options)
                DropdownMenuItem<String>(
                  value: account,
                  child: Text(account),
                ),
              const DropdownMenuItem<String>(
                value: _customValue,
                child: Text('+ Tambah Akun Sendiri'),
              ),
            ],
            onChanged: (selected) {
              if (selected == null) return;

              _form.value = _form.value.copyWith(
                selectedAccount: selected,
                isCustomAccount:
                    selected == _customValue,
              );
            },
          ),

        if (values.isCustomAccount ||
            values.accountType == AccountType.other) ...[
          if (options.isNotEmpty)
            const SizedBox(height: 13),

          TextFormField(
            controller: _customAccountController,
            textCapitalization:
                TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama Akun',
              hintText: 'Contoh: Bank daerah',
              prefixIcon: Icon(
                Icons.edit_outlined,
              ),
            ),
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Nama akun wajib diisi.';
              }

              return null;
            },
          ),
        ],
      ],
    );
  }

  // ========================================
  // DESCRIPTION FIELD
  // ========================================

  Widget _descriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      maxLength: 250,
      textCapitalization:
          TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Deskripsi',
        hintText: 'Contoh: Makan siang',
        alignLabelWithHint: true,
        prefixIcon: Icon(
          Icons.edit_note_outlined,
        ),
      ),
      validator: (value) {
        if (value == null ||
            value.trim().isEmpty) {
          return 'Deskripsi wajib diisi.';
        }

        return null;
      },
    );
  }

  // ========================================
  // MAIN PAGE
  // ========================================

  @override
  Widget build(BuildContext context) {
    final isSavingFromProvider = ref.watch(
      transactionStateProvider.select(
        (state) => state.isSaving,
      ),
    );

    return AnimatedBuilder(
      animation: _formListenable,
      builder: (context, _) {
        final values = _form.value;

        final isIncome =
            values.type == TransactionType.income;

        final isSaving =
            values.isSaving || isSavingFromProvider;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _isEditing
                  ? 'Edit Transaksi'
                  : 'Tambah Transaksi',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(
              18,
              8,
              18,
              14,
            ),
            child: SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed:
                    isSaving ? null : _saveTransaction,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_outline_rounded,
                      ),
                label: Text(
                  isSaving
                      ? 'Menyimpan...'
                      : _isEditing
                          ? 'Simpan Perubahan'
                          : 'Simpan Transaksi',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),

          body: SafeArea(
            child: Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 700,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      12,
                      18,
                      26,
                    ),
                    children: [
                      // =========================
                      // TRANSACTION PREVIEW
                      // =========================

                      _previewCard(values),

                      const SizedBox(height: 26),

                      // =========================
                      // TRANSACTION TYPE
                      // =========================

                      _sectionTitle(
                        'Jenis Transaksi',
                        isIncome
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                      ),

                      _typeSelector(values),

                      const SizedBox(height: 25),

                      // =========================
                      // AMOUNT & DATE
                      // =========================

                      _sectionTitle(
                        'Detail Transaksi',
                        Icons.payments_outlined,
                      ),

                      _card(
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _amountField(),

                            const SizedBox(height: 13),

                            _quickAmounts(),

                            const SizedBox(height: 18),

                            _dateField(values),
                          ],
                        ),
                      ),

                      // =========================
                      // CATEGORY
                      // =========================

                      if (!isIncome) ...[
                        const SizedBox(height: 25),

                        _sectionTitle(
                          'Kategori Pengeluaran',
                          Icons.category_outlined,
                        ),

                        _card(
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _categoryField(values),

                              const SizedBox(height: 12),

                              Text(
                                values.category.description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),

                              if (values.category ==
                                  TransactionCategory.savings) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Catatan: Alokasi tabungan yang '
                                  'dicatat sebagai Pengeluaran masih '
                                  'masuk dalam total pengeluaran. '
                                  'Fitur transfer antar-kantong '
                                  'akan dipisahkan pada tahap berikutnya.',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 25),

                      // =========================
                      // ACCOUNT
                      // =========================

                      _sectionTitle(
                        'Sumber Dana',
                        Icons.account_balance_wallet_outlined,
                      ),

                      _card(
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _accountTypeSelector(values),

                            const SizedBox(height: 16),

                            _accountField(values),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // =========================
                      // DESCRIPTION
                      // =========================

                      _sectionTitle(
                        'Keterangan',
                        Icons.edit_note_outlined,
                      ),

                      _card(
                        _descriptionField(),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 17,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              'Transaksi dicatat di perangkat ini.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}