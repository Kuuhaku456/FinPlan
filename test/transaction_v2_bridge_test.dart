import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celeng_id/data/transaction_repository.dart';
import 'package:celeng_id/models/finance_transaction.dart';
import 'package:celeng_id/state/transaction_notifier.dart';
import 'package:celeng_id/state/transaction_riverpod_v2.dart';

// =====================================================
// FINPLAN - TRANSACTION V2 BRIDGE TEST
// =====================================================
//
// Menguji:
// - Integrasi Riverpod V2 dengan UI Bridge
// - State awal transaksi
// - Ringkasan pemasukan dan pengeluaran
// - Filter bulan
// - Refresh dan sinkronisasi state
//
// Tidak menggunakan SQLite asli.
// =====================================================

// =====================================================
// FAKE TRANSACTION NOTIFIER
// =====================================================

class _TestTransactionV2Notifier extends TransactionV2Notifier {
  @override
  TransactionV2State build() {
    return TransactionV2State(selectedMonth: DateTime(2026, 11, 1));
  }

  // ===================================================
  // LOAD TRANSACTIONS
  // ===================================================

  @override
  Future<void> loadTransactions() async {
    state = state.copyWith(
      summary: const TransactionSummary(
        totalIncome: 5000000,
        totalExpense: 1200000,
        transactionCount: 8,
      ),
      hasLoaded: true,
      isLoading: false,
      revision: state.revision + 1,
      clearError: true,
    );
  }

  // ===================================================
  // SELECT MONTH
  // ===================================================

  @override
  Future<void> selectMonth(DateTime month) async {
    state = state.copyWith(selectedMonth: DateTime(month.year, month.month, 1));

    await loadTransactions();
  }
}

// =====================================================
// MAIN TEST SUITE
// =====================================================

void main() {
  late ProviderContainer container;

  // ===================================================
  // SETUP
  // ===================================================

  setUp(() {
    container = ProviderContainer(
      overrides: [
        transactionV2ModeProvider.overrideWithValue(true),
        transactionV2Provider.overrideWith(_TestTransactionV2Notifier.new),
      ],
    );
  });

  // ===================================================
  // TEARDOWN
  // ===================================================

  tearDown(() {
    container.dispose();
  });

  // ===================================================
  // TEST 1 - INITIAL STATE
  // ===================================================

  test('Bridge menggunakan bulan awal Riverpod V2', () {
    final state = container.read(transactionStateProvider);

    expect(state.selectedMonth, DateTime(2026, 11, 1));

    expect(state.totalIncome, 0);
    expect(state.totalExpense, 0);
    expect(state.netAmount, 0);
    expect(state.transactionCount, 0);
  });

  // ===================================================
  // TEST 2 - MONTHLY SUMMARY
  // ===================================================

  test('Bridge membaca ringkasan melalui Riverpod V2', () async {
    final notifier = container.read(transactionStateProvider.notifier);

    await notifier.loadTransactions();

    final state = container.read(transactionStateProvider);

    expect(state.totalIncome, 5000000);
    expect(state.totalExpense, 1200000);
    expect(state.netAmount, 3800000);
    expect(state.transactionCount, 8);
    expect(state.isLoading, false);
    expect(state.revision, greaterThan(0));
  });

  // ===================================================
  // TEST 3 - CHANGE MONTH
  // ===================================================

  test('Bridge meneruskan perubahan bulan ke Riverpod V2', () async {
    final notifier = container.read(transactionStateProvider.notifier);

    await notifier.selectMonth(DateTime(2026, 10, 20));

    final state = container.read(transactionStateProvider);

    expect(state.selectedMonth, DateTime(2026, 10, 1));

    expect(state.totalIncome, 5000000);
    expect(state.totalExpense, 1200000);
  });

  // ===================================================
  // TEST 4 - REFRESH
  // ===================================================

  test('Refresh memperbarui revision Riverpod V2', () async {
    final notifier = container.read(transactionStateProvider.notifier);

    await notifier.loadTransactions();

    final previous = container.read(transactionStateProvider).revision;

    await notifier.refresh();

    final current = container.read(transactionStateProvider).revision;

    expect(current, greaterThan(previous));
  });
}
