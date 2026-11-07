import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/plan_editor_provider.dart';
import 'plan_editor_fields.dart';

// =====================================================
// TRANSPORT STEP
// =====================================================

class TransportStep extends ConsumerWidget {
  const TransportStep({
    super.key,
  });

  static const _shortDays = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    // =================================================
    // RIVERPOD STATE
    // =================================================

    final day = ref.watch(
      planEditorProvider.select(
        (draft) => draft.selectedDay,
      ),
    );

    final dailyTotal = ref.watch(
      planEditorProvider.select(
        (draft) => draft.dailyTransportTotal(day),
      ),
    );

    final monthlyTotal = ref.watch(
      planEditorProvider.select(
        (draft) => draft.toFinancePlan().transport,
      ),
    );

    final notifier = ref.read(
      planEditorProvider.notifier,
    );

    final scheme = Theme.of(context).colorScheme;

    // =================================================
    // UI
    // =================================================

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // =============================================
        // PILIH HARI
        // =============================================

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 1; index <= 7; index++)
                Padding(
                  padding: const EdgeInsets.only(
                    right: 7,
                  ),
                  child: ChoiceChip(
                    label: Text(
                      _shortDays[index - 1],
                    ),
                    selected: day == index,
                    showCheckmark: false,
                    selectedColor:
                        scheme.primaryContainer,
                    onSelected: (_) {
                      notifier.selectDay(index);
                    },
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 17),

        // =============================================
        // PERJALANAN PERGI
        // =============================================

        TransportDirectionSection(
          day: day,
          direction: TravelDirection.outbound,
        ),

        const SizedBox(height: 14),

        // =============================================
        // PERJALANAN PULANG
        // =============================================

        TransportDirectionSection(
          day: day,
          direction: TravelDirection.inbound,
        ),

        const SizedBox(height: 17),

        // =============================================
        // RINGKASAN BIAYA
        // =============================================

        Row(
          children: [
            PlanEditorMetricCard(
              label: 'Hari Ini',
              amount: dailyTotal,
              icon: Icons.directions_transit_rounded,
              color: Colors.blue.shade600,
            ),

            const SizedBox(width: 10),

            PlanEditorMetricCard(
              label: 'Per Bulan',
              amount: monthlyTotal,
              icon: Icons.calendar_month_outlined,
              color: Colors.purple.shade500,
            ),
          ],
        ),
      ],
    );
  }
}

// =====================================================
// TRANSPORT DIRECTION SECTION
// =====================================================

/// Komponen ini digunakan untuk perjalanan
/// pergi dan perjalanan pulang.
///
/// Hanya daftar segmen sesuai arah perjalanan
/// yang dipantau menggunakan Riverpod select().
class TransportDirectionSection extends ConsumerWidget {
  const TransportDirectionSection({
    super.key,
    required this.day,
    required this.direction,
  });

  final int day;
  final TravelDirection direction;

  // ===================================================
  // PILIHAN TRANSPORTASI
  // ===================================================

  static const _transportModes = [
    'KRL',
    'Bus / Transum',
    'MRT',
    'LRT',
    'Gojek / Grab',
    'Angkot',
    'Kendaraan pribadi',
    'Jalan kaki',
    'Lainnya',
  ];

  // ===================================================
  // BUILD
  // ===================================================

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    // ================================================
    // RIVERPOD STATE
    // ================================================

    final legs = ref.watch(
      planEditorProvider.select((draft) {
        final route = draft.routeFor(day);

        return direction == TravelDirection.outbound
            ? route.outbound
            : route.inbound;
      }),
    );

    final notifier = ref.read(
      planEditorProvider.notifier,
    );

    final scheme = Theme.of(context).colorScheme;

    final isOutbound =
        direction == TravelDirection.outbound;

    // ================================================
    // UI
    // ================================================

    return PlanEditorSectionCard(
      title: isOutbound
          ? 'Perjalanan Pergi'
          : 'Perjalanan Pulang',
      icon: isOutbound
          ? Icons.arrow_forward_rounded
          : Icons.arrow_back_rounded,
      children: [
        // ============================================
        // DAFTAR SEGMEN TRANSPORTASI
        // ============================================

        for (final leg in legs)
          Container(
            key: ValueKey('leg_${leg.id}'),
            margin: const EdgeInsets.only(
              bottom: 13,
            ),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // ====================================
                // PILIH MODA TRANSPORTASI
                // ====================================

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                          'transport_mode_${leg.id}_'
                          '${_isCustom(leg.mode) ? 'Lainnya' : leg.mode}',
                        ),
                        initialValue:
                            _isCustom(leg.mode)
                                ? 'Lainnya'
                                : leg.mode,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Transportasi',
                        ),
                        items: [
                          for (final mode in _transportModes)
                            DropdownMenuItem<String>(
                              value: mode,
                              child: Text(mode),
                            ),
                        ],
                        onChanged: (mode) {
                          if (mode == null) return;

                          notifier.updateLeg(
                            day,
                            direction,
                            leg.id,
                            mode: mode == 'Lainnya'
                                ? ''
                                : mode,
                          );
                        },
                      ),
                    ),

                    IconButton(
                      tooltip: 'Hapus moda',
                      onPressed: () {
                        notifier.removeLeg(
                          day,
                          direction,
                          leg.id,
                        );
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                      ),
                    ),
                  ],
                ),

                // ====================================
                // TRANSPORTASI CUSTOM
                // ====================================

                if (_isCustom(leg.mode)) ...[
                  const SizedBox(height: 11),

                  TextFormField(
                    key: ValueKey(
                      'custom_mode_${leg.id}',
                    ),
                    initialValue:
                        leg.mode == 'Lainnya'
                            ? ''
                            : leg.mode,
                    decoration: const InputDecoration(
                      labelText: 'Nama Transportasi',
                      hintText: 'Shuttle / Bus Kantor',
                    ),
                    onChanged: (mode) {
                      notifier.updateLeg(
                        day,
                        direction,
                        leg.id,
                        mode: mode,
                      );
                    },
                  ),
                ],

                const SizedBox(height: 11),

                // ====================================
                // BIAYA PERJALANAN
                // ====================================

                PlanEditorMoneyField(
                  key: ValueKey(
                    'leg_cost_${leg.id}',
                  ),
                  label: 'Biaya Perjalanan',
                  value: leg.cost,
                  onChanged: (cost) {
                    notifier.updateLeg(
                      day,
                      direction,
                      leg.id,
                      cost: cost,
                    );
                  },
                ),

                const SizedBox(height: 10),

                // ====================================
                // CATATAN
                // ====================================

                TextFormField(
                  key: ValueKey(
                    'leg_note_${leg.id}',
                  ),
                  initialValue: leg.note,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (Opsional)',
                  ),
                  onChanged: (note) {
                    notifier.updateLeg(
                      day,
                      direction,
                      leg.id,
                      note: note,
                    );
                  },
                ),
              ],
            ),
          ),

        // ============================================
        // TOMBOL TAMBAH MODA
        // ============================================

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              notifier.addLeg(
                day,
                direction,
              );
            },
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: Text(
              'Tambah Moda ${isOutbound ? 'Pergi' : 'Pulang'}',
            ),
          ),
        ),
      ],
    );
  }

  // ===================================================
  // HELPER TRANSPORTASI CUSTOM
  // ===================================================

  bool _isCustom(String mode) {
    return mode == 'Lainnya' ||
        !_transportModes.contains(mode);
  }
}