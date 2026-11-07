import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../models/finance_transaction.dart';

import '../state/transaction_controller.dart';
import '../state/transaction_notifier.dart';

// =====================================================
// FINPLAN - ADD / EDIT TRANSACTION PAGE
// =====================================================

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({
    super.key,
    this.controller,
    this.transaction,
  });

  // Kompatibilitas sementara dengan TransactionsPage lama.
  // Penyimpanan sekarang menggunakan Riverpod.
  final TransactionController? controller;

  final FinanceTransaction? transaction;

  @override
  ConsumerState<AddTransactionPage> createState() {
    return _AddTransactionPageState();
  }
}

class _AddTransactionPageState
    extends ConsumerState<AddTransactionPage> {

  // =====================================================
  // COLORS
  // =====================================================

  static const Color _darkGreen = Color(0xFF064E3B);
  static const Color _green = Color(0xFF059669);

  static const String _customValue = '__custom__';

  static const List<String> _months = [
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

  // =====================================================
  // FORM CONTROLLERS
  // =====================================================

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _amountController =
      TextEditingController();

  final TextEditingController _descriptionController =
      TextEditingController();

  final TextEditingController _customAccountController =
      TextEditingController();

  // =====================================================
  // FORM STATE
  // =====================================================

  late DateTime _selectedDate;

  TransactionType _transactionType =
      TransactionType.expense;

  AccountType _accountType = AccountType.bank;

  String _selectedAccount = 'BCA';

  bool _isCustomAccount = false;

  bool _saving = false;

  bool get _editing => widget.transaction != null;

  // =====================================================
  // ACCOUNT OPTIONS
  // =====================================================

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
        return const [
          'Tunai',
        ];

      case AccountType.other:
        return const [];
    }
  }

  // =====================================================
  // INIT STATE
  // =====================================================

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    final now = DateTime.now();

    // Tanggal default adalah hari ini.
    _selectedDate = transaction?.date ??
        DateTime(
          now.year,
          now.month,
          now.day,
        );

    _transactionType =
        transaction?.type ?? TransactionType.expense;

    _accountType =
        transaction?.accountType ?? AccountType.bank;

    _amountController.text =
        transaction?.amount.toString() ?? '';

    _descriptionController.text =
        transaction?.description ?? '';

    _initializeAccount(transaction);
  }

  // =====================================================
  // INITIALIZE ACCOUNT
  // =====================================================

  void _initializeAccount(
    FinanceTransaction? transaction,
  ) {
    final options = _accountOptions(_accountType);

    if (transaction == null) {
      if (options.isNotEmpty) {
        _selectedAccount = options.first;
        _isCustomAccount = false;
      } else {
        _selectedAccount = _customValue;
        _isCustomAccount = true;
      }

      return;
    }

    if (options.contains(transaction.accountName)) {
      _selectedAccount = transaction.accountName;
      _isCustomAccount = false;
    } else {
      _selectedAccount = _customValue;
      _isCustomAccount = true;

      _customAccountController.text =
          transaction.accountName;
    }
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _amountController.dispose();

    _descriptionController.dispose();

    _customAccountController.dispose();

    super.dispose();
  }

  // =====================================================
  // FORMAT DATE
  // =====================================================

  String _formatDate(DateTime date) {
    return '${date.day} '
        '${_months[date.month - 1]} '
        '${date.year}';
  }

  // =====================================================
  // PICK DATE
  // =====================================================

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal transaksi',
    );

    if (!mounted || picked == null) return;

    setState(() {
      _selectedDate = picked;
    });
  }

  // =====================================================
  // CHANGE ACCOUNT TYPE
  // =====================================================

  void _changeAccountType(AccountType type) {
    final options = _accountOptions(type);

    setState(() {
      _accountType = type;

      _selectedAccount = options.isEmpty
          ? _customValue
          : options.first;

      _isCustomAccount = options.isEmpty;

      _customAccountController.clear();
    });
  }

  // =====================================================
  // EFFECTIVE ACCOUNT NAME
  // =====================================================

  String get _effectiveAccountName {
    if (_isCustomAccount ||
        _accountType == AccountType.other) {
      return _customAccountController.text.trim();
    }

    return _selectedAccount;
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
  // SAVE TRANSACTION - RIVERPOD
  // =====================================================

  Future<void> _saveTransaction() async {
    if (_saving) return;

    final transactionState =
        ref.read(transactionStateProvider);

    if (transactionState.isSaving) return;

    FocusScope.of(context).unfocus();

    // Validasi form.
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

    final accountName = _effectiveAccountName;

    if (accountName.isEmpty) {
      _showMessage(
        'Nama akun harus diisi.',
      );
      return;
    }

    final description =
        _descriptionController.text.trim();

    if (description.isEmpty) {
      _showMessage(
        'Deskripsi transaksi wajib diisi.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final notifier = ref.read(
        transactionStateProvider.notifier,
      );

      if (_editing) {
        // ============================================
        // UPDATE TRANSACTION
        // ============================================

        final updatedTransaction =
            widget.transaction!.copyWith(
          date: _selectedDate,
          amount: amount,
          type: _transactionType,
          accountType: _accountType,
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
        // ============================================
        // CREATE TRANSACTION
        // ============================================

        final transaction = FinanceTransaction(
          date: _selectedDate,
          amount: amount,
          type: _transactionType,
          accountType: _accountType,
          accountName: accountName,
          description: description,
        );

        await notifier.addTransaction(
          transaction,
        );
      }

      if (!mounted) return;

      _showMessage(
        _editing
            ? 'Transaksi berhasil diperbarui.'
            : 'Transaksi berhasil ditambahkan.',
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Gagal menyimpan transaksi: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // =====================================================
  // SECTION CARD
  // =====================================================

  Widget _sectionCard(Widget child) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,

        borderRadius: BorderRadius.circular(22),

        border: Border.all(
          color: scheme.outlineVariant
              .withValues(alpha: 0.55),
        ),
      ),

      child: child,
    );
  }

  // =====================================================
  // SECTION TITLE
  // =====================================================

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

          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // TRANSACTION PREVIEW
  // =====================================================

  Widget _buildPreviewCard() {
    final isIncome =
        _transactionType == TransactionType.income;

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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [
            _darkGreen,
            _green,
          ],
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
                  color: Colors.white
                      .withValues(alpha: 0.17),

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
                  isIncome
                      ? 'Uang Masuk'
                      : 'Uang Keluar',

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

          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Colors.white70,
                size: 15,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  _formatDate(_selectedDate),

                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 9),

            Text(
              description,

              maxLines: 2,
              overflow: TextOverflow.ellipsis,

              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =====================================================
  // TRANSACTION TYPE SELECTOR
  // =====================================================

  Widget _buildTypeSelector() {
    return SizedBox(
      width: double.infinity,

      child: SegmentedButton<TransactionType>(
        showSelectedIcon: false,

        segments: const [
          ButtonSegment<TransactionType>(
            value: TransactionType.expense,

            icon: Icon(
              Icons.arrow_upward_rounded,
            ),

            label: Text(
              'Pengeluaran',
            ),
          ),

          ButtonSegment<TransactionType>(
            value: TransactionType.income,

            icon: Icon(
              Icons.arrow_downward_rounded,
            ),

            label: Text(
              'Pemasukan',
            ),
          ),
        ],

        selected: {
          _transactionType,
        },

        onSelectionChanged: (selection) {
          if (selection.isEmpty) return;

          setState(() {
            _transactionType = selection.first;
          });
        },
      ),
    );
  }

  // =====================================================
  // AMOUNT FIELD
  // =====================================================

  Widget _buildAmountField() {
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

      onChanged: (_) {
        setState(() {});
      },

      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Masukkan nominal transaksi.';
        }

        if (parseRupiah(value) <= 0) {
          return 'Nominal harus lebih dari Rp0.';
        }

        return null;
      },
    );
  }

  // =====================================================
  // QUICK AMOUNT BUTTONS
  // =====================================================

  Widget _buildQuickAmounts() {
    const amounts = [
      10000,
      25000,
      50000,
      100000,
    ];

    final selectedAmount = parseRupiah(
      _amountController.text,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,

      children: amounts.map((amount) {
        return ChoiceChip(
          label: Text(
            '${amount ~/ 1000}rb',
          ),

          selected: selectedAmount == amount,

          showCheckmark: false,

          onSelected: (_) {
            setState(() {
              _amountController.text =
                  amount.toString();

              _amountController.selection =
                  TextSelection.collapsed(
                offset: _amountController.text.length,
              );
            });
          },
        );
      }).toList(),
    );
  }

  // =====================================================
  // DATE FIELD
  // =====================================================

  Widget _buildDateField() {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,

      borderRadius: BorderRadius.circular(15),

      child: InkWell(
        onTap: _pickDate,

        borderRadius: BorderRadius.circular(15),

        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),

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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Tanggal Transaksi',

                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _formatDate(_selectedDate),

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
      ),
    );
  }

  // =====================================================
  // ACCOUNT ICON
  // =====================================================

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

  // =====================================================
  // ACCOUNT TYPE SELECTOR
  // =====================================================

  Widget _buildAccountTypeSelector() {
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

            selected: _accountType == type,

            showCheckmark: false,

            onSelected: (_) {
              _changeAccountType(type);
            },
          ),
      ],
    );
  }

  // =====================================================
  // ACCOUNT FIELD
  // =====================================================

  Widget _buildAccountField() {
    final options = _accountOptions(_accountType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        // =============================================
        // PREDEFINED ACCOUNTS
        // =============================================

        if (options.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey(
              'account_${_accountType.name}',
            ),

            initialValue: _isCustomAccount
                ? _customValue
                : _selectedAccount,

            isExpanded: true,

            decoration: InputDecoration(
              labelText: _transactionType ==
                      TransactionType.income
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

                child: Text(
                  '+ Tambah Akun Sendiri',
                ),
              ),
            ],

            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _selectedAccount = value;

                _isCustomAccount =
                    value == _customValue;
              });
            },
          ),

        // =============================================
        // CUSTOM ACCOUNT
        // =============================================

        if (_isCustomAccount ||
            _accountType == AccountType.other) ...[
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

            onChanged: (_) {
              setState(() {});
            },
          ),
        ],
      ],
    );
  }

  // =====================================================
  // DESCRIPTION FIELD
  // =====================================================

  Widget _buildDescriptionField() {
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

      onChanged: (_) {
        setState(() {});
      },
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(
      transactionStateProvider.select(
        (state) => state.isSaving,
      ),
    );

    final isIncome =
        _transactionType == TransactionType.income;

    final theme = Theme.of(context);

    return Scaffold(
      // =================================================
      // APP BAR
      // =================================================

      appBar: AppBar(
        title: Text(
          _editing
              ? 'Edit Transaksi'
              : 'Tambah Transaksi',

          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      // =================================================
      // SAVE BUTTON
      // =================================================

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
            onPressed: _saving || isSaving
                ? null
                : _saveTransaction,

            icon: _saving
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
              _saving
                  ? 'Menyimpan...'
                  : _editing
                      ? 'Simpan Perubahan'
                      : 'Simpan Transaksi',

              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),

      // =================================================
      // FORM
      // =================================================

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
                  // =====================================
                  // TRANSACTION PREVIEW
                  // =====================================

                  _buildPreviewCard(),

                  const SizedBox(height: 26),

                  // =====================================
                  // TRANSACTION TYPE
                  // =====================================

                  _sectionTitle(
                    'Jenis Transaksi',

                    isIncome
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                  ),

                  _buildTypeSelector(),

                  const SizedBox(height: 25),

                  // =====================================
                  // TRANSACTION DETAILS
                  // =====================================

                  _sectionTitle(
                    'Detail Transaksi',
                    Icons.payments_outlined,
                  ),

                  _sectionCard(
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        _buildAmountField(),

                        const SizedBox(height: 13),

                        _buildQuickAmounts(),

                        const SizedBox(height: 18),

                        _buildDateField(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // =====================================
                  // ACCOUNT
                  // =====================================

                  _sectionTitle(
                    'Sumber Dana',
                    Icons.account_balance_wallet_outlined,
                  ),

                  _sectionCard(
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        _buildAccountTypeSelector(),

                        const SizedBox(height: 16),

                        _buildAccountField(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // =====================================
                  // DESCRIPTION
                  // =====================================

                  _sectionTitle(
                    'Keterangan',
                    Icons.edit_note_outlined,
                  ),

                  _sectionCard(
                    _buildDescriptionField(),
                  ),

                  const SizedBox(height: 24),

                  // =====================================
                  // INFORMATION
                  // =====================================

                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 17,
                        color: theme
                            .colorScheme.onSurfaceVariant,
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          'Transaksi dicatat di perangkat ini.',

                          style: theme.textTheme.bodySmall,
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
  }
}