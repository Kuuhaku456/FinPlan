import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../state/finance_plan_notifier.dart';
import '../state/salary_calculator_notifier.dart';

// ============================================
// FINPLAN - SALARY CALCULATOR UI
// Riverpod Version
// ============================================

String _groupMoney(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');

  if (digits.isEmpty) return '';

  final output = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      output.write('.');
    }
    output.write(digits[i]);
  }

  return output.toString();
}

// ============================================
// RUPIAH INPUT FORMATTER
// ============================================

class _RupiahFormatter extends TextInputFormatter {
  const _RupiahFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _groupMoney(newValue.text);

    final rawCursor = newValue.selection.baseOffset
        .clamp(0, newValue.text.length)
        .toInt();

    final digitsBeforeCursor = newValue.text
        .substring(0, rawCursor)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    var cursor = 0;
    var digitsFound = 0;

    while (
      cursor < formatted.length &&
      digitsFound < digitsBeforeCursor
    ) {
      if (RegExp(r'[0-9]').hasMatch(formatted[cursor])) {
        digitsFound++;
      }

      cursor++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}

// ============================================
// MAIN SALARY CALCULATOR WIDGET
// ============================================

class SalaryCalculatorSection extends ConsumerStatefulWidget {
  const SalaryCalculatorSection({
    super.key,
    this.initialMonthlySalary = 0,
  });

  final int initialMonthlySalary;

  @override
  ConsumerState<SalaryCalculatorSection> createState() =>
      _SalaryCalculatorSectionState();
}

class _SalaryCalculatorSectionState
    extends ConsumerState<SalaryCalculatorSection> {
  static const _green = Color(0xFF059669);
  static const _darkGreen = Color(0xFF064E3B);

  static const _moneyFields = <String>{
    'rate',
    'allowance',
    'bonus',
    'overtime',
    'otherIncome',
    'deductions',
    'goCost',
    'returnCost',
    'extraMeals',
    'otherWorkCosts',
    'targetRemaining',
    'plannerTransportOutsideWork',
    'manualHousing',
    'manualFood',
    'manualTransportOutsideWork',
    'manualBills',
    'manualPersonal',
    'manualOther',
    'manualSavings',
  };

  static const _stepTitles = [
    'Gaji',
    'Jadwal',
    'Perjalanan',
    'Biaya lain',
    'Kebutuhan',
    'Prioritas',
  ];

  static const _stepIcons = [
    Icons.payments_outlined,
    Icons.calendar_month_outlined,
    Icons.commute_outlined,
    Icons.receipt_long_outlined,
    Icons.shopping_basket_outlined,
    Icons.favorite_outline,
  ];

  late final Map<String, TextEditingController> _controllers;

  String? _selectedTierGuide;
  bool _showScoreDetails = false;

  // ==========================================
  // INITIALIZATION
  // ==========================================

  @override
  void initState() {
    super.initState();

    final notifier =
        ref.read(salaryCalculatorProvider.notifier);

    var draft = ref.read(salaryCalculatorProvider);

    if (
      draft.money('rate') == 0 &&
      widget.initialMonthlySalary > 0
    ) {
      notifier.setValue(
        'rate',
        widget.initialMonthlySalary,
      );

      draft = ref.read(salaryCalculatorProvider);
    }

    _controllers = {
      for (final entry in draft.values.entries)
        entry.key: TextEditingController(
          text: _displayValue(
            entry.key,
            entry.value,
          ),
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // ==========================================
  // INPUT HELPERS
  // ==========================================

  String _displayValue(String key, num value) {
    if (_moneyFields.contains(key)) {
      return _groupMoney(value.round().toString());
    }

    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }

  void _setController(String key, num value) {
    final controller = _controllers[key];

    if (controller == null) return;

    final text = _displayValue(key, value);

    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: text.length,
      ),
    );
  }

  void _syncReturn() {
    final state = ref.read(salaryCalculatorProvider);

    for (final field in const [
      'returnCost',
      'returnMinutes',
      'returnDistance',
    ]) {
      _setController(
        field,
        state.number(field),
      );
    }
  }

  void _reset() {
    ref.read(salaryCalculatorProvider.notifier).reset();

    final state = ref.read(salaryCalculatorProvider);

    for (final entry in state.values.entries) {
      _setController(
        entry.key,
        entry.value,
      );
    }

    setState(() {
      _selectedTierGuide = null;
      _showScoreDetails = false;
    });
  }

  void _changeField(String key, String text) {
    final number = _moneyFields.contains(key)
        ? parseRupiah(text)
        : double.tryParse(
              text.trim().replaceAll(',', '.'),
            ) ??
            0;

    ref.read(salaryCalculatorProvider.notifier).setValue(
          key,
          number,
        );

    if (
      ref.read(salaryCalculatorProvider).sameReturnTrip &&
      (
        key == 'goCost' ||
        key == 'goMinutes' ||
        key == 'goDistance'
      )
    ) {
      _syncReturn();
    }
  }

  // ==========================================
  // REUSABLE INPUT WIDGET
  // ==========================================

  Widget _input(
    String field,
    String label, {
    String? suffix,
    String? hint,
    bool enabled = true,
  }) {
    final money = _moneyFields.contains(field);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        TextField(
          controller: _controllers[field],
          enabled: enabled,
          keyboardType:
              const TextInputType.numberWithOptions(
            decimal: true,
          ),
          inputFormatters: money
              ? [const _RupiahFormatter()]
              : [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9,.]'),
                  ),
                ],
          onChanged: (value) =>
              _changeField(field, value),
          decoration: InputDecoration(
            hintText: hint ?? '0',
            prefixText: money ? 'Rp ' : null,
            suffixText: suffix,
            filled: true,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _twoInputs(
    String first,
    String firstLabel,
    String second,
    String secondLabel, {
    String? firstSuffix,
    String? secondSuffix,
    bool secondEnabled = true,
  }) {
    final children = [
      _input(
        first,
        firstLabel,
        suffix: firstSuffix,
      ),
      _input(
        second,
        secondLabel,
        suffix: secondSuffix,
        enabled: secondEnabled,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 350) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              children[0],
              const SizedBox(height: 14),
              children[1],
            ],
          );
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 12),
            Expanded(child: children[1]),
          ],
        );
      },
    );
  }

  // ==========================================
  // REUSABLE PANEL
  // ==========================================

  Widget _panel(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(
          color: colors.outlineVariant,
        ),
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: _green,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _hint(
    String message, {
    IconData icon = Icons.info_outline,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 1 - SALARY
  // ==========================================

  Widget _paymentStep(
    SalaryCalculatorDraft draft,
  ) {
    final notifier =
        ref.read(salaryCalculatorProvider.notifier);

    final unitLabel = switch (draft.paymentMode) {
      OfferPaymentMode.monthly => null,
      OfferPaymentMode.daily =>
        'Hari dibayar / bulan',
      OfferPaymentMode.hourly =>
        'Jam dibayar / bulan',
      OfferPaymentMode.session =>
        'Sesi dibayar / bulan',
    };

    final rateLabel = switch (draft.paymentMode) {
      OfferPaymentMode.monthly =>
        'Gaji pokok / bulan',
      OfferPaymentMode.daily =>
        'Bayaran / hari',
      OfferPaymentMode.hourly =>
        'Bayaran / jam',
      OfferPaymentMode.session =>
        'Bayaran / sesi',
    };

    return _panel(
      'Penghasilan dari pekerjaan',
      Icons.payments_outlined,
      [
        const Text(
          'Skema pembayaran',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),

        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            for (final mode in OfferPaymentMode.values)
              ChoiceChip(
                label: Text(
                  switch (mode) {
                    OfferPaymentMode.monthly => 'Bulanan',
                    OfferPaymentMode.daily => 'Harian',
                    OfferPaymentMode.hourly => 'Per jam',
                    OfferPaymentMode.session => 'Per sesi',
                  },
                ),
                selected: draft.paymentMode == mode,
                onSelected: (_) =>
                    notifier.setPaymentMode(mode),
              ),
          ],
        ),

        _input('rate', rateLabel),

        if (unitLabel != null)
          _input('units', unitLabel),

        _twoInputs(
          'allowance',
          'Tunjangan / bulan',
          'bonus',
          'Bonus / bulan',
        ),

        _twoInputs(
          'overtime',
          'Lembur / bulan',
          'otherIncome',
          'Pendapatan lain dari pekerjaan',
        ),

        _input(
          'deductions',
          'Potongan gaji / bulan',
        ),

        _hint(
          'Isi 0 jika suatu komponen tidak ada. '
          'Hasil menghitung gaji bersih setelah potongan.',
        ),
      ],
    );
  }

  // ==========================================
  // STEP 2 - WORK SCHEDULE
  // ==========================================

  Widget _scheduleStep() {
    return _panel(
      'Jadwal dan beban kerja',
      Icons.calendar_month_outlined,
      [
        _twoInputs(
          'workDays',
          'Hari kerja / bulan',
          'officeDays',
          'Hari ke kantor / bulan',
          firstSuffix: 'hari',
          secondSuffix: 'hari',
        ),

        _twoInputs(
          'workHours',
          'Jam kerja / hari',
          'daysPerWeek',
          'Hari kerja / minggu',
          firstSuffix: 'jam',
          secondSuffix: 'hari',
        ),

        _hint(
          'Hari ke kantor boleh lebih sedikit daripada hari kerja, '
          'misalnya pada sistem hybrid.',
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3 - COMMUTE
  // ==========================================

  Widget _commuteStep(
    SalaryCalculatorDraft draft,
  ) {
    final notifier =
        ref.read(salaryCalculatorProvider.notifier);

    return _panel(
      'Perjalanan pergi dan pulang',
      Icons.directions_transit_outlined,
      [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Samakan perjalanan pulang',
          ),
          subtitle: const Text(
            'Ongkos, waktu, dan jarak pulang '
            'sama seperti pergi.',
          ),
          value: draft.sameReturnTrip,
          onChanged: (value) {
            notifier.setSameReturnTrip(value);

            if (value) {
              _syncReturn();
            }
          },
        ),

        _twoInputs(
          'goCost',
          'Ongkos berangkat',
          'returnCost',
          'Ongkos pulang',
          secondEnabled: !draft.sameReturnTrip,
        ),

        _twoInputs(
          'goMinutes',
          'Waktu berangkat',
          'returnMinutes',
          'Waktu pulang',
          firstSuffix: 'menit',
          secondSuffix: 'menit',
          secondEnabled: !draft.sameReturnTrip,
        ),

        _twoInputs(
          'goDistance',
          'Jarak berangkat',
          'returnDistance',
          'Jarak pulang',
          firstSuffix: 'km',
          secondSuffix: 'km',
          secondEnabled: !draft.sameReturnTrip,
        ),

        _hint(
          'Semua angka perjalanan adalah satu kali perjalanan, '
          'bukan total sebulan.',
        ),
      ],
    );
  }

  // ==========================================
  // STEP 4 - ADDITIONAL COSTS
  // ==========================================

  Widget _costStep() {
    return _panel(
      'Biaya tambahan untuk bekerja',
      Icons.receipt_long_outlined,
      [
        _input(
          'extraMeals',
          'Tambahan biaya makan setiap hari ke kantor',
        ),

        _input(
          'otherWorkCosts',
          'Biaya pekerjaan lainnya / bulan',
        ),

        _hint(
          'Biaya ini dikurangi dari gaji bersih sebelum '
          'dibandingkan dengan kebutuhan hidup.',
        ),
      ],
    );
  }

  // ==========================================
  // NEEDS HELPERS
  // ==========================================

  Widget _needRow(String name, int amount) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(name),
          ),
          Text(
            rupiah(amount),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 5 - USER NEEDS
  // ==========================================

  Widget _needsStep(
    SalaryCalculatorDraft draft,
    SalaryAnalysis result,
  ) {
    final plan = ref.watch(financePlanProvider);

    final notifier =
        ref.read(salaryCalculatorProvider.notifier);

    final needs = result.needs;

    return _panel(
      'Bandingkan dengan kebutuhanmu',
      Icons.account_balance_wallet_outlined,
      [
        if (plan != null)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Gunakan kebutuhan dari Planner',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Kebutuhan selalu mengikuti perubahan '
              'rencana keuangan.',
            ),
            value: draft.usePlannerNeeds,
            onChanged: notifier.setUsePlannerNeeds,
          ),

        if (plan == null)
          _hint(
            'Data Planner belum tersedia. '
            'Masukkan kebutuhan secara manual.',
            icon: Icons.edit_note,
          ),

        if (draft.usePlannerNeeds && plan != null) ...[
          _needRow(
            'Tempat tinggal',
            needs.housing,
          ),

          _needRow(
            'Makan',
            needs.food,
          ),

          _needRow(
            'Tagihan',
            needs.bills,
          ),

          _needRow(
            'Pribadi',
            needs.personal,
          ),

          _needRow(
            'Kebutuhan tambahan',
            needs.other,
          ),

          _needRow(
            'Tabungan',
            needs.savings,
          ),

          _resultRow(
            'Persentase dana cadangan',
            '${needs.bufferPercent}%',
          ),

          _input(
            'plannerTransportOutsideWork',
            'Transportasi di luar pekerjaan / bulan',
          ),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Sertakan pemasukan lain dari Planner',
            ),
            subtitle: Text(
              'Pemasukan tambahan: '
              '${rupiah(plan.monthlyAdditionalIncome)}',
            ),
            value: draft.includePlannerOtherIncome,
            onChanged:
                notifier.setIncludePlannerOtherIncome,
          ),

          _hint(
            'Transportasi dari rencana kerja lama tidak '
            'dihitung dua kali. Ongkos pekerjaan baru '
            'diambil dari langkah Perjalanan.',
          ),
        ] else ...[
          _twoInputs(
            'manualHousing',
            'Tempat tinggal',
            'manualFood',
            'Makan / bulan',
          ),

          _twoInputs(
            'manualTransportOutsideWork',
            'Transportasi non-kerja',
            'manualBills',
            'Tagihan / bulan',
          ),

          _twoInputs(
            'manualPersonal',
            'Kebutuhan pribadi',
            'manualOther',
            'Kebutuhan lainnya',
          ),

          _input(
            'manualSavings',
            'Target tabungan / bulan',
          ),

          _input(
            'manualBufferPercent',
            'Dana cadangan',
            suffix: '%',
          ),

          _hint(
            'Isi kebutuhan yang sesuai dengan keadaanmu. '
            'Tier baru diberikan jika data anggaran '
            'telah diisi.',
          ),
        ],
      ],
    );
  }

  // ==========================================
  // RATING COMPONENT
  // ==========================================

  Widget _rating(
    String title,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            Text(
              '$value / 5',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),

        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: _green,
          label: '$value / 5',
          onChanged: (value) {
            onChanged(value.round());
          },
        ),
      ],
    );
  }

  // ==========================================
  // STEP 6 - PERSONAL PREFERENCES
  // ==========================================

  Widget _priorityStep(
    SalaryCalculatorDraft draft,
  ) {
    final notifier =
        ref.read(salaryCalculatorProvider.notifier);

    return _panel(
      'Prioritas pribadi',
      Icons.favorite_outline,
      [
        _input(
          'targetRemaining',
          'Target uang bebas per bulan',
        ),

        _input(
          'comfortableCommute',
          'Batas nyaman perjalanan PP',
          suffix: 'menit',
        ),

        _rating(
          'Prospek karier',
          draft.careerRating,
          notifier.setCareerRating,
        ),

        _rating(
          'Kenyamanan lingkungan kerja',
          draft.workEnvironmentRating,
          notifier.setWorkEnvironmentRating,
        ),

        _hint(
          'Rating bersifat subjektif. '
          'Masukkan penilaian berdasarkan informasi '
          'pekerjaan yang benar-benar kamu ketahui.',
        ),
      ],
    );
  }

  // ==========================================
  // STEP CONTENT SELECTOR
  // ==========================================

  Widget _stepContent(
    SalaryCalculatorDraft draft,
    SalaryAnalysis analysis,
  ) {
    return switch (draft.currentStep) {
      0 => _paymentStep(draft),
      1 => _scheduleStep(),
      2 => _commuteStep(draft),
      3 => _costStep(),
      4 => _needsStep(draft, analysis),
      _ => _priorityStep(draft),
    };
  }

  // ==========================================
  // STEP NAVIGATION
  // ==========================================

  Widget _stepNavigation(
    SalaryCalculatorDraft draft,
  ) {
    final notifier =
        ref.read(salaryCalculatorProvider.notifier);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Analisis tawaran kerja',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          'Langkah ${draft.currentStep + 1} dari 6 · '
          '${_stepTitles[draft.currentStep]}',
        ),

        const SizedBox(height: 12),

        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (draft.currentStep + 1) / 6,
            minHeight: 7,
            color: _green,
            backgroundColor:
                _green.withAlpha(24),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 57,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _stepTitles.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 7),
            itemBuilder: (context, index) =>
                ActionChip(
              avatar: Icon(
                _stepIcons[index],
                size: 16,
                color: draft.currentStep == index
                    ? Colors.white
                    : _green,
              ),

              backgroundColor:
                  draft.currentStep == index
                      ? _darkGreen
                      : null,

              label: Text(
                _stepTitles[index],
                style: TextStyle(
                  color: draft.currentStep == index
                      ? Colors.white
                      : null,
                ),
              ),

              onPressed: () =>
                  notifier.setStep(index),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP BUTTONS
  // ==========================================

  Widget _stepButtons(
    SalaryCalculatorDraft draft,
    SalaryAnalysis analysis,
  ) {
    final notifier =
        ref.read(salaryCalculatorProvider.notifier);

    return Row(
      children: [
        if (draft.currentStep > 0) ...[
          OutlinedButton.icon(
            onPressed: () {
              notifier.setStep(
                draft.currentStep - 1,
              );
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Kembali'),
          ),

          const SizedBox(width: 10),
        ],

        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _darkGreen,
              padding:
                  const EdgeInsets.symmetric(
                vertical: 15,
              ),
            ),

            onPressed: () {
              if (draft.currentStep < 5) {
                notifier.setStep(
                  draft.currentStep + 1,
                );
                return;
              }

              if (
                analysis.grossSalary <= 0 ||
                !analysis.budgetReady
              ) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Isi gaji dan kebutuhan bulanan '
                      'terlebih dahulu.',
                    ),
                  ),
                );

                return;
              }

              notifier.setShowResults(true);
            },

            icon: Icon(
              draft.currentStep < 5
                  ? Icons.arrow_forward
                  : Icons.analytics_outlined,
            ),

            label: Text(
              draft.currentStep < 5
                  ? 'Lanjut'
                  : 'Lihat hasil analisis',
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // RESULT ROW
  // ==========================================

  Widget _resultRow(
    String label,
    String value, {
    bool strong = false,
    Color? color,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong
                    ? FontWeight.w700
                    : null,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SCORE PROGRESS BAR
  // ==========================================

  Widget _scoreLine(
    String label,
    int? value,
    int max,
  ) {
    final points = value ?? 0;

    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                '$points / $max',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          LinearProgressIndicator(
            value: (points / max)
                .clamp(0, 1)
                .toDouble(),
            minHeight: 7,
            color: _green,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TIER EXPLANATION
  // ==========================================

  Widget _tierDetails(
    SalaryAnalysis result,
  ) {
    final assigned = result.tier;

    return _panel(
      'Bagaimana tier ditentukan?',
      Icons.insights_outlined,
      [
        _hint(
          'Keuangan maksimal 50 poin; '
          'perjalanan 20; keseimbangan 10; '
          'karier 10; kenyamanan 10.',
        ),

        Wrap(
          spacing: 8,
          children: [
            for (final tier in SalaryTier.values)
              ChoiceChip(
                label: Text(
                  'Tier ${tier.letter}',
                ),

                selected:
                    _selectedTierGuide == tier.letter,

                avatar: assigned == tier
                    ? const Icon(
                        Icons.check_circle,
                        color: _green,
                        size: 18,
                      )
                    : null,

                onSelected: (_) {
                  setState(() {
                    _selectedTierGuide =
                        _selectedTierGuide ==
                                tier.letter
                            ? null
                            : tier.letter;
                  });
                },
              ),
          ],
        ),

        if (_selectedTierGuide != null)
          _hint(
            'Tier $_selectedTierGuide: '
            '${SalaryTier.values.firstWhere(
              (t) =>
                  t.letter == _selectedTierGuide,
            ).label}',
          ),

        TextButton.icon(
          onPressed: () {
            setState(() {
              _showScoreDetails =
                  !_showScoreDetails;
            });
          },
          icon: Icon(
            _showScoreDetails
                ? Icons.expand_less
                : Icons.expand_more,
          ),
          label: Text(
            _showScoreDetails
                ? 'Tutup rincian skor'
                : 'Lihat rincian skor',
          ),
        ),

        if (_showScoreDetails) ...[
          _scoreLine(
            'Keuangan',
            result.financialScore,
            50,
          ),

          _scoreLine(
            'Perjalanan',
            result.travelScore,
            20,
          ),

          _scoreLine(
            'Waktu kerja',
            result.balanceScore,
            10,
          ),

          _scoreLine(
            'Prospek karier',
            result.careerScore,
            10,
          ),

          _scoreLine(
            'Kenyamanan',
            result.environmentScore,
            10,
          ),
        ],

        _hint(
          'Tier dibatasi jika biaya pekerjaan tidak '
          'tertutup, kebutuhan hidup belum terpenuhi, '
          'atau target tabungan dan cadangan kurang.',
        ),
      ],
    );
  }

  // ==========================================
  // RESULT PAGE
  // ==========================================

  Widget _resultPage(
    SalaryAnalysis result,
  ) {
    final tier = result.tier;

    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        // -----------------------------------
        // RESULT HERO CARD
        // -----------------------------------

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                _darkGreen,
                _green,
              ],
            ),
            borderRadius:
                BorderRadius.circular(25),
          ),

          child: Column(
            children: [
              const Text(
                'HASIL ANALISIS PEKERJAAN',
                style: TextStyle(
                  color: Colors.white70,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                tier?.letter ?? '-',
                style: const TextStyle(
                  fontSize: 76,
                  height: 1,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                tier == null
                    ? 'Data belum lengkap'
                    : 'Tier ${tier.letter} · '
                        '${tier.label}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                'Skor ${result.score ?? 0}/100',
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),

              if (result.tierReason != null) ...[
                const SizedBox(height: 13),

                Text(
                  result.tierReason!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              ],

              const SizedBox(height: 18),
              const Divider(
                color: Colors.white24,
              ),
              const SizedBox(height: 6),

              Text(
                result.finalSurplus < 0
                    ? 'Kekurangan dari anggaran bulanan'
                    : 'Uang bebas setelah seluruh kebutuhan',
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                rupiah(
                  result.finalSurplus.abs(),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 10),

              LinearProgressIndicator(
                value: result.budgetRequired > 0
                    ? (
                        result.combinedIncome /
                        result.budgetRequired
                      ).clamp(0, 1).toDouble()
                    : 1,
                minHeight: 8,
                backgroundColor:
                    Colors.white24,
                color: const Color(0xFFBBF7D0),
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),

        // -----------------------------------
        // SALARY BREAKDOWN
        // -----------------------------------

        _panel(
          'Rincian perhitungan',
          Icons.receipt_long_outlined,
          [
            _resultRow(
              'Gaji bruto',
              rupiah(result.grossSalary),
            ),

            _resultRow(
              'Gaji bersih',
              rupiah(result.takeHomePay),
              strong: true,
            ),

            const Divider(),

            _resultRow(
              'Transportasi bekerja',
              '- ${rupiah(result.monthlyTransport)}',
            ),

            _resultRow(
              'Tambahan makan bekerja',
              '- ${rupiah(result.monthlyMeals)}',
            ),

            _resultRow(
              'Total biaya bekerja',
              '- ${rupiah(result.monthlyWorkCosts)}',
              strong: true,
            ),

            _resultRow(
              'Sisa gaji setelah biaya kerja',
              rupiah(result.remainingAfterWork),
              strong: true,
            ),

            const Divider(),

            _resultRow(
              'Pemasukan tambahan dari Planner',
              rupiah(result.needs.otherIncome),
            ),

            _resultRow(
              'Total pemasukan tersedia',
              rupiah(result.combinedIncome),
            ),

            _resultRow(
              'Kebutuhan hidup',
              '- ${rupiah(result.needs.livingCosts)}',
            ),

            _resultRow(
              'Target tabungan',
              '- ${rupiah(result.needs.savings)}',
            ),

            _resultRow(
              'Dana cadangan',
              '- ${rupiah(result.budgetReserve)}',
            ),

            _resultRow(
              'Target uang bebas',
              '- ${rupiah(
                ref
                    .read(salaryCalculatorProvider)
                    .money('targetRemaining'),
              )}',
            ),

            const Divider(),

            _resultRow(
              'Selisih akhir',
              rupiah(result.finalSurplus),
              strong: true,
              color: result.finalSurplus < 0
                  ? colors.error
                  : _green,
            ),
          ],
        ),

        const SizedBox(height: 15),

        // -----------------------------------
        // TIME ANALYSIS
        // -----------------------------------

        _panel(
          'Nilai waktumu',
          Icons.schedule_outlined,
          [
            _resultRow(
              'Waktu perjalanan / bulan',
              '${result.monthlyCommuteHours.toStringAsFixed(1)} jam',
            ),

            _resultRow(
              'Jarak perjalanan / bulan',
              '${result.monthlyDistance.toStringAsFixed(1)} km',
            ),

            _resultRow(
              'Total waktu kerja + perjalanan',
              '${result.committedHours.toStringAsFixed(1)} jam',
            ),

            _resultRow(
              'Pendapatan efektif / jam',
              rupiah(result.effectiveHourlyIncome),
              strong: true,
              color: _green,
            ),
          ],
        ),

        const SizedBox(height: 15),

        // -----------------------------------
        // TIER DETAILS
        // -----------------------------------

        _tierDetails(result),

        const SizedBox(height: 12),

        _hint(
          'Hasil ini adalah simulasi berdasarkan '
          'data dan preferensimu, bukan jaminan '
          'kualitas atau kelayakan suatu pekerjaan.',
        ),

        const SizedBox(height: 16),

        // -----------------------------------
        // EDIT INPUT
        // -----------------------------------

        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _darkGreen,
            padding:
                const EdgeInsets.symmetric(
              vertical: 16,
            ),
          ),
          onPressed: () {
            final notifier =
                ref.read(
              salaryCalculatorProvider.notifier,
            );

            notifier.setShowResults(false);
            notifier.setStep(0);
          },
          icon: const Icon(
            Icons.edit_outlined,
          ),
          label: const Text(
            'Ubah data dan hitung ulang',
          ),
        ),

        // -----------------------------------
        // RESET INPUT
        // -----------------------------------

        TextButton.icon(
          onPressed: () async {
            final reset =
                await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text(
                  'Reset kalkulator?',
                ),
                content: const Text(
                  'Semua isian kalkulator akan '
                  'dikembalikan ke nilai awal. '
                  'Data Planner tidak dihapus.',
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(
                      context,
                      false,
                    ),
                    child: const Text('Batal'),
                  ),

                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(
                      context,
                      true,
                    ),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            );

            if (reset == true && mounted) {
              _reset();
            }
          },
          icon: const Icon(
            Icons.restart_alt,
          ),
          label: const Text(
            'Reset kalkulator',
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MAIN BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final draft =
        ref.watch(salaryCalculatorProvider);

    final analysis =
        ref.watch(salaryAnalysisProvider);

    return ListView(
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        32,
      ),
      children: [
        if (draft.showResults)
          _resultPage(analysis)
        else ...[
          _stepNavigation(draft),

          const SizedBox(height: 18),

          _stepContent(
            draft,
            analysis,
          ),

          const SizedBox(height: 18),

          _stepButtons(
            draft,
            analysis,
          ),
        ],
      ],
    );
  }
}