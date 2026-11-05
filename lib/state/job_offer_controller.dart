
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/job_offer_repository.dart';
import '../models/job_offer.dart';

class JobOfferController extends ChangeNotifier {
  JobOfferController(this._repository);

  final JobOfferRepository _repository;

  // =========================================================
  // STATE
  // =========================================================

  List<JobOffer> _offers = <JobOffer>[];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasLoaded = false;
  bool _isDisposed = false;

  String? _errorMessage;

  // Mengantre operasi agar pembaruan state tetap berurutan.
  Future<void> _operationQueue = Future<void>.value();

  // =========================================================
  // GETTERS STATUS
  // =========================================================

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get isBusy => _isLoading || _isSaving;

  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  bool get hasError => _errorMessage != null;

  // =========================================================
  // GETTERS DATA
  // =========================================================

  List<JobOffer> get allOffers {
    return List<JobOffer>.unmodifiable(_offers);
  }

  List<JobOffer> get activeOffers {
    return List<JobOffer>.unmodifiable(
      _offers.where((offer) => !offer.isArchived),
    );
  }

  List<JobOffer> get archivedOffers {
    return List<JobOffer>.unmodifiable(
      _offers.where((offer) => offer.isArchived),
    );
  }

  bool get hasActiveOffers => activeOffers.isNotEmpty;

  bool get hasArchivedOffers => archivedOffers.isNotEmpty;

  int get totalOffers => _offers.length;

  int get activeCount {
    return _offers
        .where((offer) => !offer.isArchived)
        .length;
  }

  int get archivedCount {
    return _offers
        .where((offer) => offer.isArchived)
        .length;
  }

  int get evaluatedOffersCount {
    return _offers.where((offer) {
      return !offer.isArchived &&
          offer.worthScore != null;
    }).length;
  }

  // =========================================================
  // PERINGKAT TAWARAN PEKERJAAN
  // =========================================================

  List<JobOffer> get rankedActiveOffers {
    final ranked = JobOffer.rankOffers(activeOffers);

    return List<JobOffer>.unmodifiable(ranked);
  }

  List<JobOffer> get rankedAllOffers {
    final ranked = JobOffer.rankOffers(_offers);

    return List<JobOffer>.unmodifiable(ranked);
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

    if (evaluated.isEmpty) {
      return null;
    }

    var total = 0;

    for (final offer in evaluated) {
      total += offer.worthScore!;
    }

    return total / evaluated.length;
  }

  // =========================================================
  // MENCARI TAWARAN BERDASARKAN ID
  // =========================================================

  JobOffer? findOfferById(String id) {
    for (final offer in _offers) {
      if (offer.id == id) {
        return offer;
      }
    }

    return null;
  }

  // =========================================================
  // NOTIFIKASI AMAN
  // =========================================================

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // =========================================================
  // ANTREAN OPERASI
  // =========================================================

  Future<T> _runExclusive<T>(
    Future<T> Function() action,
  ) async {
    final previous = _operationQueue;
    final completion = Completer<void>();

    _operationQueue = completion.future;

    await previous;

    try {
      return await action();
    } finally {
      completion.complete();
    }
  }

  // =========================================================
  // PESAN ERROR
  // =========================================================

  String _describeError(Object error) {
    if (error is JobOfferRepositoryException) {
      return error.message;
    }

    if (error is ArgumentError) {
      return error.message?.toString() ??
          'Data yang dimasukkan tidak valid.';
    }

    if (error is StateError) {
      return error.message;
    }

    return 'Terjadi kesalahan saat memproses '
        'tawaran pekerjaan: $error';
  }

  void clearError() {
    if (_errorMessage == null) return;

    _errorMessage = null;
    _notify();
  }

  // =========================================================
  // INISIALISASI
  // =========================================================

  Future<bool> initialize() {
    return loadOffers();
  }

  // =========================================================
  // MEMUAT SELURUH DATA
  // =========================================================

  Future<bool> loadOffers() {
    return _runExclusive(() async {
      if (_isDisposed) return false;

      _isLoading = true;
      _errorMessage = null;
      _notify();

      try {
        final loaded = await _repository.loadOffers(
          includeArchived: true,
        );

        _offers = List<JobOffer>.unmodifiable(loaded);
        _hasLoaded = true;

        return true;
      } catch (error) {
        _errorMessage = _describeError(error);

        return false;
      } finally {
        _isLoading = false;
        _notify();
      }
    });
  }

  // =========================================================
  // REFRESH DATA
  // =========================================================

  Future<bool> refresh() {
    return loadOffers();
  }

  // =========================================================
  // HELPER UNTUK OPERASI SIMPAN / UBAH / HAPUS
  // =========================================================

  Future<bool> _performMutation(
    Future<void> Function() mutation,
  ) {
    return _runExclusive(() async {
      if (_isDisposed) return false;

      _isSaving = true;
      _errorMessage = null;
      _notify();

      try {
        // Jalankan operasi repository.
        await mutation();

        // Muat ulang seluruh tawaran agar cache, arsip,
        // dan hasil peringkat selalu konsisten.
        final refreshed = await _repository.loadOffers(
          includeArchived: true,
        );

        _offers = List<JobOffer>.unmodifiable(refreshed);
        _hasLoaded = true;

        return true;
      } catch (error) {
        _errorMessage = _describeError(error);

        return false;
      } finally {
        _isSaving = false;
        _notify();
      }
    });
  }

  // =========================================================
  // MEMBUAT TAWARAN PEKERJAAN
  // =========================================================

  Future<bool> createOffer(JobOffer offer) {
    return _performMutation(() async {
      await _repository.createOffer(offer);
    });
  }

  // =========================================================
  // MENGEDIT TAWARAN PEKERJAAN
  // =========================================================

  Future<bool> updateOffer(JobOffer offer) {
    return _performMutation(() async {
      await _repository.updateOffer(offer);
    });
  }

  // =========================================================
  // SIMPAN ATAU PERBARUI TAWARAN
  // =========================================================

  Future<bool> saveOffer(JobOffer offer) {
    return _performMutation(() async {
      await _repository.saveOffer(offer);
    });
  }

  // =========================================================
  // ARSIPKAN TAWARAN PEKERJAAN
  // =========================================================

  Future<bool> archiveOffer(String id) {
    return _performMutation(() async {
      await _repository.archiveOffer(id);
    });
  }

  // =========================================================
  // PULIHKAN TAWARAN PEKERJAAN
  // =========================================================

  Future<bool> restoreOffer(String id) {
    return _performMutation(() async {
      await _repository.restoreOffer(id);
    });
  }

  // =========================================================
  // HAPUS TAWARAN SECARA PERMANEN
  // =========================================================

  Future<bool> deleteOffer(String id) {
    return _performMutation(() async {
      final deleted = await _repository.deleteOffer(id);

      if (!deleted) {
        throw StateError(
          'Tawaran pekerjaan yang ingin dihapus '
          'tidak ditemukan.',
        );
      }
    });
  }

  // =========================================================
  // FILTER BERDASARKAN HASIL REKOMENDASI
  // =========================================================

  List<JobOffer> offersByVerdict(
    JobWorthVerdict verdict, {
    bool includeArchived = false,
  }) {
    final source =
        includeArchived ? _offers : activeOffers;

    return List<JobOffer>.unmodifiable(
      source.where(
        (offer) => offer.worthVerdict == verdict,
      ),
    );
  }

  // =========================================================
  // FILTER BERDASARKAN PERUSAHAAN
  // =========================================================

  List<JobOffer> offersByCompany(
    String company, {
    bool includeArchived = false,
  }) {
    final query = company.trim().toLowerCase();

    if (query.isEmpty) {
      return includeArchived ? allOffers : activeOffers;
    }

    final source =
        includeArchived ? _offers : activeOffers;

    return List<JobOffer>.unmodifiable(
      source.where(
        (offer) =>
            offer.company.toLowerCase().contains(query),
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
