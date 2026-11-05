import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../data/plan_repository.dart';
import '../models/finance_plan.dart';

String _groupThousands(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
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

class _MoneyInputFormatter extends TextInputFormatter {
  const _MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _groupThousands(newValue.text);
    final rawCursor = newValue.selection.baseOffset
        .clamp(0, newValue.text.length)
        .toInt();
    final digitCount = newValue.text
        .substring(0, rawCursor)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    var cursor = 0;
    var seenDigits = 0;
    while (cursor < formatted.length && seenDigits < digitCount) {
      if (RegExp(r'[0-9]').hasMatch(formatted[cursor])) {
        seenDigits++;
      }
      cursor++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}

enum SalaryPaymentMode { monthly, daily, hourly, session }

extension SalaryPaymentModeLabel on SalaryPaymentMode {
  String get label => switch (this) {
        SalaryPaymentMode.monthly => 'Bulanan',
        SalaryPaymentMode.daily => 'Harian',
        SalaryPaymentMode.hourly => 'Per jam',
        SalaryPaymentMode.session => 'Per sesi',
      };

  String get unitLabel => switch (this) {
        SalaryPaymentMode.monthly => '',
        SalaryPaymentMode.daily => 'Berapa hari dibayar tiap bulan?',
        SalaryPaymentMode.hourly => 'Berapa jam dibayar tiap bulan?',
        SalaryPaymentMode.session => 'Berapa sesi dibayar tiap bulan?',
      };
}

class SalaryCalculatorSection extends StatefulWidget {
  const SalaryCalculatorSection({
    super.key,
    this.initialMonthlySalary = 0,
  });

  final int initialMonthlySalary;

  @override
  State<SalaryCalculatorSection> createState() =>
      _SalaryCalculatorSectionState();
}

class _StepInfo {
  const _StepInfo(this.title, this.description, this.icon);
  final String title;
  final String description;
  final IconData icon;
}

class _TierInfo {
  const _TierInfo({
    required this.letter,
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
  });

  final String letter;
  final String title;
  final String description;
  final Color color;
  final IconData icon;
}

class _NeedsSnapshot {
  const _NeedsSnapshot({
    required this.ready,
    required this.fromPlanner,
    required this.housing,
    required this.food,
    required this.transportOutsideWork,
    required this.bills,
    required this.personal,
    required this.other,
    required this.savings,
    required this.bufferPercent,
    required this.otherIncome,
  });

  final bool ready;
  final bool fromPlanner;
  final int housing;
  final int food;
  final int transportOutsideWork;
  final int bills;
  final int personal;
  final int other;
  final int savings;
  final int bufferPercent;
  final int otherIncome;

  int get livingCosts =>
      housing + food + transportOutsideWork + bills + personal + other;
}

class _SalaryCalculatorSectionState extends State<SalaryCalculatorSection> {
  static const _forest = Color(0xFF064E3B);
  static const _mint = Color(0xFF10B981);
  static const _teal = Color(0xFF0D9488);
  static const _orange = Color(0xFFF59E0B);
  static const _moneyKeys = <String>{
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
  static const _steps = <_StepInfo>[
    _StepInfo('Gaji', 'Penghasilan yang diterima', Icons.payments_rounded),
    _StepInfo('Jadwal', 'Waktu bekerja', Icons.calendar_month_rounded),
    _StepInfo('Perjalanan', 'Ongkos dan waktu di jalan', Icons.train_rounded),
    _StepInfo('Biaya lain', 'Pengeluaran karena bekerja', Icons.receipt_long_rounded),
    _StepInfo('Kebutuhan', 'Bandingkan dengan kebutuhanmu', Icons.shopping_bag_outlined),
    _StepInfo('Prioritas', 'Apa yang penting buatmu', Icons.favorite_rounded),
  ];
  static const _tiers = <_TierInfo>[
    _TierInfo(
      letter: 'S',
      title: 'Sangat worth it',
      description: 'Sangat sesuai dengan target uang, waktu, dan hal yang kamu anggap penting.',
      color: Color(0xFF047857),
      icon: Icons.workspace_premium_rounded,
    ),
    _TierInfo(
      letter: 'A',
      title: 'Worth it',
      description: 'Pilihan yang menarik. Sebagian besar kebutuhan dan prioritasmu terpenuhi.',
      color: Color(0xFF0D9488),
      icon: Icons.stars_rounded,
    ),
    _TierInfo(
      letter: 'B',
      title: 'Cukup worth it',
      description: 'Ada sisi yang menarik, tetapi masih ada hal yang perlu dipertimbangkan.',
      color: Color(0xFF2563EB),
      icon: Icons.thumb_up_alt_rounded,
    ),
    _TierInfo(
      letter: 'C',
      title: 'Pikirkan lagi',
      description: 'Beberapa hal penting belum cocok. Sebaiknya bandingkan dengan pilihan lain.',
      color: Color(0xFFB45309),
      icon: Icons.lightbulb_rounded,
    ),
    _TierInfo(
      letter: 'D',
      title: 'Kurang worth it',
      description: 'Cukup banyak hal yang tidak sesuai. Pertimbangkan risikonya sebelum menerima.',
      color: Color(0xFFB91C1C),
      icon: Icons.warning_amber_rounded,
    ),
  ];

  SalaryPaymentMode _mode = SalaryPaymentMode.monthly;
  int _currentStep = 0;
  int _careerRating = 3;
  int _workEnvironmentRating = 3;
  bool _showResults = false;
  bool _sameReturnTrip = false;
  bool _showTierReasons = false;
  String? _tierGuideLetter;
  FinancePlan? _plannerPlan;
  bool _loadingPlannerPlan = true;
  bool _usePlannerNeeds = true;
  bool _includePlannerOtherIncome = true;
  late final Map<String, TextEditingController> _inputs;

  @override
  void initState() {
    super.initState();
    final defaults = <String, String>{
      'rate': widget.initialMonthlySalary > 0
          ? widget.initialMonthlySalary.toString()
          : '',
      'units': '22',
      'allowance': '0',
      'bonus': '0',
      'overtime': '0',
      'otherIncome': '0',
      'deductions': '0',
      'workDays': '22',
      'officeDays': '22',
      'workHours': '8',
      'daysPerWeek': '5',
      'goCost': '0',
      'returnCost': '0',
      'goMinutes': '0',
      'returnMinutes': '0',
      'goDistance': '0',
      'returnDistance': '0',
      'extraMeals': '0',
      'otherWorkCosts': '0',
      'targetRemaining': '',
      'comfortableCommute': '120',
      'plannerTransportOutsideWork': '0',
      'manualHousing': '',
      'manualFood': '',
      'manualTransportOutsideWork': '',
      'manualBills': '',
      'manualPersonal': '',
      'manualOther': '',
      'manualSavings': '',
      'manualBufferPercent': '10',
    };
    _inputs = defaults.map(
      (key, value) => MapEntry(key, TextEditingController(text: value)),
    );
    for (final key in _moneyKeys) {
      _inputs[key]!.text = _groupThousands(_inputs[key]!.text);
    }
    _loadPlannerPlan();
  }

  Future<void> _loadPlannerPlan() async {
    FinancePlan? plan;
    try {
      plan = await PlanRepository().loadPlan();
    } catch (_) {
      plan = null;
    }
    if (!mounted) return;
    setState(() {
      _plannerPlan = plan;
      _loadingPlannerPlan = false;
      if (plan == null) _usePlannerNeeds = false;
    });
  }

  @override
  void dispose() {
    for (final controller in _inputs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int _money(String key) => parseRupiah(_inputs[key]!.text);

  double _number(String key) {
    final value = double.tryParse(
      _inputs[key]!.text.trim().replaceAll(',', '.'),
    );
    if (value == null || !value.isFinite || value < 0) return 0;
    return value;
  }

  int _wholeNumber(String key, {int max = 1000000}) =>
      _number(key).round().clamp(0, max).toInt();

  _NeedsSnapshot _needsSnapshot() {
    final plan = _usePlannerNeeds ? _plannerPlan : null;
    if (plan != null) {
      return _NeedsSnapshot(
        ready: true,
        fromPlanner: true,
        housing: plan.housing,
        food: plan.food,
        transportOutsideWork: _money('plannerTransportOutsideWork'),
        bills: plan.bills,
        personal: plan.personal,
        other: plan.monthlyCustomExpenses,
        savings: plan.savings,
        bufferPercent: plan.bufferPercent.clamp(0, 100).toInt(),
        otherIncome:
            _includePlannerOtherIncome ? plan.monthlyAdditionalIncome : 0,
      );
    }
    if (_usePlannerNeeds && _loadingPlannerPlan) {
      return const _NeedsSnapshot(
        ready: false,
        fromPlanner: false,
        housing: 0,
        food: 0,
        transportOutsideWork: 0,
        bills: 0,
        personal: 0,
        other: 0,
        savings: 0,
        bufferPercent: 0,
        otherIncome: 0,
      );
    }
    final housing = _money('manualHousing');
    final food = _money('manualFood');
    final transport = _money('manualTransportOutsideWork');
    final bills = _money('manualBills');
    final personal = _money('manualPersonal');
    final other = _money('manualOther');
    final savings = _money('manualSavings');
    return _NeedsSnapshot(
      ready: housing + food + transport + bills + personal + other + savings > 0,
      fromPlanner: false,
      housing: housing,
      food: food,
      transportOutsideWork: transport,
      bills: bills,
      personal: personal,
      other: other,
      savings: savings,
      bufferPercent: _wholeNumber('manualBufferPercent', max: 100),
      otherIncome: 0,
    );
  }

  void _setField(String key, num value) {
    final controller = _inputs[key]!;
    final raw = value is int || value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
    final next = _moneyKeys.contains(key) ? _groupThousands(raw) : raw;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() {});
  }

  void _updateReturnTrip() {
    if (!_sameReturnTrip) return;
    for (final pair in const [
      ('goCost', 'returnCost'),
      ('goMinutes', 'returnMinutes'),
      ('goDistance', 'returnDistance'),
    ]) {
      final source = _inputs[pair.$1]!.text;
      final target = _inputs[pair.$2]!;
      target.value = TextEditingValue(
        text: source,
        selection: TextSelection.collapsed(offset: source.length),
      );
    }
  }

  _SalaryResult _calculate() {
    final rate = _money('rate');
    final units = _number('units');
    final baseSalary = _mode == SalaryPaymentMode.monthly
        ? rate
        : (rate * units).round();
    final additionalIncome = _money('allowance') +
        _money('bonus') +
        _money('overtime') +
        _money('otherIncome');
    final grossSalary = baseSalary + additionalIncome;
    final deductions = _money('deductions');
    final takeHomePay = grossSalary - deductions;
    final workDays = _wholeNumber('workDays', max: 31);
    final officeDays = _wholeNumber('officeDays', max: 31)
        .clamp(0, workDays)
        .toInt();
    final dailyWorkHours = _number('workHours');
    final daysPerWeek = _number('daysPerWeek');
    final transport = (_money('goCost') + _money('returnCost')) * officeDays;
    final meals = _money('extraMeals') * officeDays;
    final otherCosts = _money('otherWorkCosts');
    final workCosts = transport + meals + otherCosts;
    final remaining = takeHomePay - workCosts;
    final dailyCommute = _number('goMinutes') + _number('returnMinutes');
    final commuteHours = dailyCommute * officeDays / 60;
    final committedHours = workDays * dailyWorkHours + commuteHours;
    final hourly = committedHours > 0
        ? (remaining / committedHours).round()
        : 0;
    final monthlyDistance =
        (_number('goDistance') + _number('returnDistance')) * officeDays;
    final target = _money('targetRemaining');
    final comfortableCommute = _number('comfortableCommute');
    final needs = _needsSnapshot();
    final combinedIncome = takeHomePay + needs.otherIncome;
    final basicNeeds = needs.livingCosts;
    // Ongkos lama dari Planner sengaja tidak dimasukkan: rute pekerjaan
    // yang sedang dinilai menggantikannya. Transport non-kerja diisi terpisah.
    final bufferBase = basicNeeds + workCosts + needs.savings;
    final budgetBuffer =
        (bufferBase * needs.bufferPercent + 99) ~/ 100;
    final afterNeeds = combinedIncome - workCosts - basicNeeds;
    final afterSavings = afterNeeds - needs.savings;
    final afterBuffer = afterSavings - budgetBuffer;
    final finalSurplus = afterBuffer - target;
    final fullBudget = bufferBase + budgetBuffer + target;

    int? score;
    int? financialScore;
    int? travelScore;
    int? balanceScore;
    if (grossSalary > 0 && needs.ready) {
      // Sebagian terbesar skor berasal dari kemampuan memenuhi kebutuhan,
      // tabungan, cadangan, dan target tambahan. Skor maksimal memerlukan
      // ruang lebih 20% di atas total anggaran.
      financialScore = afterNeeds < 0
          ? 0
          : finalSurplus >= (fullBudget * 0.2).ceil()
              ? 50
              : finalSurplus >= 0
                  ? 44
                  : afterBuffer >= 0
                      ? 36
                      : afterSavings >= 0
                          ? 27
                          : 15;
      travelScore = officeDays == 0
          ? 20
          : comfortableCommute <= 0
              ? 0
              : dailyCommute <= comfortableCommute
                  ? 20
                  : dailyCommute <= comfortableCommute * 1.5
                      ? 12
                      : 4;
      final weeklyHours = dailyWorkHours * daysPerWeek;
      balanceScore = weeklyHours <= 40
          ? 10
          : weeklyHours <= 48
              ? 6
              : 2;
      score = financialScore +
          travelScore +
          balanceScore +
          _careerRating * 2 +
          _workEnvironmentRating * 2;
    }

    return _SalaryResult(
      baseSalary: baseSalary,
      additionalIncome: additionalIncome,
      grossSalary: grossSalary,
      deductions: deductions,
      takeHomePay: takeHomePay,
      monthlyTransportCost: transport,
      extraMealCost: meals,
      otherWorkCosts: otherCosts,
      monthlyWorkCosts: workCosts,
      remainingIncome: remaining,
      monthlyCommuteHours: commuteHours,
      dailyCommuteMinutes: dailyCommute,
      monthlyDistance: monthlyDistance,
      totalCommittedHours: committedHours,
      effectiveHourlyIncome: hourly,
      workDays: workDays,
      officeDays: officeDays,
      targetRemaining: target,
      budgetReady: needs.ready,
      needsFromPlanner: needs.fromPlanner,
      additionalOutsideIncome: needs.otherIncome,
      livingNeeds: basicNeeds,
      housingNeeds: needs.housing,
      foodNeeds: needs.food,
      transportOutsideWork: needs.transportOutsideWork,
      billsNeeds: needs.bills,
      personalNeeds: needs.personal,
      otherNeeds: needs.other,
      savingsGoal: needs.savings,
      reserveGoal: budgetBuffer,
      combinedIncome: combinedIncome,
      afterNeeds: afterNeeds,
      afterSavings: afterSavings,
      afterBuffer: afterBuffer,
      budgetRequired: fullBudget,
      finalSurplus: finalSurplus,
      score: score,
      financialScore: financialScore,
      travelScore: travelScore,
      balanceScore: balanceScore,
      careerScore: score == null ? null : _careerRating * 2,
      environmentScore: score == null ? null : _workEnvironmentRating * 2,
    );
  }

  Widget _surface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _sectionHeading(String title, String description, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colors.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _field(
    String key,
    String label, {
    bool money = false,
    String? suffix,
    String? hint,
  }) {
    final colors = Theme.of(context).colorScheme;
    final controller = _inputs[key]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: money
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: money
              ? [const _MoneyInputFormatter()]
              : [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: money ? '0' : 'Isi angka',
            prefixText: money ? 'Rp ' : null,
            suffixText: suffix,
            filled: true,
            fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onTap: () {
            if (controller.text == '0') {
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            }
          },
          onChanged: (_) {
            if (_sameReturnTrip &&
                (key == 'goCost' ||
                    key == 'goMinutes' ||
                    key == 'goDistance')) {
              _updateReturnTrip();
            }
            setState(() {});
          },
        ),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  Widget _two(Widget first, Widget second) => LayoutBuilder(
        builder: (context, size) {
          if (size.maxWidth < 560 ||
              MediaQuery.textScalerOf(context).scale(16) / 16 > 1.25) {
            return Column(
              children: [
                first,
                const SizedBox(height: 15),
                second,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 15),
              Expanded(child: second),
            ],
          );
        },
      );

  Widget _quickButton(String title, VoidCallback action, {IconData? icon}) {
    return ActionChip(
      avatar: icon == null ? null : Icon(icon, size: 17),
      label: Text(title),
      onPressed: action,
    );
  }

  Widget _stepIncome() {
    final colors = Theme.of(context).colorScheme;
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Berapa penghasilanmu?',
            'Pilih cara pembayaran, lalu isi jumlah yang ditawarkan.',
            Icons.payments_rounded,
          ),
          const Text(
            'Aku dibayar...',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in SalaryPaymentMode.values)
                ChoiceChip(
                  label: Text(mode.label),
                  selected: _mode == mode,
                  onSelected: (_) {
                    setState(() {
                      _mode = mode;
                      _inputs['rate']!.clear();
                      _inputs['units']!.text =
                          mode == SalaryPaymentMode.hourly
                              ? '176'
                              : mode == SalaryPaymentMode.session
                                  ? '40'
                                  : '22';
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
          _field(
            'rate',
            _mode == SalaryPaymentMode.monthly
                ? 'Gaji pokok per bulan'
                : 'Tarif ' + _mode.label.toLowerCase(),
            money: true,
            hint: 'Masukkan jumlah sebelum tunjangan dan potongan.',
          ),
          if (_mode != SalaryPaymentMode.monthly) ...[
            const SizedBox(height: 15),
            _field('units', _mode.unitLabel),
          ],
          if (_mode == SalaryPaymentMode.monthly) ...[
            const SizedBox(height: 12),
            Text(
              'Contoh penghasilan bulanan',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 7,
              runSpacing: 3,
              children: [
                _quickButton('Rp5 juta', () => _setField('rate', 5000000)),
                _quickButton('Rp7 juta', () => _setField('rate', 7000000)),
                _quickButton('Rp10 juta', () => _setField('rate', 10000000)),
              ],
            ),
          ],
          const SizedBox(height: 18),
          ExpansionTile(
            key: const ValueKey('income_extras'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text(
              'Ada tunjangan, bonus, atau potongan?',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Opsional, isi jika ada.'),
            children: [
              const SizedBox(height: 10),
              _two(
                _field('allowance', 'Tunjangan / bulan', money: true),
                _field('bonus', 'Bonus / bulan', money: true),
              ),
              const SizedBox(height: 15),
              _two(
                _field('overtime', 'Uang lembur', money: true),
                _field(
                  'otherIncome',
                  'Tambahan dari pekerjaan ini',
                  money: true,
                  hint: 'Jangan masukkan freelance yang sudah tercatat '
                      'sebagai pemasukan tambahan di Planner.',
                ),
              ),
              const SizedBox(height: 15),
              _field(
                'deductions',
                'Total potongan gaji',
                money: true,
                hint: 'Contoh: pajak, BPJS, atau potongan lain.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepWork() => _surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading(
              'Seperti apa jadwal kerjanya?',
              'Agar biaya dan waktu kerja dihitung sesuai rutinitasmu.',
              Icons.calendar_month_rounded,
            ),
            const Text(
              'Pilih jadwal yang paling mendekati',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _quickButton('Senin–Jumat', () {
                  _setField('workDays', 22);
                  _setField('officeDays', 22);
                  _setField('daysPerWeek', 5);
                }, icon: Icons.calendar_view_week_rounded),
                _quickButton('Senin–Sabtu', () {
                  _setField('workDays', 26);
                  _setField('officeDays', 26);
                  _setField('daysPerWeek', 6);
                }, icon: Icons.date_range_rounded),
                _quickButton('Kerja remote', () {
                  _setField('officeDays', 0);
                }, icon: Icons.home_work_rounded),
              ],
            ),
            const SizedBox(height: 18),
            _two(
              _field(
                'workDays',
                'Total hari kerja dalam sebulan',
                suffix: 'hari',
              ),
              _field(
                'officeDays',
                'Berapa hari perlu pergi ke kantor?',
                suffix: 'hari',
                hint: 'Isi 0 jika selalu bekerja dari rumah.',
              ),
            ),
            const SizedBox(height: 15),
            _two(
              _field('workHours', 'Jam kerja per hari', suffix: 'jam'),
              _field('daysPerWeek', 'Hari kerja per minggu', suffix: 'hari'),
            ),
            const SizedBox(height: 16),
            _hintBox(
              Icons.lightbulb_outline_rounded,
              'Kalau jadwalmu tidak tetap, gunakan rata-rata satu bulan.',
            ),
          ],
        ),
      );

  Widget _stepTransport() {
    final result = _calculate();
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Berapa ongkos pergi bekerja?',
            'Isi biaya dan waktu sekali berangkat serta sekali pulang.',
            Icons.directions_transit_rounded,
          ),
          _hintBox(
            Icons.calendar_today_rounded,
            result.officeDays == 0
                ? 'Kamu memilih 0 hari ke kantor. Biaya perjalanan menjadi Rp0.'
                : 'Perjalanan dihitung untuk ' +
                    result.officeDays.toString() +
                    ' hari ke kantor setiap bulan.',
          ),
          const SizedBox(height: 17),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Biaya dan waktu pulang sama'),
            subtitle: const Text('Isi sekali, otomatis disamakan.'),
            value: _sameReturnTrip,
            onChanged: (value) {
              setState(() => _sameReturnTrip = value);
              if (value) _updateReturnTrip();
            },
          ),
          const SizedBox(height: 10),
          _two(
            _field('goCost', 'Ongkos berangkat', money: true),
            _field(
              'returnCost',
              'Ongkos pulang',
              money: true,
              hint: _sameReturnTrip ? 'Mengikuti biaya berangkat.' : null,
            ),
          ),
          const SizedBox(height: 17),
          _two(
            _field('goMinutes', 'Waktu berangkat', suffix: 'menit'),
            _field('returnMinutes', 'Waktu pulang', suffix: 'menit'),
          ),
          const SizedBox(height: 17),
          ExpansionTile(
            key: const ValueKey('distance_optional'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Ingin menghitung jarak juga?'),
            subtitle: const Text('Opsional, untuk melihat total jarak bulanan.'),
            children: [
              _two(
                _field('goDistance', 'Jarak berangkat', suffix: 'km'),
                _field('returnDistance', 'Jarak pulang', suffix: 'km'),
              ),
              const SizedBox(height: 6),
            ],
          ),
          const SizedBox(height: 14),
          _miniSummary(
            Icons.train_rounded,
            'Estimasi ongkos transportasi / bulan',
            rupiah(result.monthlyTransportCost),
          ),
        ],
      ),
    );
  }

  Widget _stepExpenses() {
    final result = _calculate();
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Ada biaya lain saat bekerja?',
            'Masukkan pengeluaran yang muncul karena pekerjaan.',
            Icons.receipt_long_rounded,
          ),
          _hintBox(
            Icons.info_outline_rounded,
            'Kalau tidak ada, biarkan Rp0. Angka ini tidak mengubah transaksi FinPlan.',
          ),
          const SizedBox(height: 18),
          _field(
            'extraMeals',
            'Tambahan biaya makan setiap hari ke kantor',
            money: true,
            hint: 'Hanya biaya tambahan, bukan seluruh pengeluaran makan.',
          ),
          const SizedBox(height: 16),
          _field(
            'otherWorkCosts',
            'Biaya kerja lain dalam sebulan',
            money: true,
            hint: 'Contoh: parkir, pulsa kerja, atau perlengkapan.',
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _quickButton('Tidak ada biaya lain', () {
                _setField('extraMeals', 0);
                _setField('otherWorkCosts', 0);
              }, icon: Icons.check_circle_outline_rounded),
            ],
          ),
          const SizedBox(height: 20),
          _miniSummary(
            Icons.receipt_long_rounded,
            'Total biaya bekerja / bulan',
            rupiah(result.monthlyWorkCosts),
          ),
        ],
      ),
    );
  }

  Widget _rating(
    String title,
    String description,
    int value,
    ValueChanged<int> onChanged,
  ) {
    final colors = Theme.of(context).colorScheme;
    final label = value <= 2
        ? 'Kurang cocok'
        : value == 3
            ? 'Cukup'
            : 'Bagus';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              value.toString() + '/5',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        Slider(
          min: 1,
          max: 5,
          divisions: 4,
          value: value.toDouble(),
          label: label,
          onChanged: (next) => onChanged(next.round()),
        ),
      ],
    );
  }

  Widget _stepNeeds() {
    final plan = _plannerPlan;
    final needs = _needsSnapshot();
    final result = _calculate();
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Cukup untuk kebutuhan hidupmu?',
            'Kita bandingkan gaji pekerjaan baru dengan kebutuhan bulananmu.',
            Icons.shopping_bag_outlined,
          ),
          if (_loadingPlannerPlan) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            const Text('Sedang mengambil anggaran yang tersimpan...'),
          ] else ...[
            Text(
              'Sumber kebutuhan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (plan != null)
                  ChoiceChip(
                    avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Pakai data Planner'),
                    selected: _usePlannerNeeds,
                    onSelected: (_) => setState(() => _usePlannerNeeds = true),
                  ),
                ChoiceChip(
                  avatar: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Isi kebutuhan manual'),
                  selected: !_usePlannerNeeds,
                  onSelected: (_) => setState(() => _usePlannerNeeds = false),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (plan == null) ...[
              _hintBox(
                Icons.info_outline_rounded,
                'Belum ada anggaran tersimpan di Rencana & Anggaran. '
                'Kamu tetap bisa mengisi kebutuhan langsung di sini.',
              ),
              const SizedBox(height: 16),
            ],
            if (_usePlannerNeeds && plan != null) ...[
              _hintBox(
                Icons.check_circle_outline_rounded,
                plan.name.trim().isEmpty
                    ? 'Kebutuhan tersimpan dari Planner dipakai otomatis. '
                        'Kamu bisa mengubahnya di Rencana & Anggaran.'
                    : 'Kebutuhan dari Planner milik ${plan.name} dipakai '
                        'otomatis. Kamu bisa mengubahnya di Rencana & Anggaran.',
              ),
              const SizedBox(height: 13),
              _detailRow('Tempat tinggal', rupiah(plan.housing)),
              _detailRow('Makan harian', rupiah(plan.food)),
              _detailRow('Tagihan', rupiah(plan.bills)),
              _detailRow('Kebutuhan pribadi', rupiah(plan.personal)),
              _detailRow('Kebutuhan tambahan', rupiah(plan.monthlyCustomExpenses)),
              _detailRow('Target tabungan', rupiah(plan.savings)),
              _detailRow('Dana cadangan', '${plan.bufferPercent}% dari anggaran'),
              const Divider(height: 25),
              _hintBox(
                Icons.train_rounded,
                'Transportasi Planner (${rupiah(plan.transport)}/bulan) '
                'diasumsikan sebagai ongkos pekerjaan lama, jadi tidak '
                'ditambahkan otomatis. Ongkos pekerjaan baru sudah dihitung '
                'di langkah Perjalanan. Isi transportasi pribadi lain di bawah.',
              ),
              const SizedBox(height: 13),
              _field(
                'plannerTransportOutsideWork',
                'Transportasi di luar pekerjaan / bulan',
                money: true,
                hint: 'Contoh: perjalanan pribadi, ibadah, atau antar keluarga.',
              ),
              if (plan.monthlyAdditionalIncome > 0) ...[
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _includePlannerOtherIncome,
                  onChanged: (enabled) => setState(
                    () => _includePlannerOtherIncome = enabled,
                  ),
                  title: const Text('Hitung pemasukan tambahan dari Planner'),
                  subtitle: Text(
                    '${rupiah(plan.monthlyAdditionalIncome)}/bulan. '
                    'Matikan jika penghasilan sampingan tidak berlanjut.',
                  ),
                ),
              ],
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () {
                  setState(() => _loadingPlannerPlan = true);
                  _loadPlannerPlan();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Muat ulang kebutuhan Planner'),
              ),
            ] else ...[
              const Text(
                'Isi perkiraan biaya setiap bulan. Boleh Rp0 jika memang '
                'tidak ada. Data ini hanya dipakai untuk simulasi.',
              ),
              const SizedBox(height: 16),
              _two(
                _field('manualHousing', 'Tempat tinggal', money: true),
                _field('manualFood', 'Makan dan kebutuhan dapur', money: true),
              ),
              const SizedBox(height: 15),
              _two(
                _field('manualBills', 'Tagihan bulanan', money: true),
                _field('manualPersonal', 'Kebutuhan pribadi', money: true),
              ),
              const SizedBox(height: 15),
              _two(
                _field('manualOther', 'Kebutuhan lainnya', money: true),
                _field(
                  'manualTransportOutsideWork',
                  'Transport di luar pekerjaan',
                  money: true,
                ),
              ),
              const SizedBox(height: 15),
              _two(
                _field('manualSavings', 'Target tabungan bulanan', money: true),
                _field(
                  'manualBufferPercent',
                  'Dana cadangan',
                  suffix: '%',
                  hint: 'Persentase dari biaya kerja + kebutuhan + tabungan.',
                ),
              ),
              if (!needs.ready) ...[
                const SizedBox(height: 14),
                _hintBox(
                  Icons.flag_outlined,
                  'Isi setidaknya satu kebutuhan atau target tabungan '
                  'agar Tier S–D bisa dihitung dengan masuk akal.',
                ),
              ],
            ],
            const SizedBox(height: 20),
            _miniSummary(
              Icons.shopping_bag_rounded,
              'Total kebutuhan hidup / bulan (di luar ongkos kerja baru)',
              rupiah(needs.livingCosts),
            ),
            const SizedBox(height: 9),
            _miniSummary(
              Icons.savings_rounded,
              'Tabungan + dana cadangan yang ditargetkan',
              rupiah(needs.savings + result.reserveGoal),
            ),
            const SizedBox(height: 14),
            _hintBox(
              Icons.restaurant_rounded,
              'Anggaran makan tetap dihitung. Kolom "tambahan makan" '
              'di langkah sebelumnya hanya untuk biaya makan ekstra '
              'yang BELUM termasuk anggaran kebutuhan di sini.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepPreferences() {
    final takeHome = _calculate().takeHomePay;
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Apa yang penting buatmu?',
            'Pilihan setiap orang berbeda. Sesuaikan dengan kebutuhanmu.',
            Icons.favorite_rounded,
          ),
          _field(
            'targetRemaining',
            'Uang bebas tambahan yang ingin disisakan (opsional)',
            money: true,
            hint: 'Di luar kebutuhan, tabungan, dan dana cadangan '
                'yang sudah dihitung di langkah sebelumnya.',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _quickButton('Tanpa target ekstra', () {
                _setField('targetRemaining', 0);
              }),
              _quickButton('Rp500 ribu', () {
                _setField('targetRemaining', 500000);
              }),
              _quickButton('Rp1 juta', () {
                _setField('targetRemaining', 1000000);
              }),
              if (takeHome > 0)
                _quickButton('10% gaji', () {
                  _setField('targetRemaining', (takeHome * .1).round());
                }),
            ],
          ),
          const SizedBox(height: 18),
          _field(
            'comfortableCommute',
            'Berapa menit perjalanan pulang-pergi yang nyaman?',
            suffix: 'menit',
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            children: [
              _quickButton('1 jam', () => _setField('comfortableCommute', 60)),
              _quickButton('2 jam', () => _setField('comfortableCommute', 120)),
              _quickButton('3 jam', () => _setField('comfortableCommute', 180)),
            ],
          ),
          const SizedBox(height: 18),
          _rating(
            'Peluang berkembang',
            'Menurutmu, seberapa bagus prospek di pekerjaan ini?',
            _careerRating,
            (value) => setState(() => _careerRating = value),
          ),
          const SizedBox(height: 8),
          _rating(
            'Kenyamanan kerja',
            'Bagaimana lingkungan dan kondisi kerjanya?',
            _workEnvironmentRating,
            (value) => setState(() => _workEnvironmentRating = value),
          ),
        ],
      ),
    );
  }

  Widget _hintBox(IconData icon, String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  Widget _miniSummary(IconData icon, String title, String value) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressHeader() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kenali nilai pekerjaanmu',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Isi sedikit demi sedikit. Kamu bisa kembali kapan saja.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              'Langkah ${_currentStep + 1} dari ${_steps.length}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              _steps[_currentStep].title,
              style: TextStyle(color: colors.primary),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _steps.length,
            minHeight: 8,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 13),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                ChoiceChip(
                  avatar: Icon(_steps[i].icon, size: 17),
                  label: Text(_steps[i].title),
                  selected: i == _currentStep,
                  onSelected: (_) => setState(() => _currentStep = i),
                ),
                const SizedBox(width: 7),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepContent() => switch (_currentStep) {
        0 => _stepIncome(),
        1 => _stepWork(),
        2 => _stepTransport(),
        3 => _stepExpenses(),
        4 => _stepNeeds(),
        _ => _stepPreferences(),
      };

  void _goToResults() {
    if (_calculate().grossSalary <= 0) {
      setState(() {
        _showResults = false;
        _currentStep = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan gaji terlebih dahulu untuk melihat hasil.'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _showResults = true);
  }

  Widget _bottomBar(_SalaryResult result) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final largeText =
                MediaQuery.textScalerOf(context).scale(16) / 16 > 1.3;
            final compact = constraints.maxWidth < 430 || largeText;
            final preview = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.budgetReady
                      ? 'Sisa setelah seluruh anggaran'
                      : 'Sisa setelah ongkos bekerja',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  rupiah(result.budgetReady
                      ? result.finalSurplus
                      : result.remainingIncome),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: (result.budgetReady
                                    ? result.finalSurplus
                                    : result.remainingIncome) <
                                0
                            ? colors.error
                            : colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            );
            final actions = Row(
              children: [
                if (_currentStep > 0) ...[
                  IconButton.outlined(
                    tooltip: 'Langkah sebelumnya',
                    onPressed: () => setState(() => _currentStep--),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _currentStep == _steps.length - 1
                        ? _goToResults
                        : () => setState(() => _currentStep++),
                    child: Text(
                      _currentStep == _steps.length - 1
                          ? (compact ? 'Hasil' : 'Lihat hasil')
                          : 'Lanjut',
                    ),
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  preview,
                  const SizedBox(height: 10),
                  actions,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: preview),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: actions),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _moneyHero(_SalaryResult result) {
    final hasBudget = result.budgetReady;
    final displayValue = hasBudget ? result.finalSurplus : result.remainingIncome;
    final loss = displayValue < 0;
    final headline = !hasBudget
        ? (loss
            ? 'Biaya pekerjaan ini sudah melebihi gaji bersih, '
                'bahkan sebelum kebutuhan hidup dihitung.'
            : 'Belum termasuk kebutuhan hidup. Isi langkah Kebutuhan '
                'untuk hasil lengkap.')
        : loss
            ? 'Masih kurang ${rupiah(-displayValue)} untuk menutup seluruh anggaranmu.'
            : 'Kebutuhan, tabungan, dan cadanganmu sudah diperhitungkan.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: loss
              ? [const Color(0xFF9A3412), const Color(0xFF7C2D12)]
              : [const Color(0xFF087253), _forest],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white70,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            hasBudget
                ? (loss ? 'Kekurangan dari anggaran / bulan' : 'Uang bebas setelah semua target')
                : (loss ? 'Kekurangan biaya bekerja' : 'Sisa setelah ongkos bekerja'),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            rupiah(displayValue.abs()),
            softWrap: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasBudget) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: result.budgetRequired > 0
                    ? (result.combinedIncome / result.budgetRequired)
                        .clamp(0.0, 1.0)
                        .toDouble()
                    : 1.0,
                minHeight: 9,
                backgroundColor: Colors.white30,
                color: const Color(0xFF86EFAC),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Total anggaran (termasuk biaya kerja): ${rupiah(result.budgetRequired)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  _TierInfo? _tierForResult(_SalaryResult result) {
    final score = result.score;
    if (score == null) return null;

    // Kebutuhan dasar harus terpenuhi sebelum tawaran dinilai layak.
    if (result.remainingIncome <= 0 || result.afterNeeds < 0) {
      return _tiers[4];
    }

    var tierIndex = score >= 90
        ? 0
        : score >= 80
            ? 1
            : score >= 65
                ? 2
                : score >= 50
                    ? 3
                    : 4;

    // Belum bisa memenuhi target tabungan: maksimal Tier C.
    if (result.afterSavings < 0 && tierIndex < 3) {
      tierIndex = 3;
    } else if (result.finalSurplus < 0 && tierIndex < 2) {
      // Tabungan terpenuhi, tetapi cadangan/target ekstra belum: maksimal B.
      tierIndex = 2;
    } else if (result.financialScore != 50 && tierIndex == 0) {
      // Tier S membutuhkan ruang finansial yang betul-betul lega.
      tierIndex = 1;
    }
    return _tiers[tierIndex];
  }

  String? _tierLimitNote(_SalaryResult result) {
    if (result.score == null) return null;
    if (result.remainingIncome <= 0) {
      return 'Gaji bersih dari pekerjaan ini habis untuk biaya bekerja. '
          'Walau ada pemasukan lain, tawarannya masuk Tier D.';
    }
    if (result.afterNeeds < 0) {
      return 'Penghasilan belum menutupi kebutuhan hidup dan biaya '
          'kerja. Hasil masuk Tier D agar risiko keuangannya terlihat jelas.';
    }
    if (result.afterSavings < 0) {
      return 'Kebutuhan pokok sudah tertutup, tetapi target tabungan '
          'belum terpenuhi. Tier maksimal C.';
    }
    if (result.finalSurplus < 0) {
      return 'Tabungan bisa terpenuhi, tetapi dana cadangan atau '
          'target uang bebas masih kurang. Tier maksimal B.';
    }
    if (result.score! >= 90 && result.financialScore != 50) {
      return 'Hasil bagus, tetapi ruang uang bebas belum cukup besar '
          'untuk Tier S. Tier tertinggi saat ini A.';
    }
    return null;
  }

  Widget _tierFactor(String title, int points, int maxPoints, String hint) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$points/$maxPoints',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: points / maxPoints,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
            backgroundColor: colors.surfaceContainerHighest,
            color: _mint,
            semanticsLabel: '$title: $points dari $maxPoints poin',
          ),
          const SizedBox(height: 5),
          Text(hint, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _tierCard(_SalaryResult result) {
    final assigned = _tierForResult(result);
    final limitNote = _tierLimitNote(result);
    final accent = assigned?.color ?? _forest;
    final heading = assigned == null
        ? (result.grossSalary <= 0
            ? 'Isi tawaran gaji dulu, yuk'
            : 'Hubungkan kebutuhanmu dulu')
        : assigned.title;
    final message = assigned == null
        ? (result.grossSalary <= 0
            ? 'Masukkan nominal penghasilan agar tawaran kerja bisa dinilai.'
            : 'Pilih kebutuhan dari Planner atau isi kebutuhan manual '
                'agar Tier S–D sesuai kondisi hidupmu.')
        : assigned.description;
    final guide = _tierGuideLetter == null
        ? null
        : _tiers.firstWhere((tier) => tier.letter == _tierGuideLetter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, Color.lerp(accent, Colors.black, 0.42)!],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    assigned?.icon ?? Icons.auto_awesome_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'HASIL KELAYAKAN PEKERJAAN',
                      style: TextStyle(
                        color: Colors.white70,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 76),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x25FFFFFF),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: const Color(0x55FFFFFF)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TIER',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          assigned?.letter ?? '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 46,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          heading,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (assigned == null)
                FilledButton.icon(
                  onPressed: () => setState(() {
                    _showResults = false;
                    _currentStep = result.grossSalary <= 0 ? 0 : 4;
                  }),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _forest,
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(result.grossSalary <= 0 ? 'Isi gaji' : 'Isi kebutuhan'),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x25FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insights_rounded,
                          color: Colors.white, size: 19),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Skor kecocokan ${result.score}/100 · '
                          'berdasarkan prioritasmu',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (limitNote != null) ...[
                  const SizedBox(height: 11),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Colors.white, size: 19),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          limitNote,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kenali tingkatan hasil',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Tier yang diberi tanda adalah hasilmu. Ketuk huruf '
                'lain untuk tahu artinya.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tier in _tiers)
                    ActionChip(
                      tooltip: 'Tier ${tier.letter}: ${tier.title}',
                      avatar: assigned?.letter == tier.letter
                          ? const Icon(Icons.check_circle_rounded, size: 17)
                          : null,
                      backgroundColor: assigned?.letter == tier.letter
                          ? tier.color.withAlpha(24)
                          : null,
                      side: BorderSide(
                        color: assigned?.letter == tier.letter
                            ? tier.color
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: assigned?.letter == tier.letter ? 2 : 1,
                      ),
                      label: Text(
                        'Tier ${tier.letter}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: assigned?.letter == tier.letter
                              ? tier.color
                              : null,
                        ),
                      ),
                      onPressed: () => setState(() {
                        _tierGuideLetter = _tierGuideLetter == tier.letter
                            ? null
                            : tier.letter;
                      }),
                    ),
                ],
              ),
              if (guide != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: guide.color.withAlpha(20),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: guide.color.withAlpha(90)),
                  ),
                  child: Text(
                    'Tier ${guide.letter} — ${guide.title}\n${guide.description}',
                  ),
                ),
              ],
              const SizedBox(height: 11),
              const Divider(),
              if (result.score != null)
                TextButton.icon(
                  onPressed: () => setState(
                    () => _showTierReasons = !_showTierReasons,
                  ),
                  icon: Icon(_showTierReasons
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded),
                  label: Text(_showTierReasons
                      ? 'Tutup alasan penilaian'
                      : 'Kenapa aku dapat tier ini?'),
                )
              else
                const Text(
                  'Isi data gaji dan target uang untuk membuka rincian penilaian.',
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _showTierReasons && result.score != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Penilaian dibagi menjadi 5 hal sederhana:',
                          ),
                          _tierFactor(
                            'Kecukupan kebutuhan & tabungan',
                            result.financialScore!,
                            50,
                            'Apakah penghasilan cukup untuk kebutuhan, '
                                'tabungan, cadangan, dan target tambahan?',
                          ),
                          _tierFactor(
                            'Waktu perjalanan',
                            result.travelScore!,
                            20,
                            'Apakah perjalanan sesuai batas nyamanmu?',
                          ),
                          _tierFactor(
                            'Beban jam kerja',
                            result.balanceScore!,
                            10,
                            'Apakah jadwal memberi ruang untuk kehidupan pribadi?',
                          ),
                          _tierFactor(
                            'Peluang berkembang',
                            result.careerScore!,
                            10,
                            'Diambil dari nilai peluang karier yang kamu pilih.',
                          ),
                          _tierFactor(
                            'Kenyamanan kerja',
                            result.environmentScore!,
                            10,
                            'Diambil dari nilai kenyamanan yang kamu pilih.',
                          ),
                          const SizedBox(height: 14),
                          _hintBox(
                            Icons.info_outline_rounded,
                            'S: 90–100 · A: 80–89 · B: 65–79 · '
                            'C: 50–64 · D: 0–49. '
                            'Tier dibatasi jika kebutuhan atau tabungan '
                            'belum terpenuhi. '
                            'Ini simulasi pribadi, bukan keputusan mutlak.',
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricTile(String label, String value, IconData icon, Color color) {
    return _surface(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 9),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTiles(_SalaryResult result) => LayoutBuilder(
        builder: (context, size) {
          final cards = [
            _metricTile(
              'Gaji bersih',
              rupiah(result.takeHomePay),
              Icons.payments_rounded,
              _mint,
            ),
            _metricTile(
              'Biaya kerja',
              rupiah(result.monthlyWorkCosts),
              Icons.receipt_long_rounded,
              _orange,
            ),
          ];
          if (size.maxWidth < 420) {
            return Column(
              children: [
                cards[0],
                const SizedBox(height: 10),
                cards[1],
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ],
          );
        },
      );

  Widget _needsComparison(_SalaryResult result) {
    if (!result.budgetReady) {
      return _surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Belum ada perbandingan kebutuhan',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Masukkan kebutuhan dari Planner atau secara manual. '
              'Setelah itu FinPlan bisa menilai kemampuan gaji '
              'memenuhi kebutuhan, tabungan, dan dana cadanganmu.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => setState(() {
                _showResults = false;
                _currentStep = 4;
              }),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Isi kebutuhan sekarang'),
            ),
          ],
        ),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final enoughNeeds = result.afterNeeds >= 0;
    final enoughSavings = result.afterSavings >= 0;
    final enoughAll = result.finalSurplus >= 0;
    final reference = result.combinedIncome > 0 ? result.combinedIncome : 1;
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Gaji vs kebutuhanmu',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Chip(
                avatar: Icon(
                  result.needsFromPlanner
                      ? Icons.auto_awesome_rounded
                      : Icons.edit_note_rounded,
                  size: 16,
                ),
                label: Text(result.needsFromPlanner ? 'Dari Planner' : 'Isi manual'),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Bandingkan penghasilan bulanan dengan seluruh anggaran '
            'yang ingin kamu penuhi.',
          ),
          const SizedBox(height: 17),
          _detailRow(
            'Gaji bersih pekerjaan baru',
            rupiah(result.takeHomePay),
            strong: true,
          ),
          if (result.additionalOutsideIncome > 0)
            _detailRow(
              'Pemasukan sampingan (Planner)',
              '+ ${rupiah(result.additionalOutsideIncome)}',
            ),
          _detailRow(
            'Total uang tersedia',
            rupiah(result.combinedIncome),
            strong: true,
          ),
          const Divider(height: 27),
          _bar(
            'Ongkos & biaya bekerja',
            result.monthlyWorkCosts,
            reference,
            _teal,
            Icons.train_rounded,
          ),
          _bar(
            'Kebutuhan hidup bulanan',
            result.livingNeeds,
            reference,
            const Color(0xFF6366F1),
            Icons.shopping_bag_rounded,
          ),
          _bar(
            'Target tabungan',
            result.savingsGoal,
            reference,
            _mint,
            Icons.savings_rounded,
          ),
          _bar(
            'Dana cadangan',
            result.reserveGoal,
            reference,
            _orange,
            Icons.shield_outlined,
          ),
          if (result.targetRemaining > 0)
            _bar(
              'Target uang bebas ekstra',
              result.targetRemaining,
              reference,
              const Color(0xFFEC4899),
              Icons.wallet_rounded,
            ),
          const Divider(height: 26),
          _detailRow(
            'Seluruh anggaran yang dibutuhkan',
            rupiah(result.budgetRequired),
            strong: true,
          ),
          _detailRow(
            enoughAll ? 'Uang lebih' : 'Anggaran masih kurang',
            rupiah(result.finalSurplus.abs()),
            strong: true,
          ),
          const SizedBox(height: 12),
          _hintBox(
            enoughAll
                ? Icons.check_circle_rounded
                : enoughNeeds
                    ? Icons.info_outline_rounded
                    : Icons.warning_amber_rounded,
            !enoughNeeds
                ? 'Kebutuhan hidup dan biaya bekerja belum seluruhnya '
                    'tertutup. Masih kurang ${rupiah(-result.afterNeeds)}.'
                : !enoughSavings
                    ? 'Kebutuhan pokok aman, tapi target tabungan '
                        'belum tercapai. Kurang ${rupiah(-result.afterSavings)}.'
                    : enoughAll
                        ? 'Bagus! Kebutuhan, tabungan, dan cadangan '
                            'yang kamu rencanakan sudah tertutup.'
                        : 'Kebutuhan dan tabungan tertutup, tetapi '
                            'cadangan atau uang bebas tambahan masih kurang.',
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 10),
            leading: Icon(Icons.category_outlined, color: colors.primary),
            title: const Text('Lihat rincian kebutuhan hidup'),
            children: [
              _detailRow('Tempat tinggal', rupiah(result.housingNeeds)),
              _detailRow('Makan', rupiah(result.foodNeeds)),
              _detailRow(
                'Transportasi di luar pekerjaan',
                rupiah(result.transportOutsideWork),
              ),
              _detailRow('Tagihan', rupiah(result.billsNeeds)),
              _detailRow('Kebutuhan pribadi', rupiah(result.personalNeeds)),
              _detailRow('Lainnya', rupiah(result.otherNeeds)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Catatan: ongkos dari pekerjaan lama di Planner tidak '
            'dihitung ulang. Biaya pekerjaan baru diambil dari form '
            'Kalkulator Gaji. Angka ini adalah simulasi, bukan saldo aktual.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _bar(
    String label,
    int amount,
    int reference,
    Color color,
    IconData icon,
  ) {
    final colors = Theme.of(context).colorScheme;
    final fraction = reference > 0
        ? (amount / reference).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 9),
              Expanded(child: Text(label)),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  rupiah(amount),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 9,
              color: color,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _whereMoneyGoes(_SalaryResult result) {
    final reference = result.takeHomePay > 0 ? result.takeHomePay : 1;
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rincian biaya pekerjaan baru',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pengeluaran yang muncul karena pekerjaan ini saja, '
            'belum termasuk kebutuhan hidup.',
          ),
          const SizedBox(height: 19),
          _bar(
            'Transportasi',
            result.monthlyTransportCost,
            reference,
            _teal,
            Icons.train_rounded,
          ),
          _bar(
            'Makan tambahan',
            result.extraMealCost,
            reference,
            _orange,
            Icons.restaurant_rounded,
          ),
          _bar(
            'Biaya kerja lainnya',
            result.otherWorkCosts,
            reference,
            const Color(0xFF6366F1),
            Icons.receipt_rounded,
          ),
          _bar(
            'Sisa setelah biaya kerja (sebelum kebutuhan hidup)',
            result.remainingIncome.clamp(0, 1000000000000).toInt(),
            reference,
            _mint,
            Icons.savings_rounded,
          ),
        ],
      ),
    );
  }

  Widget _timeSummary(_SalaryResult result) => _surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bagaimana dengan waktumu?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 15),
            _insightRow(
              Icons.schedule_rounded,
              'Total perjalanan dalam sebulan',
              result.monthlyCommuteHours.toStringAsFixed(1) + ' jam',
            ),
            const SizedBox(height: 12),
            _insightRow(
              Icons.work_history_rounded,
              'Waktu kerja + perjalanan',
              result.totalCommittedHours.toStringAsFixed(1) + ' jam',
            ),
            const SizedBox(height: 12),
            _insightRow(
              Icons.paid_rounded,
              'Setara penghasilan per jam',
              rupiah(result.effectiveHourlyIncome),
            ),
            const SizedBox(height: 13),
            _hintBox(
              Icons.info_outline_rounded,
              'Nilai per jam dihitung setelah biaya kerja, termasuk waktu perjalanan. Ini hanya alat bantu membandingkan tawaran.',
            ),
          ],
        ),
      );

  Widget _insightRow(IconData icon, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colors.primary, size: 22),
        const SizedBox(width: 11),
        Expanded(child: Text(label)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _insightCard(IconData icon, String title, String description, bool good) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: good
            ? colors.primaryContainer.withValues(alpha: 0.45)
            : colors.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: good ? colors.primary : colors.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _friendlyAnalysis(_SalaryResult result) {
    final comfortable = _number('comfortableCommute');
    final travelTooLong = result.officeDays > 0 &&
        comfortable > 0 &&
        result.dailyCommuteMinutes > comfortable;
    final weeklyHours = _number('workHours') * _number('daysPerWeek');
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hal yang perlu kamu pertimbangkan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          const Text('Bukan nilai mutlak. Gunakan sebagai bahan pertimbangan.'),
          const SizedBox(height: 16),
          if (!result.budgetReady)
            _insightCard(
              Icons.flag_outlined,
              'Kebutuhan belum diisi',
              'Gunakan data Planner atau isi kebutuhan manual '
                  'supaya Tier S–D bisa dinilai.',
              false,
            )
          else if (result.afterNeeds < 0)
            _insightCard(
              Icons.warning_amber_rounded,
              'Kebutuhan bulanan belum tertutup',
              'Masih kurang ${rupiah(-result.afterNeeds)} setelah '
                  'biaya pekerjaan baru dan kebutuhan hidup dihitung.',
              false,
            )
          else if (result.afterSavings < 0)
            _insightCard(
              Icons.savings_outlined,
              'Kebutuhan aman, tabungan perlu disesuaikan',
              'Target tabungan masih kurang ${rupiah(-result.afterSavings)} '
                  'dengan tawaran gaji ini.',
              false,
            )
          else if (result.finalSurplus >= 0)
            _insightCard(
              Icons.check_circle_rounded,
              'Anggaran dan target terpenuhi',
              'Kebutuhan, tabungan, cadangan, serta uang bebas '
                  'tambahan berhasil ditutup oleh penghasilan bulanan.',
              true,
            )
          else
            _insightCard(
              Icons.shield_outlined,
              'Dana cadangan atau target ekstra belum penuh',
              'Kebutuhan dan tabungan tertutup, tetapi total '
                  'anggaran masih kurang ${rupiah(-result.finalSurplus)}.',
              false,
            ),
          _insightCard(
            travelTooLong ? Icons.timer_outlined : Icons.train_rounded,
            travelTooLong
                ? 'Perjalanan lebih lama dari batas nyamanmu'
                : 'Waktu perjalanan sudah diperhitungkan',
            result.officeDays == 0
                ? 'Karena tidak ke kantor, biaya dan waktu perjalanan dihitung nol.'
                : 'Pergi-pulang sekitar ' +
                    result.dailyCommuteMinutes.toStringAsFixed(0) +
                    ' menit pada hari ke kantor.',
            !travelTooLong,
          ),
          if (weeklyHours > 48)
            _insightCard(
              Icons.bedtime_outlined,
              'Jadwal kerja cukup padat',
              'Sisihkan waktu istirahat dan kegiatan di luar pekerjaan.',
              false,
            ),
          if (_careerRating <= 2 || _workEnvironmentRating <= 2)
            _insightCard(
              Icons.favorite_border_rounded,
              'Pertimbangkan kenyamanan dan perkembangan',
              'Ada hal non-gaji yang kamu nilai kurang cocok.',
              false,
            ),
          if (_careerRating >= 4 && _workEnvironmentRating >= 4)
            _insightCard(
              Icons.emoji_emotions_rounded,
              'Cukup sesuai preferensimu',
              'Kamu memberi nilai baik untuk prospek dan kenyamanan.',
              true,
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: strong ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _calculationDetails(_SalaryResult result) {
    return _surface(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 4),
      child: ExpansionTile(
        key: const ValueKey('salary_calculation_details_v2'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 20),
        title: const Text(
          'Bagaimana uang tersisa dihitung?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text('Ketuk untuk melihat rincian angkanya.'),
        leading: const Icon(Icons.receipt_long_rounded),
        children: [
          _detailRow('Gaji pokok', rupiah(result.baseSalary)),
          _detailRow('Tambahan penghasilan', '+ ' + rupiah(result.additionalIncome)),
          _detailRow('Potongan gaji', '- ' + rupiah(result.deductions)),
          const Divider(),
          _detailRow('Gaji bersih', rupiah(result.takeHomePay), strong: true),
          if (result.additionalOutsideIncome > 0)
            _detailRow('Pemasukan sampingan', '+ ${rupiah(result.additionalOutsideIncome)}'),
          const SizedBox(height: 7),
          _detailRow('Transportasi', '- ' + rupiah(result.monthlyTransportCost)),
          _detailRow('Tambahan makan', '- ' + rupiah(result.extraMealCost)),
          _detailRow('Biaya kerja lain', '- ' + rupiah(result.otherWorkCosts)),
          const Divider(),
          _detailRow(
            'Sisa setelah biaya kerja',
            rupiah(result.remainingIncome + result.additionalOutsideIncome),
            strong: true,
          ),
          if (result.budgetReady) ...[
            _detailRow('Kebutuhan hidup', '- ${rupiah(result.livingNeeds)}'),
            _detailRow('Target tabungan', '- ${rupiah(result.savingsGoal)}'),
            _detailRow('Dana cadangan', '- ${rupiah(result.reserveGoal)}'),
            if (result.targetRemaining > 0)
              _detailRow('Target uang bebas', '- ${rupiah(result.targetRemaining)}'),
            const Divider(),
            _detailRow(
              'Uang lebih / kekurangan',
              rupiah(result.finalSurplus),
              strong: true,
            ),
          ],
          const SizedBox(height: 10),
          _hintBox(
            Icons.calculate_outlined,
            'Perhitungan dimulai dari gaji bersih dan pemasukan sampingan, '
            'dikurangi biaya pekerjaan baru, kebutuhan hidup, tabungan, '
            'cadangan, serta target tambahan. Biaya harian dikalikan '
            'dengan jumlah hari ke kantor.',
          ),
        ],
      ),
    );
  }

  Widget _resultsPage(_SalaryResult result) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 5,
          children: [
            Text(
              'Hasil simulasimu',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _showResults = false),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Ubah data'),
            ),
          ],
        ),
        const SizedBox(height: 7),
        const Text('Lihat keuangan, waktu, dan kenyamanan dalam satu tempat.'),
        const SizedBox(height: 18),
        _tierCard(result),
        const SizedBox(height: 12),
        _moneyHero(result),
        const SizedBox(height: 12),
        _needsComparison(result),
        const SizedBox(height: 12),
        _summaryTiles(result),
        const SizedBox(height: 12),
        _whereMoneyGoes(result),
        const SizedBox(height: 12),
        _timeSummary(result),
        const SizedBox(height: 12),
        _friendlyAnalysis(result),
        const SizedBox(height: 12),
        _calculationDetails(result),
        const SizedBox(height: 20),
        _surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mau mencoba angka lain?',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Coba ubah gaji, ongkos kerja, atau anggaran kebutuhan, '
                'lalu bandingkan tier-nya.',
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _quickButton('Ubah gaji', () {
                    setState(() {
                      _showResults = false;
                      _currentStep = 0;
                    });
                  }, icon: Icons.payments_outlined),
                  _quickButton('Ubah perjalanan', () {
                    setState(() {
                      _showResults = false;
                      _currentStep = 2;
                    });
                  }, icon: Icons.train_outlined),
                  _quickButton('Ubah kebutuhan', () {
                    setState(() {
                      _showResults = false;
                      _currentStep = 4;
                    });
                  }, icon: Icons.shopping_bag_outlined),
                  _quickButton('Ubah prioritas', () {
                    setState(() {
                      _showResults = false;
                      _currentStep = 5;
                    });
                  }, icon: Icons.favorite_outline_rounded),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Pajak dan BPJS tidak dihitung otomatis. Isi potongan pada form jika ada. '
          'Simulasi tidak mengubah saldo maupun transaksi FinPlan.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _calculate();
    if (_showResults) {
      return _resultsPage(result);
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
            children: [
              _progressHeader(),
              const SizedBox(height: 17),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                child: KeyedSubtree(
                  key: ValueKey('salary_step_' + _currentStep.toString()),
                  child: _stepContent(),
                ),
              ),
            ],
          ),
        ),
        _bottomBar(result),
      ],
    );
  }
}

class _SalaryResult {
  const _SalaryResult({
    required this.baseSalary,
    required this.additionalIncome,
    required this.grossSalary,
    required this.deductions,
    required this.takeHomePay,
    required this.monthlyTransportCost,
    required this.extraMealCost,
    required this.otherWorkCosts,
    required this.monthlyWorkCosts,
    required this.remainingIncome,
    required this.monthlyCommuteHours,
    required this.dailyCommuteMinutes,
    required this.monthlyDistance,
    required this.totalCommittedHours,
    required this.effectiveHourlyIncome,
    required this.workDays,
    required this.officeDays,
    required this.targetRemaining,
    required this.budgetReady,
    required this.needsFromPlanner,
    required this.additionalOutsideIncome,
    required this.livingNeeds,
    required this.housingNeeds,
    required this.foodNeeds,
    required this.transportOutsideWork,
    required this.billsNeeds,
    required this.personalNeeds,
    required this.otherNeeds,
    required this.savingsGoal,
    required this.reserveGoal,
    required this.combinedIncome,
    required this.afterNeeds,
    required this.afterSavings,
    required this.afterBuffer,
    required this.budgetRequired,
    required this.finalSurplus,
    required this.score,
    required this.financialScore,
    required this.travelScore,
    required this.balanceScore,
    required this.careerScore,
    required this.environmentScore,
  });

  final int baseSalary;
  final int additionalIncome;
  final int grossSalary;
  final int deductions;
  final int takeHomePay;
  final int monthlyTransportCost;
  final int extraMealCost;
  final int otherWorkCosts;
  final int monthlyWorkCosts;
  final int remainingIncome;
  final double monthlyCommuteHours;
  final double dailyCommuteMinutes;
  final double monthlyDistance;
  final double totalCommittedHours;
  final int effectiveHourlyIncome;
  final int workDays;
  final int officeDays;
  final int targetRemaining;
  final bool budgetReady;
  final bool needsFromPlanner;
  final int additionalOutsideIncome;
  final int livingNeeds;
  final int housingNeeds;
  final int foodNeeds;
  final int transportOutsideWork;
  final int billsNeeds;
  final int personalNeeds;
  final int otherNeeds;
  final int savingsGoal;
  final int reserveGoal;
  final int combinedIncome;
  final int afterNeeds;
  final int afterSavings;
  final int afterBuffer;
  final int budgetRequired;
  final int finalSurplus;
  final int? score;
  final int? financialScore;
  final int? travelScore;
  final int? balanceScore;
  final int? careerScore;
  final int? environmentScore;
}
