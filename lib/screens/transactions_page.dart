import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../models/finance_transaction.dart';
import '../state/transaction_controller.dart';
import '../state/transaction_notifier.dart';
import 'add_transaction_page.dart';

/// UI Transaksi menggunakan Riverpod.
///
/// Data yang ditampilkan berasal dari transactionStateProvider.
/// Controller lama masih digunakan oleh form tambah/edit
/// selama proses migrasi aplikasi berlangsung.
class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({
    super.key,
    required this.controller,
  });

  final TransactionController controller;

  @override
  ConsumerState<TransactionsPage> createState() {
    return _TransactionsPageState();
  }
}

class _HistoryItem {
  const _HistoryItem.date(this.date) : transaction = null;

  const _HistoryItem.transaction(this.transaction) : date = null;

  final DateTime? date;
  final FinanceTransaction? transaction;
}

enum _Action {
  edit,
  delete,
}

class _TransactionsPageState
    extends ConsumerState<TransactionsPage> {
  // ==========================================
  // WARNA FINPLAN
  // ==========================================

  static const _green = Color(0xFF059669);
  static const _darkGreen = Color(0xFF064E3B);
  static const _red = Color(0xFFEF4444);

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

  static const _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  final ScrollController _scrollController =
      ScrollController();

  // ==========================================
  // LIFECYCLE
  // ==========================================

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref
          .read(transactionStateProvider.notifier)
          .loadTransactions();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    super.dispose();
  }

  // ==========================================
  // PAGINATION
  // ==========================================

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter >= 300) {
      return;
    }

    final state = ref.read(transactionStateProvider);

    if (state.hasMore &&
        !state.isLoading &&
        !state.isLoadingMore) {
      ref
          .read(transactionStateProvider.notifier)
          .loadMore();
    }
  }

  // ==========================================
  // FORMAT TANGGAL DAN NOMINAL
  // ==========================================

  String _monthLabel(DateTime date) {
    return '${_months[date.month - 1]} ${date.year}';
  }

  String _dateLabel(DateTime date) {
    return '${_days[date.weekday - 1]}, '
        '${date.day} '
        '${_months[date.month - 1]} '
        '${date.year}';
  }

  String _signedRupiah(int amount) {
    if (amount < 0) {
      return '-${rupiah(amount.abs())}';
    }

    return rupiah(amount);
  }

  // ==========================================
  // FILTER BULAN
  // ==========================================

  void _changeMonth(int offset) {
    final selected = ref
        .read(transactionStateProvider)
        .selectedMonth;

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    ref
        .read(transactionStateProvider.notifier)
        .selectMonth(
          DateTime(
            selected.year,
            selected.month + offset,
            1,
          ),
        );
  }

  // ==========================================
  // TAMBAH DAN EDIT TRANSAKSI
  // ==========================================

  Future<void> _openEditor([
    FinanceTransaction? transaction,
  ]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddTransactionPage(
          controller: widget.controller,
          transaction: transaction,
        ),
      ),
    );
  }

  // ==========================================
  // SNACKBAR
  // ==========================================

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

  // ==========================================
  // HAPUS TRANSAKSI
  // ==========================================

  Future<void> _confirmDelete(
    FinanceTransaction transaction,
  ) async {
    final id = transaction.id;

    if (id == null) {
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                rupiah(transaction.amount),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
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
      final success = await ref
          .read(transactionStateProvider.notifier)
          .deleteTransaction(id);

      if (!mounted) return;

      _showMessage(
        success
            ? 'Transaksi berhasil dihapus.'
            : 'Transaksi tidak ditemukan.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Gagal menghapus transaksi: $error',
      );
    }
  }

  // ==========================================
  // IKON TRANSAKSI OTOMATIS
  // ==========================================

  IconData _iconFor(
    FinanceTransaction transaction,
  ) {
    if (transaction.type == TransactionType.income) {
      return Icons.south_west_rounded;
    }

    final value = transaction.description.toLowerCase();

    if (RegExp(
      r'makan|nasi|kopi|sarapan|resto|food|lunch|dinner',
    ).hasMatch(value)) {
      return Icons.restaurant_rounded;
    }

    if (RegExp(
      r'krl|kereta|transport|ojek|gojek|grab|bus|bensin|parkir|tj',
    ).hasMatch(value)) {
      return Icons.directions_transit_rounded;
    }

    if (RegExp(
      r'belanja|beli|shop|market|grocery',
    ).hasMatch(value)) {
      return Icons.shopping_bag_rounded;
    }

    if (RegExp(
      r'listrik|tagihan|pulsa|internet|wifi',
    ).hasMatch(value)) {
      return Icons.receipt_long_rounded;
    }

    if (RegExp(
      r'tabung|simpan|saving',
    ).hasMatch(value)) {
      return Icons.savings_rounded;
    }

    return Icons.north_east_rounded;
  }

  // ==========================================
  // KELOMPOKKAN RIWAYAT BERDASARKAN TANGGAL
  // ==========================================

  List<_HistoryItem> _history(
    List<FinanceTransaction> transactions,
  ) {
    final result = <_HistoryItem>[];

    String? lastDate;

    for (final transaction in transactions) {
      if (lastDate != transaction.dateString) {
        result.add(
          _HistoryItem.date(transaction.date),
        );

        lastDate = transaction.dateString;
      }

      result.add(
        _HistoryItem.transaction(transaction),
      );
    }

    return result;
  }

  // ==========================================
  // SELECTOR BULAN
  // ==========================================

  Widget _monthSelector(
    TransactionViewState state,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            icon: const Icon(
              Icons.chevron_left_rounded,
              size: 28,
            ),
            onPressed: () => _changeMonth(-1),
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
                    color:
                        theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _monthLabel(state.selectedMonth),
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
            icon: const Icon(
              Icons.chevron_right_rounded,
              size: 28,
            ),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // KARTU SALDO / ARUS KAS
  // ==========================================

  Widget _balanceCard(
    TransactionViewState state,
  ) {
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
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
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
              _signedRupiah(state.netAmount),
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
              color:
                  Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              '${state.transactionCount} transaksi bulan ini',
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

  // ==========================================
  // MINI CARD PEMASUKAN / PENGELUARAN
  // ==========================================

  Widget _miniCard({
    required String label,
    required int amount,
    required IconData icon,
    required Color color,
    required Color lightBackground,
  }) {
    final theme = Theme.of(context);

    final dark =
        theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: dark
            ? theme.colorScheme.surfaceContainerHigh
            : lightBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
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
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // RINGKASAN KEUANGAN
  // ==========================================

  Widget _summary(
    TransactionViewState state,
  ) {
    return Column(
      children: [
        _balanceCard(state),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _miniCard(
                label: 'Pemasukan',
                amount: state.totalIncome,
                icon: Icons.south_west_rounded,
                color: _green,
                lightBackground:
                    const Color(0xFFE4F7EE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _miniCard(
                label: 'Pengeluaran',
                amount: state.totalExpense,
                icon: Icons.north_east_rounded,
                color: _red,
                lightBackground:
                    const Color(0xFFFDECEC),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // HEADER TANGGAL
  // ==========================================

  Widget _dateHeader(DateTime date) {
    final color =
        Theme.of(context).colorScheme.onSurfaceVariant;

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
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _dateLabel(date),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // KARTU TRANSAKSI
  // ==========================================

  Widget _transactionCard(
    FinanceTransaction transaction,
  ) {
    final theme = Theme.of(context);

    final income =
        transaction.type == TransactionType.income;

    final color = income ? _green : _red;

    final account =
        transaction.accountType == AccountType.cash
            ? transaction.accountName
            : '${transaction.accountType.label} • '
                '${transaction.accountName}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openEditor(transaction),
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
                    color: color.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _iconFor(transaction),
                    color: color,
                  ),
                ),

                const SizedBox(width: 12),

                // DESKRIPSI
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        account,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // NOMINAL
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${income ? '+' : '-'}'
                      '${rupiah(transaction.amount)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      income ? 'Masuk' : 'Keluar',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                // MENU EDIT & HAPUS
                PopupMenuButton<_Action>(
                  tooltip: 'Opsi transaksi',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                  ),
                  onSelected: (action) {
                    if (action == _Action.edit) {
                      _openEditor(transaction);
                    } else if (action ==
                        _Action.delete) {
                      _confirmDelete(transaction);
                    }
                  },
                  itemBuilder: (_) {
                    return const [
                      PopupMenuItem(
                        value: _Action.edit,
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _Action.delete,
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: _red,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Hapus',
                              style:
                                  TextStyle(color: _red),
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

  // ==========================================
  // FOOTER PAGINATION
  // ==========================================

  Widget _footer(
    TransactionViewState state,
  ) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 24,
        ),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
        ),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: () {
              ref
                  .read(
                    transactionStateProvider.notifier,
                  )
                  .loadMore();
            },
            icon: const Icon(
              Icons.expand_more_rounded,
            ),
            label:
                const Text('Muat Transaksi Lainnya'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 24,
      ),
      child: Center(
        child: Text(
          'Semua transaksi bulan ini sudah ditampilkan.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // EMPTY STATE
  // ==========================================

  Widget _emptyState() {
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
          mainAxisAlignment:
              MainAxisAlignment.center,
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
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => _openEditor(),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(
                Icons.add_rounded,
              ),
              label:
                  const Text('Tambah Transaksi'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ERROR BANNER
  // ==========================================

  Widget _errorBanner(String message) {
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
              message,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Coba lagi',
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            onPressed: () {
              ref
                  .read(
                    transactionStateProvider.notifier,
                  )
                  .refresh();
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MAIN BUILD - RIVERPOD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    // Otomatis rebuild ketika state transaksi berubah.
    final state = ref.watch(
      transactionStateProvider,
    );

    final theme = Theme.of(context);

    final transactions = state.transactions.where(
      (transaction) {
        return transaction.date.year ==
                state.selectedMonth.year &&
            transaction.date.month ==
                state.selectedMonth.month;
      },
    ).toList();

    final entries = _history(transactions);

    final hasTransactions =
        transactions.isNotEmpty;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      body: RefreshIndicator(
        color: _green,

        onRefresh: () {
          return ref
              .read(
                transactionStateProvider.notifier,
              )
              .refresh();
        },

        child: CustomScrollView(
          controller: _scrollController,
          physics:
              const AlwaysScrollableScrollPhysics(),

          slivers: [
            // ==================================
            // HEADER
            // ==================================

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
                          tooltip:
                              'Perbarui transaksi',

                          onPressed: state.isLoading
                              ? null
                              : () {
                                  ref
                                      .read(
                                        transactionStateProvider
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

                    const SizedBox(height: 16),

                    _monthSelector(state),

                    const SizedBox(height: 14),

                    _summary(state),

                    const SizedBox(height: 25),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Riwayat Transaksi',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          _monthLabel(
                            state.selectedMonth,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ==================================
            // ERROR
            // ==================================

            if (state.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _errorBanner(
                    state.error!,
                  ),
                ),
              ),

            // ==================================
            // LOADING
            // ==================================

            if (state.isLoading &&
                !hasTransactions)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )

            // ==================================
            // BELUM ADA TRANSAKSI
            // ==================================

            else if (!hasTransactions)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(),
              )

            // ==================================
            // RIWAYAT TRANSAKSI
            // ==================================

            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  110,
                ),

                sliver: SliverList(
                  delegate:
                      SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == entries.length) {
                        return _footer(state);
                      }

                      final item = entries[index];

                      if (item.date != null) {
                        return _dateHeader(
                          item.date!,
                        );
                      }

                      return _transactionCard(
                        item.transaction!,
                      );
                    },

                    childCount: entries.length + 1,
                  ),
                ),
              ),
          ],
        ),
      ),

      // ======================================
      // TOMBOL TAMBAH TRANSAKSI
      // ======================================

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: state.isSaving
            ? null
            : () => _openEditor(),

        backgroundColor: _green,
        foregroundColor: Colors.white,

        icon: const Icon(
          Icons.add_rounded,
        ),

        label: const Text(
          'Tambah',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}