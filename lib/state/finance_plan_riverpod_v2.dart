import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/plan_repository.dart';
import '../models/finance_plan.dart';

// =====================================================
// FINPLAN - FINANCE PLAN RIVERPOD V2
// =====================================================
//
// Alur:
//
// UI -> Riverpod Notifier
//    -> PlanRepository
//    -> SharedPreferencesAsync
//
// Kunci penyimpanan tetap: finplan.plan.v1
// Tidak mengubah struktur JSON pengguna.
// =====================================================

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final financePlanRepositoryV2Provider = Provider<PlanRepository>((ref) {
  return PlanRepository();
});

// =====================================================
// IMMUTABLE STATE
// =====================================================

class FinancePlanV2State {
  const FinancePlanV2State({
    this.plan,
    this.isLoading = false,
    this.isSaving = false,
    this.hasLoaded = false,
    this.revision = 0,
    this.error,
  });

  final FinancePlan? plan;
  final bool isLoading;
  final bool isSaving;
  final bool hasLoaded;
  final int revision;
  final String? error;

  bool get hasPlan => plan != null;
  bool get hasError => error != null;
  bool get isBusy => isLoading || isSaving;

  int get totalIncome => plan?.totalMonthlyIncome ?? 0;

  int get totalExpenses => plan?.expenses ?? 0;

  int get totalSavings => plan?.savings ?? 0;

  int get buffer => plan?.buffer ?? 0;

  int get remaining => plan?.plannedDifference ?? 0;

  bool get canFundPlan => plan?.canFundPlan ?? false;

  FinancePlanV2State copyWith({
    FinancePlan? plan,
    bool clearPlan = false,
    bool? isLoading,
    bool? isSaving,
    bool? hasLoaded,
    int? revision,
    String? error,
    bool clearError = false,
  }) {
    return FinancePlanV2State(
      plan: clearPlan ? null : plan ?? this.plan,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      revision: revision ?? this.revision,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// =====================================================
// NOTIFIER PROVIDER
// =====================================================

final financePlanV2Provider =
    NotifierProvider<FinancePlanV2Notifier, FinancePlanV2State>(
      FinancePlanV2Notifier.new,
    );

// =====================================================
// FINANCE PLAN NOTIFIER
// =====================================================

class FinancePlanV2Notifier extends Notifier<FinancePlanV2State> {
  // Antrean untuk mencegah beberapa penulisan
  // saling menimpa.
  Future<void> _pending = Future<void>.value();

  PlanRepository get _repository {
    return ref.read(financePlanRepositoryV2Provider);
  }

  @override
  FinancePlanV2State build() {
    return const FinancePlanV2State();
  }

  // ===================================================
  // SERIAL OPERATION
  // ===================================================

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    final previous = _pending;
    final completed = Completer<void>();

    _pending = completed.future;

    await previous;

    try {
      return await operation();
    } finally {
      completed.complete();
    }
  }

  // ===================================================
  // FORMAT ERROR
  // ===================================================

  String _errorMessage(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Data rencana keuangan tidak valid.';
    }

    if (error is StateError) {
      return error.message;
    }

    return 'Gagal mengelola rencana keuangan.';
  }

  // ===================================================
  // LOAD FINANCE PLAN
  // ===================================================

  Future<void> loadPlan() {
    return _exclusive(() async {
      if (!ref.mounted) return;

      state = state.copyWith(isLoading: true, clearError: true);

      try {
        final savedPlan = await _repository.loadPlan();

        if (!ref.mounted) return;

        state = state.copyWith(
          plan: savedPlan,
          clearPlan: savedPlan == null,
          hasLoaded: true,
          revision: state.revision + 1,
          clearError: true,
        );
      } catch (error) {
        if (ref.mounted) {
          state = state.copyWith(error: _errorMessage(error));
        }

        rethrow;
      } finally {
        if (ref.mounted) {
          state = state.copyWith(isLoading: false);
        }
      }
    });
  }

  // ===================================================
  // REFRESH
  // ===================================================

  Future<void> refresh() {
    return loadPlan();
  }

  // ===================================================
  // SAVE FINANCE PLAN
  // ===================================================

  Future<void> savePlan(FinancePlan newPlan) {
    return _exclusive(() async {
      if (!ref.mounted) {
        throw StateError('Pengelola Finance Plan sudah ditutup.');
      }

      state = state.copyWith(isSaving: true, clearError: true);

      try {
        // Simpan terlebih dahulu ke perangkat.
        await _repository.savePlan(newPlan);

        if (!ref.mounted) return;

        // Perbarui UI hanya setelah simpan berhasil.
        state = state.copyWith(
          plan: newPlan,
          hasLoaded: true,
          revision: state.revision + 1,
          clearError: true,
        );
      } catch (error) {
        if (ref.mounted) {
          state = state.copyWith(error: _errorMessage(error));
        }

        rethrow;
      } finally {
        if (ref.mounted) {
          state = state.copyWith(isSaving: false);
        }
      }
    });
  }

  // ===================================================
  // RESET FINANCE PLAN
  // ===================================================

  Future<void> clearPlan() {
    return _exclusive(() async {
      if (!ref.mounted) {
        throw StateError('Pengelola Finance Plan sudah ditutup.');
      }

      state = state.copyWith(isSaving: true, clearError: true);

      try {
        // Hanya menghapus rencana keuangan.
        // Data transaksi dan tabungan tidak disentuh.
        await _repository.clearPlan();

        if (!ref.mounted) return;

        state = state.copyWith(
          clearPlan: true,
          hasLoaded: true,
          revision: state.revision + 1,
          clearError: true,
        );
      } catch (error) {
        if (ref.mounted) {
          state = state.copyWith(error: _errorMessage(error));
        }

        rethrow;
      } finally {
        if (ref.mounted) {
          state = state.copyWith(isSaving: false);
        }
      }
    });
  }

  // ===================================================
  // CLEAR ERROR
  // ===================================================

  void clearError() {
    if (!ref.mounted) return;

    state = state.copyWith(clearError: true);
  }
}
