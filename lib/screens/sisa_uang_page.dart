import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';

// =====================================================
// WARNA FINPLAN
// =====================================================

const Color _darkGreen = Color(0xFF064E3B);
const Color _green = Color(0xFF059669);
const Color _mint = Color(0xFFD1FAE5);
const Color _orange = Color(0xFFF59E0B);
const Color _blue = Color(0xFF38BDF8);

// =====================================================
// SIMULASI SISA UANG
// =====================================================

class SisaUangPage extends StatefulWidget {
  const SisaUangPage({super.key});

  @override
  State<SisaUangPage> createState() {
    return _SisaUangPageState();
  }
}

class _SisaUangPageState extends State<SisaUangPage> {
  final _saldo = TextEditingController();
  final _tagihan = TextEditingController(text: '0');
  final _makan = TextEditingController(text: '25000');
  final _transport = TextEditingController(text: '15000');

  late DateTime _hariIni;
  late DateTime _gajian;

  double _cadanganPersen = 10;

  // Default: bepergian Senin-Jumat.
  final Set<int> _hariPergi = {
    1, 2, 3, 4, 5,
  };

  final Set<int> _hariMakanGratis = {};

  static const _namaHari = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  static const _bulan = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _hariIni = DateTime(
      now.year,
      now.month,
      now.day,
    );

    _gajian = _hariIni.add(
      const Duration(days: 14),
    );
  }

  @override
  void dispose() {
    _saldo.dispose();
    _tagihan.dispose();
    _makan.dispose();
    _transport.dispose();

    super.dispose();
  }

  // ===================================================
  // HELPER
  // ===================================================

  int _nilai(TextEditingController controller) {
    return parseRupiah(controller.text);
  }

  int get _jumlahHari {
    final from = DateTime.utc(
      _hariIni.year,
      _hariIni.month,
      _hariIni.day,
    );

    final to = DateTime.utc(
      _gajian.year,
      _gajian.month,
      _gajian.day,
    );

    return to.difference(from).inDays;
  }

  int _hitungHari(
    Set<int> weekdays,
    int totalHari,
  ) {
    var result = 0;

    for (var i = 0; i < totalHari; i++) {
      final day = DateTime.utc(
        _hariIni.year,
        _hariIni.month,
        _hariIni.day + i,
      ).weekday;

      if (weekdays.contains(day)) {
        result++;
      }
    }

    return result;
  }

  String _tanggal(DateTime date) {
    return '${date.day} '
        '${_bulan[date.month - 1]} '
        '${date.year}';
  }

  // ===================================================
  // DATE PICKER
  // ===================================================

  Future<void> _pilihTanggal(bool pilihGajian) async {
    final result = await showDatePicker(
      context: context,
      initialDate: pilihGajian ? _gajian : _hariIni,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: pilihGajian
          ? 'PILIH TANGGAL GAJIAN'
          : 'PILIH TANGGAL AWAL',
    );

    if (result == null || !mounted) return;

    setState(() {
      if (pilihGajian) {
        _gajian = result;
      } else {
        _hariIni = result;
      }
    });
  }

  // ===================================================
  // LOGIKA SIMULASI
  // ===================================================

  _Simulasi _hitung() {
    final days = _jumlahHari;

    final balance = _nilai(_saldo);
    final bills = _nilai(_tagihan);

    if (days <= 0 || days > 366) {
      return _Simulasi.invalid(days: days);
    }

    // Saldo setelah tagihan.
    final afterBills = (balance - bills)
        .clamp(0, balance)
        .toInt();

    // Tagihan yang belum tertutup.
    final unpaidBills = (bills - balance)
        .clamp(0, bills)
        .toInt();

    // Dana cadangan.
    final reserve = (
      afterBills * _cadanganPersen / 100
    ).round();

    final available = afterBills - reserve;

    // Jumlah hari bepergian.
    final tripDays = _hitungHari(
      _hariPergi,
      days,
    );

    // Jumlah hari makan gratis.
    final freeFoodDays = _hitungHari(
      _hariMakanGratis,
      days,
    );

    final eatingDays = days - freeFoodDays;

    // Estimasi kebutuhan.
    final tripNeed =
        tripDays * _nilai(_transport);

    final foodNeed =
        eatingDays * _nilai(_makan);

    // Prioritas: transportasi, lalu makan.
    final tripBudget = tripNeed
        .clamp(0, available)
        .toInt();

    final foodBudget = foodNeed
        .clamp(0, available - tripBudget)
        .toInt();

    final otherBudget =
        available - tripBudget - foodBudget;

    final shortage =
        unpaidBills +
        (tripNeed - tripBudget) +
        (foodNeed - foodBudget);

    return _Simulasi(
      valid: true,
      days: days,
      available: available,
      reserve: reserve,
      tripDays: tripDays,
      eatingDays: eatingDays,
      tripNeed: tripNeed,
      foodNeed: foodNeed,
      tripBudget: tripBudget,
      foodBudget: foodBudget,
      otherBudget: otherBudget,
      shortage: shortage,
    );
  }

  // ===================================================
  // KOMPONEN UI
  // ===================================================

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
            color: theme.colorScheme.primary,
          ),

          const SizedBox(width: 9),

          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(
            alpha: 0.55,
          ),
        ),
      ),
      child: child,
    );
  }

  // ===================================================
  // INPUT NOMINAL
  // ===================================================

  Widget _moneyInput(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (_) {
        setState(() {});
      },
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        prefixIcon: Icon(icon),
      ),
    );
  }

  // ===================================================
  // TOMBOL TANGGAL
  // ===================================================

  Widget _dateButton(
    String label,
    DateTime date,
    bool salaryDate,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Expanded(
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => _pilihTanggal(salaryDate),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: scheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(
              children: [
                Icon(
                  salaryDate
                      ? Icons.event_available_outlined
                      : Icons.today_outlined,
                  color: scheme.primary,
                  size: 24,
                ),

                const SizedBox(height: 8),

                Text(
                  label,
                  style: theme.textTheme.labelSmall,
                ),

                const SizedBox(height: 5),

                Text(
                  _tanggal(date),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(
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
  // PILIHAN HARI
  // ===================================================

  Widget _dayChips(Set<int> selectedDays) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: List.generate(7, (index) {
        final day = index + 1;

        return FilterChip(
          label: Text(_namaHari[index]),
          selected: selectedDays.contains(day),
          showCheckmark: false,
          selectedColor: _mint,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                selectedDays.add(day);
              } else {
                selectedDays.remove(day);
              }
            });
          },
        );
      }),
    );
  }

  // ===================================================
  // INFO CARD
  // ===================================================

  Widget _miniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: scheme.outlineVariant.withValues(
              alpha: 0.5,
            ),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),

            const SizedBox(height: 10),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),

            const SizedBox(height: 5),

            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================
  // PROGRESS ALOKASI
  // ===================================================

  Widget _allocationBar({
    required String label,
    required String subtitle,
    required int amount,
    required int total,
    required IconData icon,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final ratio = total <= 0
        ? 0.0
        : (amount / total).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      style:
                          Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Text(
                rupiah(amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 11),

          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: ratio,
            ),
            duration: const Duration(
              milliseconds: 350,
            ),
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 8,
                borderRadius: BorderRadius.circular(12),
                color: color,
                backgroundColor:
                    scheme.surfaceContainerHighest,
              );
            },
          ),
        ],
      ),
    );
  }

  // ===================================================
  // NOTIFIKASI HASIL
  // ===================================================

  Widget _notice(
    IconData icon,
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 23,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // HASIL SIMULASI
  // ===================================================

  Widget _result() {
    final scheme = Theme.of(context).colorScheme;

    if (_saldo.text.trim().isEmpty) {
      return _notice(
        Icons.touch_app_outlined,
        'Masukkan sisa uang untuk melihat hasil.',
        scheme.primary,
      );
    }

    final result = _hitung();

    if (!result.valid) {
      return _notice(
        Icons.event_busy_outlined,
        'Tanggal gajian harus setelah tanggal awal '
        'dan maksimal 366 hari.',
        scheme.error,
      );
    }

    final safeFoodDaily = result.eatingDays == 0
        ? 0
        : (result.available - result.tripNeed)
                .clamp(0, result.available)
                .toInt() ~/
            result.eatingDays;

    final dailyLimit =
        result.available ~/ result.days;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // =============================================
        // KARTU UTAMA HASIL
        // =============================================

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                _darkGreen,
                _green,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.14,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white54,
                    width: 2.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Text(
                      '${result.days}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const Text(
                      'HARI',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Batas Harian',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 5),

                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        rupiah(dailyLimit),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      'Gajian ${_tanggal(_gajian)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 13),

        // =============================================
        // RINGKASAN
        // =============================================

        Row(
          children: [
            _miniStat(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Siap Dipakai',
              value: rupiah(result.available),
              color: _green,
            ),

            const SizedBox(width: 8),

            _miniStat(
              icon: Icons.shield_outlined,
              label: 'Cadangan',
              value: rupiah(result.reserve),
              color: _blue,
            ),

            const SizedBox(width: 8),

            _miniStat(
              icon: Icons.shopping_bag_outlined,
              label: 'Lainnya',
              value: rupiah(result.otherBudget),
              color: _orange,
            ),
          ],
        ),

        const SizedBox(height: 17),

        // =============================================
        // STATUS CUKUP ATAU KURANG
        // =============================================

        if (result.shortage > 0) ...[
          _notice(
            Icons.warning_amber_rounded,
            'Anggaran kurang '
            '${rupiah(result.shortage)} untuk '
            'memenuhi semua kebutuhan.',
            scheme.error,
          ),

          const SizedBox(height: 14),
        ],

        // =============================================
        // PEMBAGIAN ANGGARAN
        // =============================================

        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pembagian Uang',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),

              const SizedBox(height: 8),

              _allocationBar(
                label: 'Makan',
                subtitle:
                    '${result.eatingDays} hari × '
                    '${rupiah(_nilai(_makan))}',
                amount: result.foodBudget,
                total: result.available,
                icon: Icons.restaurant_rounded,
                color: _green,
              ),

              _allocationBar(
                label: 'Transportasi',
                subtitle:
                    '${result.tripDays} hari × '
                    '${rupiah(_nilai(_transport))}',
                amount: result.tripBudget,
                total: result.available,
                icon: Icons.train_rounded,
                color: _blue,
              ),

              _allocationBar(
                label: 'Lainnya',
                subtitle: 'Anggaran fleksibel',
                amount: result.otherBudget,
                total: result.available,
                icon: Icons.shopping_bag_rounded,
                color: _orange,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // =============================================
        // REKOMENDASI
        // =============================================

        _notice(
          result.shortage == 0
              ? Icons.check_circle_outline_rounded
              : Icons.tips_and_updates_outlined,
          result.shortage == 0
              ? 'Anggaran cukup berdasarkan '
                  'biaya yang kamu masukkan.'
              : result.tripNeed > result.tripBudget
                  ? 'Biaya transportasi perlu '
                      'dikurangi agar saldo mencukupi.'
                  : 'Batas makan agar lebih aman: '
                      '${rupiah(safeFoodDaily)} per hari.',
          result.shortage == 0
              ? scheme.primary
              : scheme.error,
        ),
      ],
    );
  }

  // ===================================================
  // TAMPILAN HALAMAN
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Simulasi Sisa Uang',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 700,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                18,
                12,
                18,
                32,
              ),
              children: [
                // =====================================
                // HEADER
                // =====================================

                Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(21),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius:
                              BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.auto_graph_rounded,
                          color: scheme.onPrimary,
                          size: 26,
                        ),
                      ),

                      const SizedBox(width: 13),

                      Expanded(
                        child: Text(
                          'Atur uang sampai gajian 💚',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 23),

                // =====================================
                // SALDO DAN TANGGAL
                // =====================================

                _sectionTitle(
                  'Saldo & Tanggal',
                  Icons.wallet_outlined,
                ),

                _card(
                  Column(
                    children: [
                      _moneyInput(
                        _saldo,
                        'Sisa Uang',
                        Icons.account_balance_wallet_outlined,
                      ),

                      const SizedBox(height: 13),

                      _moneyInput(
                        _tagihan,
                        'Tagihan Wajib',
                        Icons.receipt_long_outlined,
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          _dateButton(
                            'Tanggal Awal',
                            _hariIni,
                            false,
                          ),

                          const SizedBox(width: 11),

                          _dateButton(
                            'Tanggal Gajian',
                            _gajian,
                            true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // =====================================
                // BIAYA HARIAN
                // =====================================

                _sectionTitle(
                  'Kebutuhan Harian',
                  Icons.tune_rounded,
                ),

                _card(
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _moneyInput(
                        _makan,
                        'Biaya Makan / Hari',
                        Icons.restaurant_outlined,
                      ),

                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          15000,
                          25000,
                          35000,
                        ].map((value) {
                          return ChoiceChip(
                            label: Text(
                              '${value ~/ 1000}rb',
                            ),
                            selected: _nilai(_makan) == value,
                            showCheckmark: false,
                            selectedColor: _mint,
                            onSelected: (_) {
                              setState(() {
                                _makan.text = value.toString();
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      _moneyInput(
                        _transport,
                        'Transport / Hari Bepergian',
                        Icons.directions_transit_outlined,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // =====================================
                // PILIHAN HARI
                // =====================================

                _card(
                  Column(
                    children: [
                      ExpansionTile(
                        leading: const Icon(
                          Icons.calendar_view_week_outlined,
                        ),
                        title: const Text(
                          'Hari Bepergian',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'Hari yang membutuhkan ongkos',
                        ),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(
                          6,
                          0,
                          6,
                          12,
                        ),
                        children: [
                          _dayChips(_hariPergi),
                        ],
                      ),

                      const Divider(height: 1),

                      ExpansionTile(
                        leading: const Icon(
                          Icons.no_food_outlined,
                        ),
                        title: const Text(
                          'Hari Makan Gratis',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'Hari tanpa biaya makan',
                        ),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(
                          6,
                          0,
                          6,
                          12,
                        ),
                        children: [
                          _dayChips(_hariMakanGratis),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // =====================================
                // DANA CADANGAN
                // =====================================

                _sectionTitle(
                  'Dana Cadangan',
                  Icons.shield_outlined,
                ),

                _card(
                  Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Persentase Cadangan',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_cadanganPersen.round()}%',
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Slider(
                        value: _cadanganPersen,
                        min: 0,
                        max: 30,
                        divisions: 6,
                        label:
                            '${_cadanganPersen.round()}%',
                        onChanged: (value) {
                          setState(() {
                            _cadanganPersen = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // =====================================
                // HASIL SIMULASI
                // =====================================

                _sectionTitle(
                  'Hasil Simulasi',
                  Icons.pie_chart_outline_rounded,
                ),

                _result(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// MODEL HASIL SIMULASI
// =====================================================

class _Simulasi {
  const _Simulasi({
    required this.valid,
    required this.days,
    required this.available,
    required this.reserve,
    required this.tripDays,
    required this.eatingDays,
    required this.tripNeed,
    required this.foodNeed,
    required this.tripBudget,
    required this.foodBudget,
    required this.otherBudget,
    required this.shortage,
  });

  factory _Simulasi.invalid({
    required int days,
  }) {
    return _Simulasi(
      valid: false,
      days: days,
      available: 0,
      reserve: 0,
      tripDays: 0,
      eatingDays: 0,
      tripNeed: 0,
      foodNeed: 0,
      tripBudget: 0,
      foodBudget: 0,
      otherBudget: 0,
      shortage: 0,
    );
  }

  final bool valid;
  final int days;
  final int available;
  final int reserve;
  final int tripDays;
  final int eatingDays;
  final int tripNeed;
  final int foodNeed;
  final int tripBudget;
  final int foodBudget;
  final int otherBudget;
  final int shortage;
}