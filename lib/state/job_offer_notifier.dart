import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/job_offer_repository.dart';
import '../models/job_offer.dart';

// ======================================================
// FINPLAN - JOB OFFER RIVERPOD
// ======================================================

// Repository yang sama dengan aplikasi sebelumnya.
// Format penyimpanan tawaran kerja tidak berubah.
final jobOfferRepositoryProvider = Provider<JobOfferRepository>((ref) {
  return JobOfferRepository();
});

// ======================================================
// STATE
// ======================================================

class JobOffersState {
  const JobOffersState({
    this.offers = const <JobOffer>[],
    this.isLoading = false,
    this.isSaving = false,
    this.hasLoaded = false,
    this.errorMessage,
  });

  final List<JobOffer> offers;
  final bool isLoading;
  final bool isSaving;
  final bool hasLoaded;
  final String? errorMessage;

  bool get isBusy => isLoading || isSaving;

  bool get hasError => errorMessage != null;

  List<JobOffer> get allOffers {
    return List<JobOffer>.unmodifiable(offers);
  }

  List<JobOffer> get activeOffers {
    return List<JobOffer>.unmodifiable(
      offers.where((offer) => !offer.isArchived),
    );
  }

  List<JobOffer> get archivedOffers {
    return List<JobOffer>.unmodifiable(
      offers.where((offer) => offer.isArchived),
    );
  }

  bool get hasActiveOffers => activeOffers.isNotEmpty;

  bool get hasArchivedOffers => archivedOffers.isNotEmpty;

  int get totalOffers => offers.length;

  int get activeCount => activeOffers.length;

  int get archivedCount => archivedOffers.length;

  int get evaluatedOffersCount {
    return activeOffers.where((offer) => offer.worthScore != null).length;
  }

  List<JobOffer> get rankedActiveOffers {
    return List<JobOffer>.unmodifiable(JobOffer.rankOffers(activeOffers));
  }

  List<JobOffer> get rankedAllOffers {
    return List<JobOffer>.unmodifiable(JobOffer.rankOffers(allOffers));
  }

  JobOffer? get bestRatedOffer {
    for (final offer in rankedActiveOffers) {
      if (offer.worthScore != null) {
        return offer;
      }
    }
    return null;
  }

  double? get averageWorthScore {
    final evaluated = activeOffers
        .where((offer) => offer.worthScore != null)
        .toList();

    if (evaluated.isEmpty) return null;

    var total = 0.0;

    for (final offer in evaluated) {
      total += offer.worthScore!;
    }

    return total / evaluated.length;
  }

  JobOffer? findOfferById(String id) {
    for (final offer in offers) {
      if (offer.id == id) return offer;
    }
    return null;
  }

  List<JobOffer> offersByCompany(
    String company, {
    bool includeArchived = false,
  }) {
    final query = company.trim().toLowerCase();

    final source = includeArchived ? allOffers : activeOffers;

    return List<JobOffer>.unmodifiable(
      source.where((offer) => offer.company.toLowerCase().contains(query)),
    );
  }

  List<JobOffer> offersByVerdict(
    JobWorthVerdict verdict, {
    bool includeArchived = false,
  }) {
    final source = includeArchived ? allOffers : activeOffers;

    return List<JobOffer>.unmodifiable(
      source.where((offer) => offer.worthVerdict == verdict),
    );
  }

  JobOffersState copyWith({
    List<JobOffer>? offers,
    bool? isLoading,
    bool? isSaving,
    bool? hasLoaded,
    String? errorMessage,
    bool clearError = false,
  }) {
    return JobOffersState(
      offers: offers == null
          ? this.offers
          : List<JobOffer>.unmodifiable(offers),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

// ======================================================
// RIVERPOD PROVIDER
// ======================================================

final jobOffersProvider = NotifierProvider<JobOffersNotifier, JobOffersState>(
  JobOffersNotifier.new,
);

// ======================================================
// NOTIFIER
// ======================================================

class JobOffersNotifier extends Notifier<JobOffersState> {
  Future<void> _operationQueue = Future<void>.value();
  bool _disposed = false;

  JobOfferRepository get _repository => ref.read(jobOfferRepositoryProvider);

  @override
  JobOffersState build() {
    _disposed = false;

    ref.onDispose(() {
      _disposed = true;
    });

    return const JobOffersState();
  }

  // Menjalankan operasi berurutan untuk mencegah
  // perubahan state saling menimpa.
  Future<T> _runExclusive<T>(Future<T> Function() operation) async {
    final previous = _operationQueue;
    final completer = Completer<void>();

    _operationQueue = completer.future;

    await previous;

    try {
      return await operation();
    } finally {
      completer.complete();
    }
  }

  String _describeError(Object error) {
    if (error is JobOfferRepositoryException) {
      return error.message;
    }

    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Data tawaran kerja tidak valid.';
    }

    if (error is StateError) {
      return error.message;
    }

    return 'Gagal memproses tawaran kerja: $error';
  }

  void clearError() {
    if (_disposed || state.errorMessage == null) {
      return;
    }

    state = state.copyWith(clearError: true);
  }

  // ====================================================
  // LOAD
  // ====================================================

  Future<bool> initialize() => loadOffers();

  Future<bool> refresh() => loadOffers();

  Future<bool> loadOffers() {
    return _runExclusive(() async {
      if (_disposed) return false;

      state = state.copyWith(isLoading: true, clearError: true);

      try {
        final loaded = await _repository.loadOffers(includeArchived: true);

        if (_disposed) return false;

        state = state.copyWith(
          offers: loaded,
          hasLoaded: true,
          clearError: true,
        );

        return true;
      } catch (error) {
        if (!_disposed) {
          state = state.copyWith(errorMessage: _describeError(error));
        }

        return false;
      } finally {
        if (!_disposed) {
          state = state.copyWith(isLoading: false);
        }
      }
    });
  }

  // ====================================================
  // MUTATION HELPER
  // ====================================================

  Future<bool> _performMutation(Future<void> Function() mutation) {
    return _runExclusive(() async {
      if (_disposed) return false;

      state = state.copyWith(isSaving: true, clearError: true);

      try {
        await mutation();

        // Reload setelah perubahan berhasil disimpan.
        final refreshed = await _repository.loadOffers(includeArchived: true);

        if (_disposed) return false;

        state = state.copyWith(
          offers: refreshed,
          hasLoaded: true,
          clearError: true,
        );

        return true;
      } catch (error) {
        if (!_disposed) {
          state = state.copyWith(errorMessage: _describeError(error));
        }

        return false;
      } finally {
        if (!_disposed) {
          state = state.copyWith(isSaving: false);
        }
      }
    });
  }

  // ====================================================
  // CREATE
  // ====================================================

  Future<bool> createOffer(JobOffer offer) {
    return _performMutation(() async {
      await _repository.createOffer(offer);
    });
  }

  // ====================================================
  // UPDATE
  // ====================================================

  Future<bool> updateOffer(JobOffer offer) {
    return _performMutation(() async {
      await _repository.updateOffer(offer);
    });
  }

  // ====================================================
  // SAVE (CREATE OR UPDATE)
  // ====================================================

  Future<bool> saveOffer(JobOffer offer) {
    return _performMutation(() async {
      await _repository.saveOffer(offer);
    });
  }

  // ====================================================
  // ARCHIVE
  // ====================================================

  Future<bool> archiveOffer(String id) {
    return _performMutation(() async {
      await _repository.archiveOffer(id);
    });
  }

  // ====================================================
  // RESTORE
  // ====================================================

  Future<bool> restoreOffer(String id) {
    return _performMutation(() async {
      await _repository.restoreOffer(id);
    });
  }

  // ====================================================
  // DELETE
  // ====================================================

  Future<bool> deleteOffer(String id) {
    return _performMutation(() async {
      final deleted = await _repository.deleteOffer(id);

      if (!deleted) {
        throw StateError(
          'Tawaran kerja yang ingin dihapus '
          'tidak ditemukan.',
        );
      }
    });
  }

  // ====================================================
  // HELPERS
  // ====================================================

  JobOffer? findOfferById(String id) {
    return state.findOfferById(id);
  }

  List<JobOffer> offersByCompany(
    String company, {
    bool includeArchived = false,
  }) {
    return state.offersByCompany(company, includeArchived: includeArchived);
  }

  List<JobOffer> offersByVerdict(
    JobWorthVerdict verdict, {
    bool includeArchived = false,
  }) {
    return state.offersByVerdict(verdict, includeArchived: includeArchived);
  }
}
