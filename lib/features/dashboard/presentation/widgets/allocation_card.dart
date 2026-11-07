import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../models/finance_plan.dart';
import '../../providers/dashboard_provider.dart';

// =====================================================
// FINPLAN COLORS
// =====================================================

const _darkGreen = Color(0xFF064E3B);
const _green = Color(0xFF059669);
const _muted = Color(0xFF84958C);
const _softGreen = Color(0xFFE9F8F0);

// =====================================================
// ALLOCATION CARD
// =====================================================

class AllocationCard extends ConsumerWidget {
  const AllocationCard({
    super.key,
    required this.plan,
  });

  final FinancePlan plan;

  // ===================================================
  // SHOW ALL CATEGORIES
  // ===================================================

  Future<void> _showAll(
    BuildContext context,
    WidgetRef ref,
    DashboardAllocation allocation,
  ) async {
    if (allocation.slices.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.76,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              19,
              7,
              19,
              20,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // =====================================
                // HEADER
                // =====================================

                const Row(
                  children: [
                    Icon(
                      Icons.donut_large_rounded,
                      color: _green,
                      size: 23,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Rincian Pembagian',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  'Total ${rupiah(allocation.chartTotal)}',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 17),

                // =====================================
                // CATEGORY LIST
                // =====================================

                Expanded(
                  child: ListView.separated(
                    itemCount: allocation.slices.length,
                    separatorBuilder: (_, _) {
                      return const SizedBox(height: 4);
                    },
                    itemBuilder: (_, index) {
                      final slice =
                          allocation.slices[index];

                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),

                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: slice.color.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius:
                                BorderRadius.circular(13),
                          ),
                          child: Icon(
                            slice.icon,
                            color: slice.color,
                            size: 20,
                          ),
                        ),

                        title: Text(
                          slice.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        subtitle: Text(
                          rupiah(slice.amount),
                          style: const TextStyle(
                            fontSize: 11,
                          ),
                        ),

                        trailing: Text(
                          allocation.percentage(
                            slice.amount,
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        onTap: () {
                          Navigator.pop(sheetContext);

                          if (context.mounted) {
                            ref
                                .read(
                                  dashboardSelectedCategoryProvider
                                      .notifier,
                                )
                                .toggle(index);
                          }
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 9),

                // =====================================
                // CLOSE BUTTON
                // =====================================

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkGreen,
                      minimumSize:
                          const Size.fromHeight(50),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Selesai'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===================================================
  // CATEGORY ROW
  // ===================================================

  Widget _categoryRow(
    BuildContext context,
    WidgetRef ref,
    AllocationSlice slice,
    int index,
    DashboardAllocation allocation,
    int? selectedIndex,
  ) {
    final scheme =
        Theme.of(context).colorScheme;

    final selected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(13),

        child: InkWell(
          onTap: () {
            ref
                .read(
                  dashboardSelectedCategoryProvider
                      .notifier,
                )
                .toggle(index);
          },

          borderRadius: BorderRadius.circular(13),

          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 9,
            ),

            child: Row(
              children: [
                // CATEGORY ICON
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: slice.color.withValues(
                      alpha: 0.14,
                    ),
                    borderRadius:
                        BorderRadius.circular(11),
                  ),
                  child: Icon(
                    slice.icon,
                    color: slice.color,
                    size: 18,
                  ),
                ),

                const SizedBox(width: 10),

                // CATEGORY INFORMATION
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        slice.name,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        rupiah(slice.amount),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // CATEGORY PERCENTAGE
                Text(
                  allocation.percentage(
                    slice.amount,
                  ),
                  style: TextStyle(
                    color: selected
                        ? scheme.primary
                        : scheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================================================
  // DONUT CHART
  // ===================================================

  Widget _donut(
    BuildContext context,
    WidgetRef ref,
    DashboardAllocation allocation,
    int? selectedIndex,
    double size,
  ) {
    final slices = allocation.slices;

    final selected =
        selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < slices.length
        ? slices[selectedIndex]
        : null;

    final total = allocation.chartTotal;

    final percent = total <= 0
        ? 0
        : (plan.idealIncome / total * 100)
            .clamp(0, 100)
            .round();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTap: () {
        _showAll(
          context,
          ref,
          allocation,
        );
      },

      child: SizedBox(
        width: size,
        height: size,

        child: Stack(
          alignment: Alignment.center,
          children: [
            // =========================================
            // CUSTOM PAINTER
            // =========================================

            CustomPaint(
              size: Size(size, size),
              painter: AllocationDonutPainter(
                slices: slices,
                total: total,
                selectedIndex: selectedIndex,
              ),
            ),

            // =========================================
            // CENTER INFORMATION
            // =========================================

            SizedBox(
              width: size * 0.55,
              child: AnimatedSwitcher(
                duration:
                    const Duration(milliseconds: 220),

                child: Column(
                  key: ValueKey(selectedIndex),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected == null
                          ? '$percent%'
                          : allocation.percentage(
                              selected.amount,
                            ),

                      maxLines: 1,
                      textAlign: TextAlign.center,

                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface,
                        fontSize: size * 0.17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      selected?.name ?? 'Teralokasi',
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================
  // BUILD ALLOCATION CARD
  // ===================================================

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final scheme =
        Theme.of(context).colorScheme;

    // =================================================
    // RIVERPOD STATE
    // =================================================

    final allocation =
        ref.watch(dashboardAllocationProvider) ??
        calculateDashboardAllocation(plan);

    final selectedIndex =
        ref.watch(dashboardSelectedCategoryProvider);

    final slices = allocation.slices;

    final total = allocation.chartTotal;

    final selected =
        selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < slices.length
        ? slices[selectedIndex]
        : null;

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),

        border: Border.all(
          color: scheme.brightness ==
                  Brightness.dark
              ? Colors.white12
              : const Color(0xFFE5EFE8),
        ),

        boxShadow: const [
          BoxShadow(
            color: Color(0x0C064E3B),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // ===========================================
          // CARD HEADER
          // ===========================================

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pembagian Gaji',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Alokasi bulananmu',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: _softGreen,
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: _darkGreen,
                  size: 20,
                ),
              ),
            ],
          ),

          // ===========================================
          // ALLOCATION CONTENT
          // ===========================================

          if (total > 0) ...[
            const SizedBox(height: 17),

            LayoutBuilder(
              builder: (context, constraints) {
                final chartSize =
                    constraints.maxWidth < 290
                    ? 120.0
                    : 137.0;

                return Row(
                  children: [
                    // DONUT CHART
                    _donut(
                      context,
                      ref,
                      allocation,
                      selectedIndex,
                      chartSize,
                    ),

                    const SizedBox(width: 14),

                    // ALLOCATION SUMMARY
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Text(
                            selected?.name ??
                                'Total direncanakan',

                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,

                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                            ),
                          ),

                          const SizedBox(height: 8),

                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment:
                                Alignment.centerLeft,

                            child: Text(
                              rupiah(
                                selected?.amount ??
                                    plan.idealIncome,
                              ),

                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 21,
                                fontWeight:
                                    FontWeight.w900,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            selected == null
                                ? plan.plannedDifference >= 0
                                    ? 'Sisa ${rupiah(plan.plannedDifference)}'
                                    : 'Kurang ${rupiah(-plan.plannedDifference)}'
                                : allocation.percentage(
                                    selected.amount,
                                  ),

                            maxLines: 2,

                            style: const TextStyle(
                              color: _green,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // =========================================
            // TOP CATEGORIES
            // =========================================

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kategori terbesar',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),

                Text(
                  '${slices.length} kategori',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 11),

            // TOP 3 CATEGORIES
            for (final index in allocation.topIndices)
              _categoryRow(
                context,
                ref,
                slices[index],
                index,
                allocation,
                selectedIndex,
              ),

            const SizedBox(height: 4),

            // =========================================
            // VIEW ALL BUTTON
            // =========================================

            SizedBox(
              width: double.infinity,

              child: OutlinedButton.icon(
                onPressed: () {
                  _showAll(
                    context,
                    ref,
                    allocation,
                  );
                },

                style: OutlinedButton.styleFrom(
                  foregroundColor: _darkGreen,
                  side: const BorderSide(
                    color: Color(0xFFBBDCC9),
                  ),
                  minimumSize:
                      const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),

                icon: const Icon(
                  Icons.grid_view_rounded,
                  size: 17,
                ),

                label: const Text(
                  'Lihat Semua Kategori',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ] else ...[
            // =========================================
            // EMPTY STATE
            // =========================================

            const SizedBox(height: 15),

            const Center(
              child: Text(
                'Belum ada alokasi keuangan',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 15),
          ],
        ],
      ),
    );
  }
}

// =====================================================
// CUSTOM DONUT PAINTER
// =====================================================

class AllocationDonutPainter extends CustomPainter {
  const AllocationDonutPainter({
    required this.slices,
    required this.total,
    required this.selectedIndex,
  });

  final List<AllocationSlice> slices;
  final int total;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    // =================================================
    // CHART DIMENSIONS
    // =================================================

    final rect = Rect.fromCircle(
      center: Offset(
        size.width / 2,
        size.height / 2,
      ),
      radius: size.shortestSide * 0.36,
    );

    // =================================================
    // BACKGROUND TRACK
    // =================================================

    final trackPaint = Paint()
      ..color = const Color(0xFFE8F0EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17;

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      trackPaint,
    );

    if (total <= 0 || slices.isEmpty) return;

    // =================================================
    // DRAW ALLOCATION SLICES
    // =================================================

    double startAngle = -math.pi / 2;

    for (
      var index = 0;
      index < slices.length;
      index++
    ) {
      final slice = slices[index];

      final sweep =
          slice.amount / total * math.pi * 2;

      final gap = math.min(
        0.025,
        sweep * 0.14,
      );

      final visibleSweep = sweep - gap;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            selectedIndex == index ? 22 : 17
        ..strokeCap = StrokeCap.butt;

      if (visibleSweep > 0) {
        canvas.drawArc(
          rect,
          startAngle + gap / 2,
          visibleSweep,
          false,
          paint,
        );
      }

      startAngle += sweep;
    }
  }

  // ===================================================
  // REPAINT CONDITIONS
  // ===================================================

  @override
  bool shouldRepaint(
    covariant AllocationDonutPainter oldDelegate,
  ) {
    return oldDelegate.slices != slices ||
        oldDelegate.total != total ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}