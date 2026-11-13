
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celeng_id/data/job_offer_repository.dart';
import 'package:celeng_id/models/job_offer.dart';
import 'package:celeng_id/state/job_offer_notifier.dart';

// =====================================================
// FINPLAN - JOB OFFER RIVERPOD TEST
// VERSION: FAKE REPOSITORY FIX
// =====================================================
//
// Fake implements repository, bukan extends repository.
// Tidak membuat instance SharedPreferencesAsync.
// Data test hanya berada di memori.
// =====================================================

class MemoryJobOfferRepository extends Fake
    implements JobOfferRepository {
  final Map<String, JobOffer> _offers = {};

  @override
  Future<List<JobOffer>> loadOffers({
    bool includeArchived = false,
  }) async {
    final result = _offers.values.where((offer) {
      return includeArchived || !offer.isArchived;
    }).toList();

    result.sort(
      (a, b) => b.updatedAt.compareTo(a.updatedAt),
    );

    return List<JobOffer>.unmodifiable(result);
  }

  @override
  Future<JobOffer> createOffer(JobOffer offer) async {
    if (_offers.containsKey(offer.id)) {
      throw const JobOfferRepositoryException(
        'Tawaran kerja sudah tersedia.',
      );
    }

    _offers[offer.id] = offer;
    return offer;
  }

  @override
  Future<JobOffer> updateOffer(JobOffer offer) async {
    if (!_offers.containsKey(offer.id)) {
      throw const JobOfferRepositoryException(
        'Tawaran kerja tidak ditemukan.',
      );
    }

    final updated = offer.copyWith();
    _offers[offer.id] = updated;

    return updated;
  }

  @override
  Future<JobOffer> saveOffer(JobOffer offer) async {
    final saved = _offers.containsKey(offer.id)
        ? offer.copyWith()
        : offer;

    _offers[offer.id] = saved;
    return saved;
  }

  @override
  Future<JobOffer> archiveOffer(String id) async {
    final offer = _offers[id];

    if (offer == null) {
      throw const JobOfferRepositoryException(
        'Tawaran kerja tidak ditemukan.',
      );
    }

    final updated = offer.copyWith(
      isArchived: true,
    );

    _offers[id] = updated;
    return updated;
  }

  @override
  Future<JobOffer> restoreOffer(String id) async {
    final offer = _offers[id];

    if (offer == null) {
      throw const JobOfferRepositoryException(
        'Tawaran kerja tidak ditemukan.',
      );
    }

    final updated = offer.copyWith(
      isArchived: false,
    );

    _offers[id] = updated;
    return updated;
  }

  @override
  Future<bool> deleteOffer(String id) async {
    return _offers.remove(id) != null;
  }
}

// =====================================================
// UNIT TEST
// =====================================================

void main() {
  late ProviderContainer container;
  late MemoryJobOfferRepository repository;

  setUp(() {
    repository = MemoryJobOfferRepository();

    container = ProviderContainer(
      overrides: [
        jobOfferRepositoryProvider.overrideWithValue(
          repository,
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // TEST 1
  test('State awal kosong - Fake Repository Fix', () {
    final state = container.read(jobOffersProvider);

    expect(state.offers, isEmpty);
    expect(state.activeOffers, isEmpty);
    expect(state.archivedOffers, isEmpty);

    expect(state.totalOffers, 0);
    expect(state.activeCount, 0);
    expect(state.archivedCount, 0);

    expect(state.isLoading, isFalse);
    expect(state.isSaving, isFalse);
    expect(state.hasLoaded, isFalse);
    expect(state.hasError, isFalse);
  });

  // TEST 2
  test('Berhasil load tawaran kerja', () async {
    final notifier = container.read(
      jobOffersProvider.notifier,
    );

    final success = await notifier.loadOffers();

    expect(success, isTrue);

    final state = container.read(jobOffersProvider);

    expect(state.hasLoaded, isTrue);
    expect(state.offers, isEmpty);
    expect(state.isLoading, isFalse);
    expect(state.errorMessage, isNull);
  });

  // TEST 3
  test('Berhasil create tawaran kerja', () async {
    final notifier = container.read(
      jobOffersProvider.notifier,
    );

    final offer = JobOffer.create(
      title: 'Software Engineer',
      company: 'PT Teknologi Indonesia',
      location: 'Jakarta',
    );

    final success = await notifier.createOffer(offer);

    expect(success, isTrue);

    final state = container.read(jobOffersProvider);

    expect(state.totalOffers, 1);
    expect(state.activeCount, 1);
    expect(state.archivedCount, 0);

    expect(
      state.activeOffers.first.title,
      'Software Engineer',
    );

    expect(
      state.activeOffers.first.company,
      'PT Teknologi Indonesia',
    );

    expect(state.findOfferById(offer.id), isNotNull);
  });

  // TEST 4
  test('Berhasil update tawaran kerja', () async {
    final notifier = container.read(
      jobOffersProvider.notifier,
    );

    final offer = JobOffer.create(
      title: 'IT Support',
      company: 'PT ABC',
    );

    expect(
      await notifier.createOffer(offer),
      isTrue,
    );

    final updatedOffer = offer.copyWith(
      title: 'Senior IT Support',
      salaryRate: 7500000,
    );

    final success = await notifier.updateOffer(
      updatedOffer,
    );

    expect(success, isTrue);

    final saved = container
        .read(jobOffersProvider)
        .findOfferById(offer.id);

    expect(saved, isNotNull);
    expect(saved!.title, 'Senior IT Support');
    expect(saved.salaryRate, 7500000);
    expect(saved.id, offer.id);
  });

  // TEST 5
  test('Berhasil archive tawaran kerja', () async {
    final notifier = container.read(
      jobOffersProvider.notifier,
    );

    final offer = JobOffer.create(
      title: 'Data Analyst',
    );

    await notifier.createOffer(offer);

    final success = await notifier.archiveOffer(
      offer.id,
    );

    expect(success, isTrue);

    final state = container.read(jobOffersProvider);

    expect(state.activeCount, 0);
    expect(state.archivedCount, 1);
    expect(state.archivedOffers.first.id, offer.id);
    expect(state.archivedOffers.first.isArchived, isTrue);
  });

  // TEST 6
  test('Berhasil restore tawaran kerja', () async {
    final notifier = container.read(
      jobOffersProvider.notifier,
    );

    final offer = JobOffer.create(
      title: 'Flutter Developer',
    );

    await notifier.createOffer(offer);
    await notifier.archiveOffer(offer.id);

    final success = await notifier.restoreOffer(
      offer.id,
    );

    expect(success, isTrue);

    final state = container.read(jobOffersProvider);

    expect(state.activeCount, 1);
    expect(state.archivedCount, 0);
    expect(state.activeOffers.first.id, offer.id);
    expect(state.activeOffers.first.isArchived, isFalse);
  });

  // TEST 7
  test('Berhasil delete tawaran kerja', () async {
    final notifier = container.read(
      jobOffersProvider.notifier,
    );

    final offer = JobOffer.create(
      title: 'Backend Developer',
    );

    await notifier.createOffer(offer);

    expect(
      container.read(jobOffersProvider).totalOffers,
      1,
    );

    final success = await notifier.deleteOffer(
      offer.id,
    );

    expect(success, isTrue);

    final state = container.read(jobOffersProvider);

    expect(state.totalOffers, 0);
    expect(state.findOfferById(offer.id), isNull);
  });

  // TEST 8
  test('Delete ID tidak ditemukan menampilkan error',
      () async {
    final notifier = container.read(
      jobOffersProvider.notifier,
    );

    final success = await notifier.deleteOffer(
      'tidak-ada',
    );

    expect(success, isFalse);

    var state = container.read(jobOffersProvider);

    expect(state.hasError, isTrue);
    expect(state.errorMessage, isNotNull);

    notifier.clearError();

    state = container.read(jobOffersProvider);

    expect(state.hasError, isFalse);
    expect(state.errorMessage, isNull);
  });

  // TEST 9
  test('SaveOffer tidak membuat data duplikat',
      () async {
    final notifier = container.read(
      jobOffersProvider.notifier,
    );

    final offer = JobOffer.create(
      title: 'Mobile Developer',
    );

    expect(
      await notifier.saveOffer(offer),
      isTrue,
    );

    final edited = offer.copyWith(
      company: 'PT FinPlan',
    );

    expect(
      await notifier.saveOffer(edited),
      isTrue,
    );

    final state = container.read(jobOffersProvider);

    expect(state.totalOffers, 1);

    expect(
      state.findOfferById(offer.id)?.company,
      'PT FinPlan',
    );
  });

  // TEST 10
  test('ProviderContainer terisolasi tanpa plugin',
      () async {
    final secondRepository =
        MemoryJobOfferRepository();

    final secondContainer = ProviderContainer(
      overrides: [
        jobOfferRepositoryProvider.overrideWithValue(
          secondRepository,
        ),
      ],
    );

    addTearDown(secondContainer.dispose);

    final notifier = container.read(
      jobOffersProvider.notifier,
    );

    final offer = JobOffer.create(
      title: 'UI UX Designer',
    );

    await notifier.createOffer(offer);

    expect(
      container.read(jobOffersProvider).totalOffers,
      1,
    );

    expect(
      secondContainer.read(jobOffersProvider).totalOffers,
      0,
    );
  });
}
