import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../models/finance_transaction.dart';
import '../state/transaction_controller.dart';
import '../state/transaction_notifier.dart';

// ==========================================
// FINPLAN COLORS
// ==========================================

const _darkGreen = Color(0xFF064E3B);
const _green = Color(0xFF059669);

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
  // dengan navigasi yang sudah ada.
  final TransactionController controller;

  final FinanceTransaction? transaction;

  @override
  ConsumerState<AddTransactionPage> createState() {
    return _AddTransactionPageState();
  }
}

class _AddTransactionPageState
    extends ConsumerState<AddTransactionPage> {
  static const _customValue = '__custom__';

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

  final _formKey = GlobalKey<FormState>();

  final _amountController =
      TextEditingController();

  final _descriptionController =
      TextEditingController();

  final _customAccountController =
      TextEditingController();

  late DateTime _selectedDate;

  TransactionType _transactionType =
      TransactionType.expense;

  AccountType _accountType =
      AccountType.bank;

  String _selectedAccount = 'BCA';

  bool _isCustomAccount = false;
  bool _saving = false;

  bool get _editing => widget.transaction != null;

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
        return const [
          'Tunai',
        ];

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
    final now = DateTime.now();

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

    final options = _accountOptions(
      _accountType,
    );

    if (transaction != null &&
        options.contains(transaction.accountName)) {
      _selectedAccount = transaction.accountName;
      _isCustomAccount = false;
    } else if (transaction != null) {
      _selectedAccount = _customValue;
      _isCustomAccount = true;

      _customAccountController.text =
          transaction.accountName;
    } else if (options.isNotEmpty) {
      _selectedAccount = options.first;
      _isCustomAccount = false;
    } else {
      _selectedAccount = _customValue;
      _isCustomAccount = true;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _customAccountController.dispose();

    super.dispose();
  }

  // ========================================
  // DATE FORMAT
  // ========================================

  String _formatDate(DateTime date) {
    return '${date.day} '
        '${_months[date.month - 1]} '
        '${date.year}';
  }

  // ========================================
  // DATE PICKER
  // ========================================

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal transaksi',
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // ========================================
  // CHANGE ACCOUNT TYPE
  // ========================================

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

  // ========================================
  // EFFECTIVE ACCOUNT NAME
  // ========================================

  String get _effectiveAccountName {
    if (_isCustomAccount ||
        _accountType == AccountType.other) {
      return _customAccountController.text.trim();
    }

    return _selectedAccount;
  }

  // ========================================
  // SNACKBAR
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
  // SAVE USING TRANSACTION NOTIFIER
  // ========================================

  Future<void> _saveTransaction() async {
    if (_saving ||
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

    final accountName = _effectiveAccountName;

    if (accountName.isEmpty) {
      _showMessage(
        'Nama akun harus diisi.',
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

      final description =
          _descriptionController.text.trim();

      if (_editing) {
        // =================================
        // UPDATE TRANSACTION
        // =================================

        final updated = widget.transaction!.copyWith(
          date: _selectedDate,
          amount: amount,
          type: _transactionType,
          accountType: _accountType,
          accountName: accountName,
          description: description,
        );

        final success = await notifier.updateTransaction(
          updated,
        );

        if (!success) {
          throw StateError(
            'Transaksi tidak ditemukan.',
          );
        }
      } else {
        // =================================
        // CREATE TRANSACTION
        // =================================

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

  // ========================================
  // CARD CONTAINER
  // ========================================

  Widget _card(Widget child) {
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

  // ========================================
  // TRANSACTION PREVIEW
  // ========================================

  Widget _previewCard() {
    final income =
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
                  income
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  income
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
              '${income ? '+' : '-'}${rupiah(amount)}',
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
            const SizedBox(height: 7),

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

  // ========================================
  // TRANSACTION TYPE SELECTOR
  // ========================================

  Widget _typeSelector() {
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
            label: Text('Pengeluaran'),
          ),

          ButtonSegment<TransactionType>(
            value: TransactionType.income,
            icon: Icon(
              Icons.arrow_downward_rounded,
            ),
            label: Text('Pemasukan'),
          ),
        ],

        selected: {_transactionType},

        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            setState(() {
              _transactionType = selection.first;
            });
          }
        },
      ),
    );
  }

  // ========================================
  // AMOUNT INPUT
  // ========================================

  Widget _amountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,

      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],

      onChanged: (_) {
        setState(() {});
      },

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
  // QUICK AMOUNTS
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
          label: Text(
            '${amount ~/ 1000}rb',
          ),
          selected: selected,
          showCheckmark: false,
          selectedColor: const Color(0xFFD1FAE5),
          onSelected: (_) {
            setState(() {
              _amountController.text =
                  amount.toString();
            });
          },
        );
      }).toList(),
    );
  }

  // ========================================
  // DATE FIELD
  // ========================================

  Widget _dateField() {
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

  // ========================================
  // ACCOUNT ICON
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

  Widget _accountTypeSelector() {
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
            selectedColor: const Color(0xFFD1FAE5),
            onSelected: (_) {
              _changeAccountType(type);
            },
          ),
      ],
    );
  }

  // ========================================
  // ACCOUNT NAME FIELD
  // ========================================

  Widget _accountField() {
    final options = _accountOptions(
      _accountType,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              labelText:
                  _transactionType == TransactionType.income
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

      onChanged: (_) {
        setState(() {});
      },
    );
  }

  // ========================================
  // MAIN BUILD - RIVERPOD
  // ========================================

  @override
  Widget build(BuildContext context) {
    // Hanya memantau status penyimpanan.
    final isSaving = ref.watch(
      transactionStateProvider.select(
        (state) => state.isSaving,
      ),
    );

    final income =
        _transactionType == TransactionType.income;

    return Scaffold(
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

      // ====================================
      // FIXED SAVE BUTTON
      // ====================================

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

      // ====================================
      // FORM CONTENT
      // ====================================

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
                  // LIVE PREVIEW
                  _previewCard(),

                  const SizedBox(height: 26),

                  // TRANSACTION TYPE
                  _sectionTitle(
                    'Jenis Transaksi',
                    income
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                  ),

                  _typeSelector(),

                  const SizedBox(height: 25),

                  // AMOUNT AND DATE
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

                        _dateField(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ACCOUNT
                  _sectionTitle(
                    'Sumber Dana',
                    Icons.account_balance_wallet_outlined,
                  ),

                  _card(
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _accountTypeSelector(),

                        const SizedBox(height: 16),

                        _accountField(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // DESCRIPTION
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
  }
}