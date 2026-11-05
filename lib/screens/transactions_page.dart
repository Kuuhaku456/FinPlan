import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models/finance_transaction.dart';
import '../state/transaction_controller.dart';
import 'add_transaction_page.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({
    super.key,
    required this.controller,
  });

  final TransactionController controller;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

enum _TransactionAction {
  edit,
  delete,
}

class _HistoryEntry {
  const _HistoryEntry.day(this.date) : transaction = null;

  const _HistoryEntry.item(this.transaction) : date = null;

  final DateTime? date;
  final FinanceTransaction? transaction;
}

class _TransactionsPageState extends State<TransactionsPage> {
  final ScrollController _scrollController = ScrollController();

  static const Color _green = Color(0xFF059669);
  static const Color _darkGreen = Color(0xFF064E3B);
  static const Color _red = Color(0xFFEF4444);

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

  static const List<String> _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  // =====================================================
  // LIFECYCLE
  // =====================================================

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.loadTransactions();
    });
  }

  @override
  void didUpdateWidget(covariant TransactionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.controller.loadTransactions();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // =====================================================
  // PAGINATION
  // =====================================================

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.extentAfter < 300) {
      final controller = widget.controller;

      if (!controller.isLoading &&
          !controller.isLoadingMore &&
          controller.hasMore) {
        controller.loadMore();
      }
    }
  }

  // =====================================================
  // FORMAT
  // =====================================================

  String _monthYear(DateTime date) {
    return '${_months[date.month - 1]} ${date.year}';
  }

  String _fullDate(DateTime date) {
    return '${_days[date.weekday - 1]}, '
        '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  String _signedMoney(int amount) {
    if (amount < 0) {
      return '-${rupiah(amount.abs())}';
    }

    return rupiah(amount);
  }

  String _accountLabel(FinanceTransaction transaction) {
    if (transaction.accountType == AccountType.cash) {
      return transaction.accountName;
    }

    return '${transaction.accountType.label} • '
        '${transaction.accountName}';
  }

  // =====================================================
  // IKON TRANSAKSI OTOMATIS
  // =====================================================

  IconData _transactionIcon(FinanceTransaction transaction) {
    if (transaction.type == TransactionType.income) {
      return Icons.south_west_rounded;
    }

    final description = transaction.description.toLowerCase();

    if (RegExp(
      r'makan|nasi|kopi|sarapan|resto|food|lunch|dinner',
    ).hasMatch(description)) {
      return Icons.restaurant_rounded;
    }

    if (RegExp(
      r'krl|kereta|transport|ojek|gojek|grab|bus|bensin|parkir|tj',
    ).hasMatch(description)) {
      return Icons.directions_transit_rounded;
    }

    if (RegExp(
      r'belanja|beli|shop|market|grocery',
    ).hasMatch(description)) {
      return Icons.shopping_bag_rounded;
    }

    if (RegExp(
      r'listrik|tagihan|pulsa|internet|wifi',
    ).hasMatch(description)) {
      return Icons.receipt_long_rounded;
    }

    if (RegExp(
      r'tabung|simpan|saving',
    ).hasMatch(description)) {
      return Icons.savings_rounded;
    }

    return Icons.north_east_rounded;
  }

  // =====================================================
  // FILTER BULAN
  // =====================================================

  void _changeMonth(int offset) {
    final current = widget.controller.selectedMonth;

    final nextMonth = DateTime(
      current.year,
      current.month + offset,
      1,
    );

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    widget.controller.selectMonth(nextMonth);
  }

  // =====================================================
  // TAMBAH TRANSAKSI
  // =====================================================

  Future<void> _openAddTransaction() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => AddTransactionPage(
          controller: widget.controller,
        ),
      ),
    );
  }

  // =====================================================
  // EDIT TRANSAKSI
  // =====================================================

  Future<void> _openEditTransaction(
    FinanceTransaction transaction,
  ) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => AddTransactionPage(
          controller: widget.controller,
          transaction: transaction,
        ),
      ),
    );
  }

  // =====================================================
  // PESAN
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
  // HAPUS TRANSAKSI
  // =====================================================

  Future<void> _confirmDelete(
    FinanceTransaction transaction,
  ) async {
    final transactionId = transaction.id;

    if (transactionId == null) {
      _showMessage('ID transaksi tidak ditemukan.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),

          title: const Text('Hapus Transaksi?'),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.description,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                rupiah(transaction.amount),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 13),

              const Text(
                'Transaksi yang dihapus tidak dapat dikembalikan.',
                style: TextStyle(
                  color: _red,
                  fontSize: 12,
                ),
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
                foregroundColor: Colors.white,
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
      final deleted = await widget.controller.deleteTransaction(
        transactionId,
      );

      if (!mounted) return;

      _showMessage(
        deleted
            ? 'Transaksi berhasil dihapus.'
            : 'Transaksi tidak ditemukan.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage('Gagal menghapus transaksi: $error');
    }
  }

  // =====================================================
  // GROUPING TRANSAKSI
  // =====================================================

  List<_HistoryEntry> _buildHistoryEntries(
    List<FinanceTransaction> transactions,
  ) {
    final entries = <_HistoryEntry>[];

    String? previousDate;

    for (final transaction in transactions) {
      final currentDate = transaction.dateString;

      if (previousDate != currentDate) {
        entries.add(
          _HistoryEntry.day(transaction.date),
        );

        previousDate = currentDate;
      }

      entries.add(
        _HistoryEntry.item(transaction),
      );
    }

    return entries;
  }

  // =====================================================
  // FILTER BULAN CARD
  // =====================================================

  Widget _buildMonthSelector(DateTime selectedMonth) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),

      child: Row(
        children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: () => _changeMonth(-1),
            icon: const Icon(
              Icons.chevron_left_rounded,
              size: 28,
            ),
          ),

          Expanded(
            child: Column(
              children: [
                Text(
                  'PERIODE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _monthYear(selectedMonth),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: () => _changeMonth(1),
            icon: const Icon(
              Icons.chevron_right_rounded,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // HERO CARD
  // =====================================================

  Widget _buildBalanceCard(TransactionController controller) {
    final summary = controller.summary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _darkGreen,
            _green,
          ],
        ),

        borderRadius: BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Arus Kas Bersih',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),

              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),

          const SizedBox(height: 11),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _signedMoney(summary.netAmount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 29,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(25),
            ),

            child: Text(
              '${summary.transactionCount} transaksi bulan ini',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // MINI SUMMARY CARD
  // =====================================================

  Widget _buildSummaryCard({
    required String title,
    required int amount,
    required IconData icon,
    required Color accentColor,
    required Color backgroundColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),

            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),

            child: Icon(
              icon,
              color: accentColor,
              size: 22,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 5),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // RINGKASAN PEMASUKAN & PENGELUARAN
  // =====================================================

  Widget _buildSummary(TransactionController controller) {
    final summary = controller.summary;

    return Column(
      children: [
        _buildBalanceCard(controller),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Pemasukan',
                amount: summary.totalIncome,
                icon: Icons.south_west_rounded,
                accentColor: _green,
                backgroundColor: const Color(0xFFE4F7EE),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildSummaryCard(
                title: 'Pengeluaran',
                amount: summary.totalExpense,
                icon: Icons.north_east_rounded,
                accentColor: _red,
                backgroundColor: const Color(0xFFFDECEC),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =====================================================
  // RIWAYAT HEADER
  // =====================================================

  Widget _buildHistoryTitle(TransactionController controller) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Riwayat Transaksi',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        Text(
          _monthYear(controller.selectedMonth),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // DATE HEADER
  // =====================================================

  Widget _buildDateHeader(DateTime date) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        top: 22,
        bottom: 10,
      ),

      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 15,
            color: scheme.onSurfaceVariant,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              _fullDate(date),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // TRANSACTION CARD
  // =====================================================

  Widget _buildTransactionCard(FinanceTransaction transaction) {
    final isIncome =
        transaction.type == TransactionType.income;

    final accentColor = isIncome ? _green : _red;

    final amountLabel = isIncome
        ? '+${rupiah(transaction.amount)}'
        : '-${rupiah(transaction.amount)}';

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),

      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),

        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openEditTransaction(transaction),

          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),

            child: Row(
              children: [
                // IKON
                Container(
                  width: 46,
                  height: 46,

                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),

                  child: Icon(
                    _transactionIcon(transaction),
                    color: accentColor,
                  ),
                ),

                const SizedBox(width: 12),

                // DESKRIPSI
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        _accountLabel(transaction),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // NOMINAL
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountLabel,
                      maxLines: 1,

                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      isIncome ? 'Masuk' : 'Keluar',

                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                // MENU EDIT & HAPUS
                PopupMenuButton<_TransactionAction>(
                  tooltip: 'Opsi transaksi',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                  ),

                  onSelected: (action) {
                    if (action == _TransactionAction.edit) {
                      _openEditTransaction(transaction);
                    } else if (action == _TransactionAction.delete) {
                      _confirmDelete(transaction);
                    }
                  },

                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: _TransactionAction.edit,
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ],
                        ),
                      ),

                      PopupMenuItem(
                        value: _TransactionAction.delete,
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: _red,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Hapus',
                              style: TextStyle(color: _red),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // PAGINATION FOOTER
  // =====================================================

  Widget _buildPaginationFooter(TransactionController controller) {
    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (controller.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),

        child: Center(
          child: OutlinedButton.icon(
            onPressed: controller.loadMore,
            icon: const Icon(Icons.expand_more_rounded),
            label: const Text('Muat Transaksi Lainnya'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),

      child: Center(
        child: Text(
          'Semua transaksi bulan ini sudah ditampilkan.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          24,
          30,
          24,
          110,
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,

              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),

              child: Icon(
                Icons.receipt_long_outlined,
                size: 42,
                color: scheme.onPrimaryContainer,
              ),
            ),

            const SizedBox(height: 19),

            const Text(
              'Belum Ada Transaksi',
              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 9),

            Text(
              'Mulai catat pemasukan dan pengeluaranmu.',
              textAlign: TextAlign.center,

              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 22),

            FilledButton.icon(
              onPressed: _openAddTransaction,

              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),

              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Transaksi'),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ERROR BOX
  // =====================================================

  Widget _buildErrorBox(String error) {
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),

        border: Border.all(
          color: _red.withValues(alpha: 0.25),
        ),
      ),

      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _red,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 12),
            ),
          ),

          IconButton(
            tooltip: 'Coba lagi',
            onPressed: widget.controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // MAIN BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,

      builder: (context, _) {
        final controller = widget.controller;
        final theme = Theme.of(context);

        final visibleTransactions =
            controller.transactions.where((transaction) {
          return transaction.date.year ==
                  controller.selectedMonth.year &&
              transaction.date.month ==
                  controller.selectedMonth.month;
        }).toList();

        final historyEntries =
            _buildHistoryEntries(visibleTransactions);

        final hasTransactions =
            visibleTransactions.isNotEmpty;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,

          body: RefreshIndicator(
            color: _green,
            onRefresh: controller.refresh,

            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),

              slivers: [
                // HEADER & SUMMARY
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      8,
                    ),

                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Transaksi',
                                style: theme
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                              ),
                            ),

                            IconButton.filledTonal(
                              tooltip: 'Perbarui transaksi',

                              onPressed: controller.isLoading
                                  ? null
                                  : controller.refresh,

                              icon: const Icon(
                                Icons.refresh_rounded,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        _buildMonthSelector(
                          controller.selectedMonth,
                        ),

                        const SizedBox(height: 14),

                        _buildSummary(controller),

                        const SizedBox(height: 25),

                        _buildHistoryTitle(controller),
                      ],
                    ),
                  ),
                ),

                // ERROR
                if (controller.error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),

                      child: _buildErrorBox(
                        '${controller.error}',
                      ),
                    ),
                  ),

                // LOADING
                if (controller.isLoading && !hasTransactions)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )

                // EMPTY
                else if (!hasTransactions)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )

                // HISTORY
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      110,
                    ),

                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index < historyEntries.length) {
                            final entry = historyEntries[index];

                            if (entry.date != null) {
                              return _buildDateHeader(
                                entry.date!,
                              );
                            }

                            return _buildTransactionCard(
                              entry.transaction!,
                            );
                          }

                          return _buildPaginationFooter(controller);
                        },

                        childCount: historyEntries.length + 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          floatingActionButton: FloatingActionButton.extended(
            onPressed: controller.isSaving
                ? null
                : _openAddTransaction,

            backgroundColor: _green,
            foregroundColor: Colors.white,

            icon: const Icon(Icons.add_rounded),

            label: const Text(
              'Tambah',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}