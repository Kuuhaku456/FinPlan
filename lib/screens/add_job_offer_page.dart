
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../models/job_offer.dart';
import '../state/job_offer_controller.dart';

class AddJobOfferPage extends StatefulWidget {
  const AddJobOfferPage({
    super.key,
    required this.controller,
    this.initialOffer,
  });

  final JobOfferController controller;
  final JobOffer? initialOffer;

  @override
  State<AddJobOfferPage> createState() =>
      _AddJobOfferPageState();
}

class _AddJobOfferPageState extends State<AddJobOfferPage> {
  static const Color darkGreen = Color(0xFF064E3B);
  static const Color green = Color(0xFF10B981);
  static const Color softGreen = Color(0xFFE9F8F0);
  static const Color muted = Color(0xFF84958C);

  late final JobOffer _baseOffer;

  late final Map<String, TextEditingController> _fields;

  late JobSalaryMode _salaryMode;
  late int _careerRating;
  late int _environmentRating;

  bool _isSubmitting = false;
  // Simpan status tiap panel secara eksplisit agar tidak bergantung pada
  // animasi ExpansionTile saat form diperbarui.
  final Map<String, bool> _expandedSections = <String, bool>{};

  bool get _isEditing => widget.initialOffer != null;

  @override
  void initState() {
    super.initState();

    _baseOffer = widget.initialOffer ??
        JobOffer.create(title: '');

    _salaryMode = _baseOffer.salaryMode;
    _careerRating = _baseOffer.careerRating;
    _environmentRating = _baseOffer.environmentRating;

    final values = <String, String>{
      'title': _baseOffer.title,
      'company': _baseOffer.company,
      'location': _baseOffer.location,
      'notes': _baseOffer.notes,

      'salaryRate': _baseOffer.salaryRate == 0
          ? ''
          : _baseOffer.salaryRate.toString(),

      'paidUnits': _baseOffer.paidUnitsPerMonth.toString(),

      'allowances': _baseOffer.allowances.toString(),
      'bonuses': _baseOffer.bonuses.toString(),
      'overtime': _baseOffer.overtimeIncome.toString(),
      'otherIncome': _baseOffer.otherIncome.toString(),
      'deductions': _baseOffer.deductions.toString(),

      'workDays': _baseOffer.workDaysPerMonth.toString(),
      'officeDays': _baseOffer.officeDaysPerMonth.toString(),
      'daysPerWeek': _baseOffer.daysPerWeek.toString(),
      'hoursPerDay': _baseOffer.hoursPerDay.toString(),

      'goCost': _baseOffer.goCost.toString(),
      'returnCost': _baseOffer.returnCost.toString(),

      'goMinutes': _baseOffer.goMinutes.toString(),
      'returnMinutes': _baseOffer.returnMinutes.toString(),

      'goDistance': _baseOffer.goDistanceKm.toString(),
      'returnDistance': _baseOffer.returnDistanceKm.toString(),

      'extraMealCost': _baseOffer.extraMealCost.toString(),
      'otherWorkCosts': _baseOffer.otherWorkCosts.toString(),

      'targetRemaining': _baseOffer.targetRemaining == 0
          ? ''
          : _baseOffer.targetRemaining.toString(),

      'comfortableCommute':
          _baseOffer.comfortableCommuteMinutes.toString(),
    };

    _fields = values.map(
      (key, value) => MapEntry(
        key,
        TextEditingController(text: value),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // =====================================================
  // INPUT HELPERS
  // =====================================================

  String _text(String key) {
    return _fields[key]!.text.trim();
  }

  int _money(String key) {
    return parseRupiah(_fields[key]!.text);
  }

  double _number(String key) {
    final text = _fields[key]!
        .text
        .trim()
        .replaceAll(',', '.');

    final value = double.tryParse(text);

    if (value == null || !value.isFinite || value < 0) {
      return 0;
    }

    return value;
  }

  int _wholeNumber(
    String key, {
    int max = 1000000,
  }) {
    return _number(key).round().clamp(0, max).toInt();
  }

  // =====================================================
  // BUILD MODEL
  // =====================================================

  JobOffer _buildOffer() {
    return _baseOffer.copyWith(
      title: _text('title'),
      company: _text('company'),
      location: _text('location'),
      notes: _text('notes'),

      salaryMode: _salaryMode,
      salaryRate: _money('salaryRate'),
      paidUnitsPerMonth: _number('paidUnits'),

      allowances: _money('allowances'),
      bonuses: _money('bonuses'),
      overtimeIncome: _money('overtime'),
      otherIncome: _money('otherIncome'),
      deductions: _money('deductions'),

      workDaysPerMonth:
          _wholeNumber('workDays', max: 31),

      officeDaysPerMonth:
          _wholeNumber('officeDays', max: 31),

      daysPerWeek:
          _wholeNumber('daysPerWeek', max: 7),

      hoursPerDay: _number('hoursPerDay'),

      goCost: _money('goCost'),
      returnCost: _money('returnCost'),

      goMinutes: _number('goMinutes'),
      returnMinutes: _number('returnMinutes'),

      goDistanceKm: _number('goDistance'),
      returnDistanceKm: _number('returnDistance'),

      extraMealCost: _money('extraMealCost'),
      otherWorkCosts: _money('otherWorkCosts'),

      targetRemaining: _money('targetRemaining'),

      comfortableCommuteMinutes:
          _number('comfortableCommute'),

      careerRating: _careerRating,
      environmentRating: _environmentRating,
    );
  }

  // =====================================================
  // VALIDATION
  // =====================================================

  String? _validateAllInputs() {
    if (_text('title').isEmpty) {
      return 'Nama posisi pekerjaan wajib diisi.';
    }

    if (_money('salaryRate') <= 0) {
      return 'Masukkan gaji lebih dari Rp0.';
    }

    if (_salaryMode != JobSalaryMode.monthly &&
        _number('paidUnits') <= 0) {
      return 'Jumlah hari, jam, atau sesi harus lebih dari nol.';
    }

    final workDays = _number('workDays');
    final officeDays = _number('officeDays');
    final daysPerWeek = _number('daysPerWeek');
    final hoursPerDay = _number('hoursPerDay');

    if (workDays <= 0 || workDays > 31) {
      return 'Hari kerja per bulan harus antara 1–31.';
    }

    if (officeDays > workDays) {
      return 'Hari ke kantor tidak boleh melebihi hari kerja.';
    }

    if (daysPerWeek <= 0 || daysPerWeek > 7) {
      return 'Hari kerja per minggu harus antara 1–7.';
    }

    if (hoursPerDay <= 0 || hoursPerDay > 24) {
      return 'Jam kerja per hari harus antara 1–24.';
    }

    return null;
  }

  // =====================================================
  // SAVE
  // =====================================================

  Future<void> _save() async {
    if (_isSubmitting || widget.controller.isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final error = _validateAllInputs();

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'Periksa kembali input pekerjaan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final offer = _buildOffer();

      final success = _isEditing
          ? await widget.controller.updateOffer(offer)
          : await widget.controller.createOffer(offer);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.errorMessage ??
                'Gagal menyimpan tawaran pekerjaan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Terjadi kesalahan saat menyimpan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // =====================================================
  // FORM WIDGETS
  // =====================================================

  Widget _textInput(
    String label,
    String key, {
    int maxLines = 1,
    String? hint,
  }) {
    return _inputWrapper(
      label: label,
      child: TextField(
        key: ValueKey('job_offer_field_$key'),
        controller: _fields[key],
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: _inputDecoration(hint: hint),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _moneyInput(
    String label,
    String key,
  ) {
    return _inputWrapper(
      label: label,
      child: TextField(
        key: ValueKey('job_offer_field_$key'),
        controller: _fields[key],
        keyboardType: TextInputType.number,
        maxLines: 1,
        expands: false,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: _inputDecoration(
          prefix: 'Rp ',
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _numberInput(
    String label,
    String key, {
    String? suffix,
  }) {
    return _inputWrapper(
      label: label,
      child: TextField(
        key: ValueKey('job_offer_field_$key'),
        controller: _fields[key],
        keyboardType:
            const TextInputType.numberWithOptions(
          decimal: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(r'[0-9,.]'),
          ),
        ],
        decoration: _inputDecoration(
          suffix: suffix,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    String? prefix,
    String? suffix,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 12,
        color: muted,
      ),
      prefixText: prefix,
      suffixText: suffix,
      filled: true,
      fillColor: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHighest
          : const Color(0xFFF6F9F7),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _inputWrapper({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _pair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 440) {
          return Column(
            children: [
              first,
              const SizedBox(height: 13),
              second,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 13),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  // =====================================================
  // EXPANDABLE SECTION
  // =====================================================

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool expanded = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isExpanded = _expandedSections[title] ?? expanded;

    return Container(
      key: ValueKey('job_offer_section_$title'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: scheme.brightness == Brightness.dark
              ? Colors.white12
              : const Color(0xFFE7EFE9),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  _expandedSections[title] = !isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 39,
                      height: 39,
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: isExpanded ? green : scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 6, 17, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // =====================================================
  // SALARY MODE
  // =====================================================

  Widget _salaryModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sistem pembayaran',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 9),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: JobSalaryMode.values.map((mode) {
            final selected = _salaryMode == mode;

            return ChoiceChip(
              selected: selected,
              showCheckmark: false,
              selectedColor: darkGreen,
              label: Text(mode.label),
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) {
                if (selected) return;

                setState(() {
                  _salaryMode = mode;

                  _fields['salaryRate']!.clear();

                  if (mode == JobSalaryMode.hourly) {
                    _fields['paidUnits']!.text = '176';
                  } else if (mode == JobSalaryMode.session) {
                    _fields['paidUnits']!.text = '40';
                  } else {
                    _fields['paidUnits']!.text = '22';
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // =====================================================
  // RATING
  // =====================================================

  Widget _ratingSlider({
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: softGreen,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$value/5',
                style: const TextStyle(
                  color: darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),

        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: green,
          label: '$value',
          onChanged: (next) => onChanged(next.round()),
        ),
      ],
    );
  }

  // =====================================================
  // LIVE PREVIEW
  // =====================================================

  Widget _buildPreview() {
    final offer = _buildOffer();
    final score = offer.worthScore;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF087557),
            darkGreen,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFBCEBD4),
                size: 20,
              ),
              SizedBox(width: 9),
              Text(
                'HASIL SIMULASI',
                style: TextStyle(
                  color: Color(0xFFBCEBD4),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          const Text(
            'Perkiraan uang tersisa',
            style: TextStyle(
              color: Color(0xFFC6ECDD),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 5),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(offer.remainingMonthlyIncome),
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
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 20,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    offer.worthVerdict.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),

                if (score != null)
                  Text(
                    '$score/100',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),

          if (score != null) ...[
            const SizedBox(height: 13),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 7,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(
                  Color(0xFF98ECC4),
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _previewMetric(
                  'Gaji bersih',
                  rupiah(offer.takeHomePay),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _previewMetric(
                  'Biaya bekerja',
                  rupiah(offer.totalMonthlyWorkCosts),
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Expanded(
                child: _previewMetric(
                  'Perjalanan / bulan',
                  '${offer.monthlyCommuteHours.toStringAsFixed(1)} jam',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _previewMetric(
                  'Efektif / jam',
                  rupiah(offer.effectiveHourlyIncome),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFBCE6D2),
            fontSize: 10,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // MAIN UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final saving =
            _isSubmitting || widget.controller.isSaving;

        return Scaffold(
          backgroundColor:
              theme.scaffoldBackgroundColor,

          appBar: AppBar(
            title: Text(
              _isEditing
                  ? 'Edit Tawaran'
                  : 'Tawaran Baru',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            centerTitle: false,
          ),

          body: ListView(
              padding: const EdgeInsets.fromLTRB(
                17,
                15,
                17,
                25,
              ),
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: darkGreen,
                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.work_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing
                                ? 'Perbarui Tawaran'
                                : 'Tambah Pekerjaan',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Isi detail sesuai tawaranmu',
                            style: TextStyle(
                              color: muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // INFORMASI PEKERJAAN
                _section(
                  title: 'Informasi pekerjaan',
                  icon: Icons.business_center_rounded,
                  expanded: true,
                  children: [
                    _textInput(
                      'Nama posisi',
                      'title',
                      hint: 'Contoh: Backend Developer',
                    ),

                    _textInput(
                      'Perusahaan',
                      'company',
                      hint: 'Nama perusahaan',
                    ),

                    _textInput(
                      'Lokasi',
                      'location',
                      hint: 'Contoh: Jakarta Timur',
                    ),
                  ],
                ),

                // PENGHASILAN
                _section(
                  title: 'Penghasilan',
                  icon: Icons.payments_rounded,
                  expanded: true,
                  children: [
                    _salaryModeSelector(),

                    _moneyInput(
                      _salaryMode == JobSalaryMode.monthly
                          ? 'Gaji pokok / bulan'
                          : 'Tarif ${_salaryMode.label.toLowerCase()}',
                      'salaryRate',
                    ),

                    if (_salaryMode != JobSalaryMode.monthly)
                      _numberInput(
                        'Jumlah dibayar / bulan',
                        'paidUnits',
                      ),

                    _pair(
                      _moneyInput(
                        'Tunjangan',
                        'allowances',
                      ),
                      _moneyInput(
                        'Bonus',
                        'bonuses',
                      ),
                    ),

                    _pair(
                      _moneyInput(
                        'Lembur',
                        'overtime',
                      ),
                      _moneyInput(
                        'Penghasilan lain',
                        'otherIncome',
                      ),
                    ),

                    _moneyInput(
                      'Potongan gaji',
                      'deductions',
                    ),
                  ],
                ),

                // JADWAL KERJA
                _section(
                  title: 'Jadwal kerja',
                  icon: Icons.calendar_month_rounded,
                  children: [
                    _pair(
                      _numberInput(
                        'Hari kerja / bulan',
                        'workDays',
                        suffix: 'hari',
                      ),
                      _numberInput(
                        'Hari ke kantor / bulan',
                        'officeDays',
                        suffix: 'hari',
                      ),
                    ),

                    _pair(
                      _numberInput(
                        'Hari kerja / minggu',
                        'daysPerWeek',
                        suffix: 'hari',
                      ),
                      _numberInput(
                        'Jam kerja / hari',
                        'hoursPerDay',
                        suffix: 'jam',
                      ),
                    ),
                  ],
                ),

                // TRANSPORTASI
                _section(
                  title: 'Transportasi',
                  icon: Icons.directions_transit_rounded,
                  children: [
                    _pair(
                      _moneyInput(
                        'Ongkos berangkat',
                        'goCost',
                      ),
                      _moneyInput(
                        'Ongkos pulang',
                        'returnCost',
                      ),
                    ),

                    _pair(
                      _numberInput(
                        'Waktu berangkat',
                        'goMinutes',
                        suffix: 'menit',
                      ),
                      _numberInput(
                        'Waktu pulang',
                        'returnMinutes',
                        suffix: 'menit',
                      ),
                    ),

                    _pair(
                      _numberInput(
                        'Jarak berangkat',
                        'goDistance',
                        suffix: 'km',
                      ),
                      _numberInput(
                        'Jarak pulang',
                        'returnDistance',
                        suffix: 'km',
                      ),
                    ),
                  ],
                ),

                // BIAYA TAMBAHAN
                _section(
                  title: 'Biaya tambahan',
                  icon: Icons.receipt_long_rounded,
                  children: [
                    _moneyInput(
                      'Tambahan makan / hari ke kantor',
                      'extraMealCost',
                    ),

                    _moneyInput(
                      'Biaya lainnya / bulan',
                      'otherWorkCosts',
                    ),
                  ],
                ),

                // PREFERENSI PRIBADI
                _section(
                  title: 'Preferensi pribadi',
                  icon: Icons.favorite_outline_rounded,
                  children: [
                    _moneyInput(
                      'Target uang tersisa / bulan',
                      'targetRemaining',
                    ),

                    _numberInput(
                      'Batas nyaman perjalanan PP',
                      'comfortableCommute',
                      suffix: 'menit',
                    ),

                    _ratingSlider(
                      title: 'Prospek karier',
                      value: _careerRating,
                      onChanged: (value) {
                        setState(() {
                          _careerRating = value;
                        });
                      },
                    ),

                    _ratingSlider(
                      title: 'Kenyamanan kerja',
                      value: _environmentRating,
                      onChanged: (value) {
                        setState(() {
                          _environmentRating = value;
                        });
                      },
                    ),
                  ],
                ),

                // CATATAN
                _section(
                  title: 'Catatan tambahan',
                  icon: Icons.notes_rounded,
                  children: [
                    _textInput(
                      'Catatan',
                      'notes',
                      maxLines: 4,
                      hint:
                          'Kontrak, benefit, WFH, dan lainnya...',
                    ),
                  ],
                ),

                const SizedBox(height: 9),

                // LIVE PREVIEW
                _buildPreview(),

                const SizedBox(height: 15),

                const Text(
                  'Hasil merupakan simulasi. '
                  'Pastikan nominal gaji, potongan, '
                  'dan benefit sesuai tawaran sebenarnya.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 16),
              ],
          ),

          // TOMBOL SIMPAN
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(
              17,
              8,
              17,
              16,
            ),
            child: FilledButton.icon(
              onPressed: saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: darkGreen,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.check_circle_outline_rounded,
                    ),
              label: Text(
                saving
                    ? 'Menyimpan...'
                    : _isEditing
                        ? 'Simpan Perubahan'
                        : 'Simpan Tawaran',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}



