import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../models/job_offer.dart';
import '../state/job_offer_notifier.dart';

enum _OfferSort { recent, score, remainingIncome }

class JobOffersPage extends ConsumerStatefulWidget {
  const JobOffersPage({super.key, required this.onAdd, required this.onEdit});
  final VoidCallback onAdd;
  final ValueChanged<JobOffer> onEdit;

  @override
  ConsumerState<JobOffersPage> createState() => _JobOffersPageState();
}

class _JobOffersPageState extends ConsumerState<JobOffersPage> {
  static const Color darkGreen = Color(0xFF064E3B);
  static const Color green = Color(0xFF10B981);
  static const Color softGreen = Color(0xFFE9F8F0);
  static const Color muted = Color(0xFF84958C);

  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedIds = <String>{};

  bool _showArchived = false;
  _OfferSort _sort = _OfferSort.recent;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!ref.read(jobOffersProvider).hasLoaded &&
          !ref.read(jobOffersProvider).isLoading) {
        unawaited(ref.read(jobOffersProvider.notifier).loadOffers());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<JobOffer> _visibleOffers() {
    List<JobOffer> offers;

    if (_showArchived) {
      offers = List<JobOffer>.from(ref.read(jobOffersProvider).archivedOffers);
    } else {
      switch (_sort) {
        case _OfferSort.recent:
          offers = List<JobOffer>.from(
            ref.read(jobOffersProvider).activeOffers,
          );
          break;

        case _OfferSort.score:
          offers = List<JobOffer>.from(
            ref.read(jobOffersProvider).rankedActiveOffers,
          );
          break;

        case _OfferSort.remainingIncome:
          offers = List<JobOffer>.from(ref.read(jobOffersProvider).activeOffers)
            ..sort(
              (a, b) =>
                  b.remainingMonthlyIncome.compareTo(a.remainingMonthlyIncome),
            );
          break;
      }
    }

    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return offers;

    return offers.where((offer) {
      return offer.title.toLowerCase().contains(query) ||
          offer.company.toLowerCase().contains(query) ||
          offer.location.toLowerCase().contains(query);
    }).toList();
  }

  List<JobOffer> get _selectedOffers {
    return ref
        .read(jobOffersProvider)
        .activeOffers
        .where((offer) => _selectedIds.contains(offer.id))
        .toList();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggleSelection(JobOffer offer) {
    if (_selectedIds.contains(offer.id)) {
      setState(() {
        _selectedIds.remove(offer.id);
      });
      return;
    }

    if (_selectedOffers.length >= 3) {
      _showMessage('Maksimal 3 tawaran untuk dibandingkan.');
      return;
    }

    setState(() {
      _selectedIds.add(offer.id);
    });
  }

  Future<void> _toggleArchive(JobOffer offer) async {
    if (ref.read(jobOffersProvider).isSaving) return;

    final success = offer.isArchived
        ? await ref.read(jobOffersProvider.notifier).restoreOffer(offer.id)
        : await ref.read(jobOffersProvider.notifier).archiveOffer(offer.id);

    if (!mounted) return;

    if (success) {
      setState(() {
        _selectedIds.remove(offer.id);
      });

      _showMessage(
        offer.isArchived
            ? 'Tawaran berhasil dipulihkan.'
            : 'Tawaran berhasil diarsipkan.',
      );
    } else {
      _showMessage(
        ref.read(jobOffersProvider).errorMessage ??
            'Gagal memperbarui tawaran.',
      );
    }
  }

  Future<void> _confirmDelete(JobOffer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Hapus tawaran?'),
          content: Text('"${offer.title}" akan dihapus permanen.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(jobOffersProvider.notifier)
        .deleteOffer(offer.id);

    if (!mounted) return;

    if (success) {
      setState(() {
        _selectedIds.remove(offer.id);
      });

      _showMessage('Tawaran berhasil dihapus.');
    } else {
      _showMessage(
        ref.read(jobOffersProvider).errorMessage ?? 'Gagal menghapus tawaran.',
      );
    }
  }

  Color _statusColor(JobOffer offer) {
    switch (offer.worthVerdict) {
      case JobWorthVerdict.attractive:
        return green;
      case JobWorthVerdict.reasonable:
        return const Color(0xFF0891B2);
      case JobWorthVerdict.incomplete:
        return muted;
      case JobWorthVerdict.financialRisk:
      case JobWorthVerdict.belowTarget:
      case JobWorthVerdict.needsReview:
        return const Color(0xFFE8794B);
    }
  }

  String _sortLabel() {
    switch (_sort) {
      case _OfferSort.recent:
        return 'Terbaru';
      case _OfferSort.score:
        return 'Skor';
      case _OfferSort.remainingIncome:
        return 'Uang tersisa';
    }
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tawaran Kerja',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Temukan pilihan terbaikmu',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Material(
              color: darkGreen,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                onTap: widget.onAdd,
                borderRadius: BorderRadius.circular(15),
                child: const SizedBox(
                  width: 47,
                  height: 47,
                  child: Icon(Icons.add_rounded, color: Colors.white, size: 25),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 19),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF087557), darkGreen],
            ),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TAWARAN AKTIF',
                      style: TextStyle(
                        color: Color(0xFFB7EAD1),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${ref.read(jobOffersProvider).activeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 33,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${ref.read(jobOffersProvider).evaluatedOffersCount} sudah dinilai',
                      style: const TextStyle(
                        color: Color(0xFFC6ECDD),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 69,
                height: 69,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.work_rounded,
                  color: Colors.white,
                  size: 33,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 17),

        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Cari posisi atau perusahaan...',
            hintStyle: const TextStyle(fontSize: 13, color: muted),
            prefixIcon: const Icon(Icons.search_rounded, color: muted),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _filterButton(
                'Aktif',
                ref.read(jobOffersProvider).activeCount,
                !_showArchived,
                () {
                  setState(() {
                    _showArchived = false;
                  });
                },
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _filterButton(
                'Arsip',
                ref.read(jobOffersProvider).archivedCount,
                _showArchived,
                () {
                  setState(() {
                    _showArchived = true;
                    _selectedIds.clear();
                  });
                },
              ),
            ),
          ],
        ),

        if (!_showArchived) ...[
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.sort_rounded, color: muted, size: 19),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Urutkan tawaran',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
              PopupMenuButton<_OfferSort>(
                tooltip: 'Urutkan',
                onSelected: (value) {
                  setState(() {
                    _sort = value;
                  });
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _OfferSort.recent,
                    child: Text('Terbaru'),
                  ),
                  PopupMenuItem(
                    value: _OfferSort.score,
                    child: Text('Skor tertinggi'),
                  ),
                  PopupMenuItem(
                    value: _OfferSort.remainingIncome,
                    child: Text('Uang tersisa'),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sortLabel(),
                      style: const TextStyle(
                        color: darkGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: darkGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 15),
      ],
    );
  }

  Widget _filterButton(
    String title,
    int count,
    bool selected,
    VoidCallback onTap,
  ) {
    return Material(
      color: selected ? darkGreen : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? darkGreen : Theme.of(context).dividerColor,
            ),
          ),
          child: Center(
            child: Text(
              '$title ($count)',
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallMetric(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: green, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(label, style: const TextStyle(color: muted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(JobOffer offer) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedIds.contains(offer.id);
    final score = offer.worthScore;
    final statusColor = _statusColor(offer);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          width: selected ? 1.6 : 1,
          color: selected
              ? green
              : scheme.brightness == Brightness.dark
              ? Colors.white12
              : const Color(0xFFE8F0EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B064E3B),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: softGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: darkGreen,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title.isEmpty ? 'Tanpa nama posisi' : offer.title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer.company.isEmpty
                          ? 'Perusahaan belum diisi'
                          : offer.company,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    if (offer.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: muted,
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              offer.location,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                enabled: !ref.read(jobOffersProvider).isSaving,
                tooltip: 'Opsi tawaran',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      widget.onEdit(offer);
                      break;
                    case 'archive':
                      _toggleArchive(offer);
                      break;
                    case 'delete':
                      _confirmDelete(offer);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Lihat / Edit'),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(offer.isArchived ? 'Pulihkan' : 'Arsipkan'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
                icon: const Icon(Icons.more_vert_rounded, color: muted),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              offer.worthVerdict.label,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'ESTIMASI UANG TERSISA',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(height: 5),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(offer.remainingMonthlyIncome),
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
          ),

          const SizedBox(height: 17),

          Row(
            children: [
              _smallMetric(
                Icons.payments_outlined,
                'Gaji bersih',
                rupiah(offer.takeHomePay),
              ),
              const SizedBox(width: 10),
              _smallMetric(
                Icons.receipt_long_outlined,
                'Biaya kerja',
                rupiah(offer.totalMonthlyWorkCosts),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              _smallMetric(
                Icons.schedule_outlined,
                'Perjalanan / bulan',
                '${offer.monthlyCommuteHours.toStringAsFixed(1)} jam',
              ),
              const SizedBox(width: 10),
              _smallMetric(
                Icons.timelapse_outlined,
                'Efektif / jam',
                rupiah(offer.effectiveHourlyIncome),
              ),
            ],
          ),

          if (score != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Skor Kelayakan',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '$score / 100',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 7,
                backgroundColor: const Color(0xFFE7F1EB),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ],

          const SizedBox(height: 15),

          Row(
            children: [
              TextButton.icon(
                onPressed: () => widget.onEdit(offer),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Lihat Detail'),
                style: TextButton.styleFrom(foregroundColor: green),
              ),
              const Spacer(),
              if (!_showArchived)
                FilterChip(
                  selected: selected,
                  showCheckmark: true,
                  label: Text(selected ? 'Dipilih' : 'Bandingkan'),
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: softGreen,
                  onSelected: (_) => _toggleSelection(offer),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final searching = _searchController.text.trim().isNotEmpty;

    final title = searching
        ? 'Tawaran tidak ditemukan'
        : _showArchived
        ? 'Belum ada arsip'
        : 'Belum ada tawaran';

    final description = searching
        ? 'Coba kata kunci lainnya.'
        : _showArchived
        ? 'Tawaran yang diarsipkan muncul di sini.'
        : 'Tambahkan tawaran pekerjaan pertamamu.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 38),
      child: Column(
        children: [
          Container(
            width: 94,
            height: 94,
            decoration: const BoxDecoration(
              color: softGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              searching ? Icons.search_off_rounded : Icons.work_outline_rounded,
              color: darkGreen,
              size: 42,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          if (!_showArchived && !searching) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: widget.onAdd,
              style: FilledButton.styleFrom(backgroundColor: darkGreen),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Tawaran'),
            ),
          ],
        ],
      ),
    );
  }

  DataRow _comparisonRow(
    String label,
    List<JobOffer> offers,
    String Function(JobOffer) formatter,
  ) {
    return DataRow(
      cells: [
        DataCell(Text(label)),
        for (final offer in offers) DataCell(Text(formatter(offer))),
      ],
    );
  }

  Future<void> _showComparison() async {
    final selected = _selectedOffers;

    if (selected.length < 2) {
      _showMessage('Pilih minimal 2 tawaran.');
      return;
    }

    final ranked = JobOffer.rankOffers(selected);

    final evaluated = ranked.where((offer) => offer.worthScore != null);

    final best = evaluated.isEmpty ? null : evaluated.first;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 9, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.compare_arrows_rounded, color: green, size: 24),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Bandingkan Tawaran',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${ranked.length} pekerjaan dipilih',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 17),

                Expanded(
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 20,
                        headingRowHeight: 55,
                        dataRowMinHeight: 50,
                        dataRowMaxHeight: 85,
                        columns: [
                          const DataColumn(label: Text('Aspek')),
                          for (final offer in ranked)
                            DataColumn(
                              label: SizedBox(
                                width: 115,
                                child: Text(
                                  offer.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                        rows: [
                          _comparisonRow(
                            'Perusahaan',
                            ranked,
                            (o) => o.company.isEmpty ? '-' : o.company,
                          ),
                          _comparisonRow(
                            'Gaji bruto',
                            ranked,
                            (o) => rupiah(o.grossMonthlyIncome),
                          ),
                          _comparisonRow(
                            'Gaji bersih',
                            ranked,
                            (o) => rupiah(o.takeHomePay),
                          ),
                          _comparisonRow(
                            'Biaya kerja',
                            ranked,
                            (o) => rupiah(o.totalMonthlyWorkCosts),
                          ),
                          _comparisonRow(
                            'Uang tersisa',
                            ranked,
                            (o) => rupiah(o.remainingMonthlyIncome),
                          ),
                          _comparisonRow(
                            'Perjalanan',
                            ranked,
                            (o) =>
                                '${o.monthlyCommuteHours.toStringAsFixed(1)} jam',
                          ),
                          _comparisonRow(
                            'Jarak / bulan',
                            ranked,
                            (o) =>
                                '${o.monthlyCommuteDistance.toStringAsFixed(1)} km',
                          ),
                          _comparisonRow(
                            'Efektif / jam',
                            ranked,
                            (o) => rupiah(o.effectiveHourlyIncome),
                          ),
                          _comparisonRow(
                            'Skor',
                            ranked,
                            (o) => o.worthScore == null
                                ? '-'
                                : '${o.worthScore}/100',
                          ),
                          _comparisonRow(
                            'Status',
                            ranked,
                            (o) => o.worthVerdict.label,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (best != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: softGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: darkGreen,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Skor tertinggi: ${best.title} '
                            '(${best.worthScore}/100)',
                            style: const TextStyle(
                              color: darkGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                const Text(
                  'Hasil merupakan simulasi berdasarkan '
                  'data dan preferensimu.',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final offerState = ref.watch(jobOffersProvider);
    if (offerState.isLoading && !offerState.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final offers = _visibleOffers();
    final selectedCount = _selectedOffers.length;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            await ref.read(jobOffersProvider.notifier).refresh();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(17, 17, 17, 0),
                  child: Column(
                    children: [
                      _buildHeader(),

                      if (ref.read(jobOffersProvider).isSaving)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(),
                        ),

                      if (ref.read(jobOffersProvider).hasError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ref.read(jobOffersProvider).errorMessage ??
                                      'Terjadi kesalahan.',
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  ref
                                      .read(jobOffersProvider.notifier)
                                      .refresh();
                                },
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (offers.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return _buildOfferCard(offers[index]);
                    }, childCount: offers.length),
                  ),
                ),

              SliverToBoxAdapter(
                child: SizedBox(height: selectedCount >= 2 ? 105 : 24),
              ),
            ],
          ),
        ),

        if (!_showArchived && selectedCount >= 2)
          Positioned(
            left: 17,
            right: 17,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: darkGreen,
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                onPressed: _showComparison,
                icon: const Icon(Icons.compare_arrows_rounded),
                label: Text('Bandingkan $selectedCount Tawaran'),
              ),
            ),
          ),
      ],
    );
  }
}
