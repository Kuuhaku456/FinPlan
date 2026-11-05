import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models/finance_plan.dart';

// =====================================================
// MODEL ALOKASI
// =====================================================

class _AllocationSlice {
  const _AllocationSlice({
    required this.name,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String name;
  final int amount;
  final Color color;
  final IconData icon;
}

// =====================================================
// DASHBOARD FINPLAN
// =====================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.plan,
    required this.onOpenPlanner,
  });

  final FinancePlan plan;
  final VoidCallback onOpenPlanner;

  @override
  State<DashboardPage> createState() =>
      _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const Color darkGreen = Color(0xFF064E3B);
  static const Color green = Color(0xFF059669);
  static const Color muted = Color(0xFF84958C);
  static const Color softGreen = Color(0xFFE9F8F0);

  int? _selectedIndex;

  static const List<Color> _colors = [
    Color(0xFF059669),
    Color(0xFF34D399),
    Color(0xFF0D9488),
    Color(0xFF84CC16),
    Color(0xFF0F766E),
    Color(0xFF86BBA8),
    Color(0xFF14B8A6),
    Color(0xFF65A30D),
    Color(0xFF6B9E8D),
  ];

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.plan != widget.plan) {
      _selectedIndex = null;
    }
  }

  // =====================================================
  // DATA DIAGRAM
  // =====================================================

  List<_AllocationSlice> _buildSlices() {
    final plan = widget.plan;
    final slices = <_AllocationSlice>[];

    void add(
      String name,
      int amount,
      IconData icon,
    ) {
      if (amount <= 0) return;

      slices.add(
        _AllocationSlice(
          name: name,
          amount: amount,
          icon: icon,
          color: _colors[slices.length % _colors.length],
        ),
      );
    }

    add(
      'Tempat Tinggal',
      plan.housing,
      Icons.home_outlined,
    );

    add(
      'Makanan',
      plan.food,
      Icons.restaurant_outlined,
    );

    add(
      'Transportasi',
      plan.transport,
      Icons.train_outlined,
    );

    add(
      'Tagihan',
      plan.bills,
      Icons.receipt_long_outlined,
    );

    add(
      'Kebutuhan Pribadi',
      plan.personal,
      Icons.shopping_bag_outlined,
    );

    for (final expense in plan.customExpenses) {
      add(
        expense.name.trim().isEmpty
            ? 'Kebutuhan Lainnya'
            : expense.name,
        expense.monthlyAmount,
        Icons.category_outlined,
      );
    }

    add(
      'Tabungan',
      plan.savings,
      Icons.savings_outlined,
    );

    add(
      'Dana Cadangan',
      plan.buffer,
      Icons.shield_outlined,
    );

    if (plan.plannedDifference > 0) {
      slices.add(
        _AllocationSlice(
          name: 'Belum Dialokasikan',
          amount: plan.plannedDifference,
          color: const Color(0xFFCBD5D1),
          icon: Icons.account_balance_wallet_outlined,
        ),
      );
    }

    return slices;
  }

  int _chartTotal() {
    return math.max(
      widget.plan.totalMonthlyIncome,
      widget.plan.idealIncome,
    );
  }

  String _percentage(int amount, int total) {
    if (total <= 0) return '0%';

    return '${(amount / total * 100).toStringAsFixed(1)}%';
  }

  List<int> _topIndices(List<_AllocationSlice> slices) {
    final indices = List<int>.generate(
      slices.length,
      (index) => index,
    );

    indices.sort(
      (a, b) => slices[b].amount.compareTo(
        slices[a].amount,
      ),
    );

    return indices.take(3).toList();
  }

  void _selectCategory(int index) {
    setState(() {
      _selectedIndex =
          _selectedIndex == index ? null : index;
    });
  }

  // =====================================================
  // RINGKASAN KATEGORI
  // =====================================================

  Widget _categoryRow(
    _AllocationSlice slice,
    int index,
    int total,
  ) {
    final selected = _selectedIndex == index;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: () => _selectCategory(index),
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 9,
            ),
            child: Row(
              children: [
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

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        slice.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rupiah(slice.amount),
                        style: const TextStyle(
                          color: muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Text(
                  _percentage(slice.amount, total),
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

  // =====================================================
  // DIAGRAM DONAT
  // =====================================================

  Widget _donutChart(
    List<_AllocationSlice> slices,
    int total,
    double size,
  ) {
    final selectedIndex = _selectedIndex;

    final selected = selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < slices.length
        ? slices[selectedIndex]
        : null;

    final allocated = widget.plan.idealIncome;

    final percentage = total <= 0
        ? 0
        : (allocated / total * 100)
            .clamp(0, 100)
            .round();

    return GestureDetector(
      onTap: () => _showAllCategories(slices, total),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _AllocationDonutPainter(
                slices: slices,
                total: total,
                selectedIndex: selectedIndex,
              ),
            ),

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
                          ? '$percentage%'
                          : _percentage(
                              selected.amount,
                              total,
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
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: muted,
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

  // =====================================================
  // LIHAT SEMUA KATEGORI
  // =====================================================

  Future<void> _showAllCategories(
    List<_AllocationSlice> slices,
    int total,
  ) async {
    if (slices.isEmpty) return;

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
                Row(
                  children: [
                    const Icon(
                      Icons.donut_large_rounded,
                      color: green,
                      size: 23,
                    ),

                    const SizedBox(width: 10),

                    const Expanded(
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
                  'Total ${rupiah(total)}',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 17),

                Expanded(
                  child: ListView.separated(
                    itemCount: slices.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final slice = slices[index];

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
                          _percentage(slice.amount, total),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);

                          if (mounted) {
                            _selectCategory(index);
                          }
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 9),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: darkGreen,
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

  // =====================================================
  // KARTU PEMBAGIAN GAJI BARU
  // =====================================================

  Widget _allocationCard() {
    final plan = widget.plan;
    final scheme = Theme.of(context).colorScheme;

    final slices = _buildSlices();
    final total = _chartTotal();

    final topIndices = _topIndices(slices);

    final selectedIndex = _selectedIndex;

    final selected = selectedIndex != null &&
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
          color: scheme.brightness == Brightness.dark
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        color: muted,
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
                  color: softGreen,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: darkGreen,
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          if (total > 0) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final chartSize =
                    constraints.maxWidth < 290
                        ? 120.0
                        : 137.0;

                return Row(
                  children: [
                    _donutChart(
                      slices,
                      total,
                      chartSize,
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected?.name ??
                                'Total direncanakan',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: muted,
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
                                fontWeight: FontWeight.w900,
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
                                : _percentage(
                                    selected.amount,
                                    total,
                                  ),
                            maxLines: 2,
                            style: const TextStyle(
                              color: green,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
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
                    color: muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 11),

            for (final index in topIndices)
              _categoryRow(
                slices[index],
                index,
                total,
              ),

            const SizedBox(height: 4),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showAllCategories(slices, total);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: darkGreen,
                  side: const BorderSide(
                    color: Color(0xFFBBDCC9),
                  ),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
            const SizedBox(height: 15),

            const Center(
              child: Text(
                'Belum ada alokasi keuangan',
                style: TextStyle(
                  color: muted,
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

  // =====================================================
  // METRIC CARD
  // =====================================================

  Widget _metric(
    IconData icon,
    String label,
    int amount,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: scheme.brightness == Brightness.dark
              ? Colors.white12
              : const Color(0xFFE5EFE8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: softGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: darkGreen,
              size: 20,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 5),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(amount),
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // MAIN DASHBOARD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final scheme = Theme.of(context).colorScheme;

    final positive = plan.plannedDifference >= 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        32,
      ),
      children: [
        // HEADER
        Row(
          children: [
            Container(
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                color: softGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.waving_hand_rounded,
                color: darkGreen,
                size: 24,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selamat datang 👋',
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plan.name.trim().isEmpty
                        ? 'Keuanganmu'
                        : plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            IconButton.filledTonal(
              tooltip: 'Buka Planner',
              onPressed: widget.onOpenPlanner,
              icon: const Icon(
                Icons.tune_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // KARTU PEMASUKAN
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                darkGreen,
                green,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22064E3B),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pemasukan bulanan',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ],
              ),

              const SizedBox(height: 11),

              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  plan.totalMonthlyIncome > 0
                      ? rupiah(plan.totalMonthlyIncome)
                      : 'Belum ada pemasukan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.13,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      positive
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: const Color(0xFFBBF7D0),
                      size: 21,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            positive
                                ? 'Anggaran aman'
                                : 'Perlu penyesuaian',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${positive ? 'Sisa' : 'Kurang'} '
                            '${rupiah(plan.plannedDifference.abs())}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 17),

        // RINGKASAN KEBUTUHAN & TABUNGAN
        Row(
          children: [
            Expanded(
              child: _metric(
                Icons.shopping_bag_outlined,
                'Kebutuhan',
                plan.expenses,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _metric(
                Icons.savings_outlined,
                'Tabungan',
                plan.savings,
              ),
            ),
          ],
        ),

        const SizedBox(height: 11),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: scheme.brightness == Brightness.dark
                ? scheme.surface
                : softGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: green,
                size: 20,
              ),

              const SizedBox(width: 10),

              const Expanded(
                child: Text(
                  'Dana Cadangan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              Text(
                rupiah(plan.buffer),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 23),

        // PEMBAGIAN GAJI BARU
        _allocationCard(),

        const SizedBox(height: 18),

        // TOMBOL PLANNER
        FilledButton.icon(
          onPressed: widget.onOpenPlanner,
          style: FilledButton.styleFrom(
            backgroundColor: darkGreen,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          icon: const Icon(
            Icons.edit_calendar_outlined,
          ),
          label: const Text(
            'Atur Anggaran',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),

        const SizedBox(height: 13),

        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: muted,
              size: 14,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Berdasarkan rencana, bukan transaksi aktual',
                style: TextStyle(
                  color: muted,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =====================================================
// CUSTOM PAINTER DIAGRAM
// =====================================================

class _AllocationDonutPainter extends CustomPainter {
  _AllocationDonutPainter({
    required this.slices,
    required this.total,
    required this.selectedIndex,
  });

  final List<_AllocationSlice> slices;
  final int total;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius = size.shortestSide * 0.36;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    // Track abu-abu muda
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

    double startAngle = -math.pi / 2;

    for (int index = 0;
        index < slices.length;
        index++) {
      final slice = slices[index];

      final sweep =
          slice.amount / total * math.pi * 2;

      final selected = selectedIndex == index;

      final gap = math.min(
        0.025,
        sweep * 0.14,
      );

      final visibleSweep = sweep - gap;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 22 : 17
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

  @override
  bool shouldRepaint(
    covariant _AllocationDonutPainter oldDelegate,
  ) {
    return oldDelegate.slices != slices ||
        oldDelegate.total != total ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}