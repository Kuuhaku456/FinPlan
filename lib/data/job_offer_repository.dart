
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/job_offer.dart';

class JobOfferRepositoryException implements Exception {
  const JobOfferRepositoryException(
    this.message, [
    this.cause,
  ]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    return 'JobOfferRepositoryException: $message';
  }
}

class JobOfferRepository {
  JobOfferRepository({
    SharedPreferencesAsync? preferences,
  }) : _preferences =
           preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const String _storageKey =
      'finplan_job_offers_v1';

  static const int _schemaVersion = 1;

  // Mengurutkan operasi dalam satu isolate.
  // Mencegah dua operasi dalam aplikasi membaca data lama
  // lalu saling menimpa hasil perubahan.
  static Future<void> _operationQueue = Future<void>.value();

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
  // MEMBACA DATA DARI SHARED PREFERENCES
  // =========================================================

  Future<List<JobOffer>> _readAllUnlocked() async {
    final raw = await _preferences.getString(
      _storageKey,
    );

    if (raw == null || raw.trim().isEmpty) {
      return <JobOffer>[];
    }

    try {
      final decoded = jsonDecode(raw);

      late final List<dynamic> records;

      // Dukungan jika suatu saat data lama disimpan
      // langsung sebagai JSON array.
      if (decoded is List) {
        records = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final version = decoded['schemaVersion'];

        if (version != _schemaVersion) {
          throw JobOfferRepositoryException(
            'Versi penyimpanan tawaran pekerjaan '
            'tidak didukung: $version.',
          );
        }

        final savedOffers = decoded['offers'];

        if (savedOffers is! List) {
          throw const JobOfferRepositoryException(
            'Format daftar tawaran pekerjaan tidak valid.',
          );
        }

        records = savedOffers;
      } else {
        throw const JobOfferRepositoryException(
          'Format penyimpanan tawaran pekerjaan '
          'tidak dikenali.',
        );
      }

      final offers = <JobOffer>[];
      final usedIds = <String>{};

      for (final record in records) {
        if (record is! Map) {
          throw const JobOfferRepositoryException(
            'Terdapat data tawaran pekerjaan '
            'dengan format tidak valid.',
          );
        }

        final data = Map<String, dynamic>.from(record);

        final id = data['id'];

        if (id is! String || id.trim().isEmpty) {
          throw const JobOfferRepositoryException(
            'Terdapat tawaran pekerjaan tanpa ID valid.',
          );
        }

        if (!usedIds.add(id)) {
          throw JobOfferRepositoryException(
            'Ditemukan ID tawaran pekerjaan '
            'yang duplikat: $id.',
          );
        }

        offers.add(JobOffer.fromJson(data));
      }

      return offers;
    } on JobOfferRepositoryException {
      rethrow;
    } catch (error) {
      throw JobOfferRepositoryException(
        'Gagal membaca data tawaran pekerjaan. '
        'Data lama tidak akan ditimpa secara otomatis.',
        error,
      );
    }
  }

  // =========================================================
  // MENYIMPAN DATA
  // =========================================================

  Future<void> _writeAllUnlocked(
    List<JobOffer> offers,
  ) async {
    try {
      final payload = <String, dynamic>{
        'schemaVersion': _schemaVersion,
        'updatedAt': DateTime.now().toIso8601String(),
        'offers': offers
            .map((offer) => offer.toJson())
            .toList(),
      };

      final encoded = jsonEncode(payload);

      await _preferences.setString(
        _storageKey,
        encoded,
      );
    } catch (error) {
      throw JobOfferRepositoryException(
        'Gagal menyimpan data tawaran pekerjaan.',
        error,
      );
    }
  }

  // =========================================================
  // VALIDASI
  // =========================================================

  void _validateOffer(JobOffer offer) {
    if (offer.id.trim().isEmpty) {
      throw ArgumentError(
        'ID tawaran pekerjaan tidak boleh kosong.',
      );
    }

    if (offer.title.trim().isEmpty) {
      throw ArgumentError(
        'Nama posisi pekerjaan tidak boleh kosong.',
      );
    }
  }

  void _validateId(String id) {
    if (id.trim().isEmpty) {
      throw ArgumentError(
        'ID tawaran pekerjaan tidak boleh kosong.',
      );
    }
  }

  // =========================================================
  // PENGURUTAN DATA
  // =========================================================

  List<JobOffer> _sortByRecent(
    Iterable<JobOffer> offers,
  ) {
    final sorted = offers.toList();

    sorted.sort((a, b) {
      final updatedComparison =
          b.updatedAt.compareTo(a.updatedAt);

      if (updatedComparison != 0) {
        return updatedComparison;
      }

      final createdComparison =
          b.createdAt.compareTo(a.createdAt);

      if (createdComparison != 0) {
        return createdComparison;
      }

      return a.id.compareTo(b.id);
    });

    return List<JobOffer>.unmodifiable(sorted);
  }

  // =========================================================
  // MEMUAT SELURUH TAWARAN
  // =========================================================

  Future<List<JobOffer>> loadOffers({
    bool includeArchived = false,
  }) {
    return _runExclusive(() async {
      final offers = await _readAllUnlocked();

      final filtered = includeArchived
          ? offers
          : offers
              .where((offer) => !offer.isArchived)
              .toList();

      return _sortByRecent(filtered);
    });
  }

  // =========================================================
  // MEMUAT TAWARAN AKTIF
  // =========================================================

  Future<List<JobOffer>> loadActiveOffers() {
    return loadOffers();
  }

  // =========================================================
  // MEMUAT TAWARAN ARSIP
  // =========================================================

  Future<List<JobOffer>> loadArchivedOffers() {
    return _runExclusive(() async {
      final offers = await _readAllUnlocked();

      return _sortByRecent(
        offers.where((offer) => offer.isArchived),
      );
    });
  }

  // =========================================================
  // MENCARI TAWARAN BERDASARKAN ID
  // =========================================================

  Future<JobOffer?> getOfferById(String id) {
    _validateId(id);

    return _runExclusive(() async {
      final offers = await _readAllUnlocked();

      for (final offer in offers) {
        if (offer.id == id) {
          return offer;
        }
      }

      return null;
    });
  }

  // =========================================================
  // MEMERIKSA APAKAH TAWARAN SUDAH ADA
  // =========================================================

  Future<bool> offerExists(String id) async {
    final offer = await getOfferById(id);
    return offer != null;
  }

  // =========================================================
  // MENAMBAH TAWARAN BARU
  // =========================================================

  Future<JobOffer> createOffer(JobOffer offer) {
    _validateOffer(offer);

    return _runExclusive(() async {
      final offers = await _readAllUnlocked();

      final duplicate = offers.any(
        (item) => item.id == offer.id,
      );

      if (duplicate) {
        throw JobOfferRepositoryException(
          'Tawaran pekerjaan dengan ID '
          '${offer.id} sudah tersedia.',
        );
      }

      offers.add(offer);

      await _writeAllUnlocked(offers);

      return offer;
    });
  }

  // =========================================================
  // MEMPERBARUI TAWARAN
  // =========================================================

  Future<JobOffer> updateOffer(JobOffer offer) {
    _validateOffer(offer);

    return _runExclusive(() async {
      final offers = await _readAllUnlocked();

      final index = offers.indexWhere(
        (item) => item.id == offer.id,
      );

      if (index == -1) {
        throw JobOfferRepositoryException(
          'Tawaran pekerjaan yang ingin '
          'diperbarui tidak ditemukan.',
        );
      }

      // copyWith() pada JobOffer memperbarui updatedAt.
      final updatedOffer = offer.copyWith();

      offers[index] = updatedOffer;

      await _writeAllUnlocked(offers);

      return updatedOffer;
    });
  }

  // =========================================================
  // MENYIMPAN TAWARAN (TAMBAH ATAU PERBARUI)
  // =========================================================

  Future<JobOffer> saveOffer(JobOffer offer) {
    _validateOffer(offer);

    return _runExclusive(() async {
      final offers = await _readAllUnlocked();

      final index = offers.indexWhere(
        (item) => item.id == offer.id,
      );

      JobOffer savedOffer;

      if (index == -1) {
        savedOffer = offer;
        offers.add(savedOffer);
      } else {
        savedOffer = offer.copyWith();
        offers[index] = savedOffer;
      }

      await _writeAllUnlocked(offers);

      return savedOffer;
    });
  }

  // =========================================================
  // MENGARSIPKAN TAWARAN
  // =========================================================

  Future<JobOffer> archiveOffer(String id) {
    return _setArchiveStatus(
      id,
      archived: true,
    );
  }

  // =========================================================
  // MEMULIHKAN TAWARAN DARI ARSIP
  // =========================================================

  Future<JobOffer> restoreOffer(String id) {
    return _setArchiveStatus(
      id,
      archived: false,
    );
  }

  Future<JobOffer> _setArchiveStatus(
    String id, {
    required bool archived,
  }) {
    _validateId(id);

    return _runExclusive(() async {
      final offers = await _readAllUnlocked();

      final index = offers.indexWhere(
        (item) => item.id == id,
      );

      if (index == -1) {
        throw JobOfferRepositoryException(
          'Tawaran pekerjaan tidak ditemukan.',
        );
      }

      final existing = offers[index];

      // Tidak perlu menulis ulang jika statusnya sama.
      if (existing.isArchived == archived) {
        return existing;
      }

      final updated = existing.copyWith(
        isArchived: archived,
      );

      offers[index] = updated;

      await _writeAllUnlocked(offers);

      return updated;
    });
  }

  // =========================================================
  // MENGHAPUS TAWARAN SECARA PERMANEN
  // =========================================================

  Future<bool> deleteOffer(String id) {
    _validateId(id);

    return _runExclusive(() async {
      final offers = await _readAllUnlocked();

      final originalLength = offers.length;

      offers.removeWhere(
        (offer) => offer.id == id,
      );

      if (offers.length == originalLength) {
        return false;
      }

      await _writeAllUnlocked(offers);

      return true;
    });
  }

  // =========================================================
  // MENGHITUNG JUMLAH TAWARAN
  // =========================================================

  Future<int> countActiveOffers() {
    return _runExclusive(() async {
      final offers = await _readAllUnlocked();

      return offers.where(
        (offer) => !offer.isArchived,
      ).length;
    });
  }

  Future<int> countArchivedOffers() {
    return _runExclusive(() async {
      final offers = await _readAllUnlocked();

      return offers.where(
        (offer) => offer.isArchived,
      ).length;
    });
  }

  // =========================================================
  // MEMUAT TAWARAN BERDASARKAN SKOR WORTH IT
  // =========================================================

  Future<List<JobOffer>> loadRankedOffers({
    bool includeArchived = false,
  }) {
    return _runExclusive(() async {
      final offers = await _readAllUnlocked();

      final filtered = includeArchived
          ? offers
          : offers
              .where((offer) => !offer.isArchived)
              .toList();

      final ranked = JobOffer.rankOffers(filtered);

      return List<JobOffer>.unmodifiable(ranked);
    });
  }
}
