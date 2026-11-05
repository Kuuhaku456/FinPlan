import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../models/finance_plan.dart';

// =====================================================
// WARNA FINPLAN
// =====================================================

const Color _darkGreen = Color(0xFF064E3B);
const Color _green = Color(0xFF059669);
const Color _mint = Color(0xFFD1FAE5);
const Color _orange = Color(0xFFF59E0B);
const Color _blue = Color(0xFF3B82F6);
const Color _purple = Color(0xFF8B5CF6);

// =====================================================
// DRAFT DATA
// =====================================================

class _IncomeDraft {
  _IncomeDraft({
    required this.id,
    required this.name,
    required this.amount,
    required this.frequency,
  });

  final String id;
  String name;
  int amount;
  BudgetFrequency frequency;
}

class _ExpenseDraft {
  _ExpenseDraft({
    required this.id,
    required this.name,
    required this.amount,
    required this.frequency,
  });

  final String id;
  String name;
  int amount;
  BudgetFrequency frequency;
}

class _LegDraft {
  _LegDraft({
    required this.id,
    required this.mode,
    required this.cost,
    this.note = '',
  });

  final String id;
  String mode;
  int cost;
  String note;
}

class _TravelDraft {
  _TravelDraft({
    List<_LegDraft>? outbound,
    List<_LegDraft>? inbound,
  })  : outbound = outbound ?? [],
        inbound = inbound ?? [];

  final List<_LegDraft> outbound;
  final List<_LegDraft> inbound;
}

// =====================================================
// PLAN EDITOR
// =====================================================

class PlanEditor extends StatefulWidget {
  const PlanEditor({
    super.key,
    required this.initial,
    required this.onSave,
    this.onboarding = false,
  });

  final FinancePlan initial;
  final Future<void> Function(FinancePlan) onSave;
  final bool onboarding;

  @override
  State<PlanEditor> createState() {
    return _PlanEditorState();
  }
}

class _PlanEditorState extends State<PlanEditor> {
  static const _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const _shortDays = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

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

  static const _stepTitles = [
    'Profil & Pemasukan',
    'Anggaran Makan',
    'Transportasi',
    'Kebutuhan',
    'Tabungan',
    'Ringkasan',
  ];

  static const _stepIcons = [
    Icons.account_balance_wallet_outlined,
    Icons.restaurant_outlined,
    Icons.directions_transit_outlined,
    Icons.shopping_bag_outlined,
    Icons.savings_outlined,
    Icons.pie_chart_outline_rounded,
  ];

  final ScrollController _scrollController =
      ScrollController();

  int _step = 0;
  int _selectedDay = 1;
  int _idCounter = 0;

  bool _saving = false;

  late String _name;
  late int _salary;
  late int _housing;
  late int _bills;
  late int _personal;
  late int _savings;
  late int _bufferPercent;

  late int _foodFallback;
  late int _transportFallback;

  late List<_IncomeDraft> _incomes;
  late List<_ExpenseDraft> _expenses;

  late Map<int, int> _foodByDay;
  late Map<int, _TravelDraft> _travelDays;

  String _newId() {
    return 'draft_${_idCounter++}';
  }

  // ===================================================
  // INITIAL STATE
  // ===================================================

  @override
  void initState() {
    super.initState();

    final plan = widget.initial;

    _name = plan.name;
    _salary = plan.actualIncome;

    _housing = plan.housing;
    _bills = plan.bills;
    _personal = plan.personal;

    _savings = plan.savings;
    _bufferPercent = plan.bufferPercent;

    _foodFallback = plan.foodByWeekday.isEmpty
        ? plan.food
        : 0;

    _transportFallback =
        widget.onboarding ||
                plan.transportByWeekday.isNotEmpty
            ? 0
            : plan.transport;

    _incomes = [
      for (final income in plan.additionalIncomes)
        _IncomeDraft(
          id: _newId(),
          name: income.name,
          amount: income.amount,
          frequency: income.frequency,
        ),
    ];

    _expenses = [
      for (final expense in plan.customExpenses)
        _ExpenseDraft(
          id: _newId(),
          name: expense.name,
          amount: expense.amount,
          frequency: expense.frequency,
        ),
    ];

    _foodByDay = Map<int, int>.from(
      plan.foodByWeekday,
    );

    // Estimasi awal makanan untuk onboarding.
    if (_foodByDay.isEmpty && widget.onboarding) {
      final estimate =
          (plan.food * 12) ~/ (52 * 7);

      for (var day = 1; day <= 7; day++) {
        _foodByDay[day] = estimate;
      }
    }

    _travelDays = {
      for (var day = 1; day <= 7; day++)
        day: _TravelDraft(),
    };

    for (final day in plan.transportByWeekday) {
      if (day.weekday < 1 || day.weekday > 7) {
        continue;
      }

      _travelDays[day.weekday] = _TravelDraft(
        outbound: [
          for (final leg in day.outbound)
            _LegDraft(
              id: _newId(),
              mode: leg.mode,
              cost: leg.cost,
              note: leg.note,
            ),
        ],
        inbound: [
          for (final leg in day.returnTrip)
            _LegDraft(
              id: _newId(),
              mode: leg.mode,
              cost: leg.cost,
              note: leg.note,
            ),
        ],
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ===================================================
  // MEMBUAT FINANCE PLAN
  // ===================================================

  FinancePlan _currentPlan() {
    final routes = <DailyTransport>[];

    for (var day = 1; day <= 7; day++) {
      final route = _travelDays[day]!;

      if (route.outbound.isEmpty &&
          route.inbound.isEmpty) {
        continue;
      }

      routes.add(
        DailyTransport(
          weekday: day,
          outbound: [
            for (final leg in route.outbound)
              TransportLeg(
                mode: leg.mode,
                cost: leg.cost,
                note: leg.note,
              ),
          ],
          returnTrip: [
            for (final leg in route.inbound)
              TransportLeg(
                mode: leg.mode,
                cost: leg.cost,
                note: leg.note,
              ),
          ],
        ),
      );
    }

    return FinancePlan(
      name: _name.trim(),
      actualIncome: _salary,
      housing: _housing,
      food: _foodFallback,
      transport: _transportFallback,
      bills: _bills,
      personal: _personal,
      savings: _savings,
      bufferPercent: _bufferPercent,

      additionalIncomes: [
        for (final income in _incomes)
          IncomeSource(
            id: income.id,
            name: income.name.trim(),
            amount: income.amount,
            frequency: income.frequency,
          ),
      ],

      foodByWeekday: Map<int, int>.from(
        _foodByDay,
      ),

      transportByWeekday: routes,

      customExpenses: [
        for (final expense in _expenses)
          CustomExpense(
            id: expense.id,
            name: expense.name.trim(),
            amount: expense.amount,
            frequency: expense.frequency,
          ),
      ],
    );
  }

  // ===================================================
  // VALIDASI
  // ===================================================

  String? _validationError() {
    if (_step == 0) {
      if (_name.trim().isEmpty) {
        return 'Nama panggilan wajib diisi.';
      }

      for (final income in _incomes) {
        if (income.name.trim().isEmpty) {
          return 'Nama pemasukan tambahan wajib diisi.';
        }
      }
    }

    if (_step == 2) {
      for (final route in _travelDays.values) {
        for (final leg in [
          ...route.outbound,
          ...route.inbound,
        ]) {
          if (leg.mode.trim().isEmpty) {
            return 'Nama moda transportasi wajib diisi.';
          }
        }
      }
    }

    if (_step == 3) {
      for (final expense in _expenses) {
        if (expense.name.trim().isEmpty) {
          return 'Nama kebutuhan tambahan wajib diisi.';
        }
      }
    }

    if (_step == 5) {
      if (_currentPlan().minimumIncome <= 0) {
        return 'Isi setidaknya satu kebutuhan '
            'atau target tabungan.';
      }
    }

    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===================================================
  // NAVIGASI TAHAP
  // ===================================================

  void _changeStep(int nextStep) {
    if (nextStep < 0 || nextStep > 5) return;

    setState(() {
      _step = nextStep;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _next() async {
    if (_saving) return;

    final error = _validationError();

    if (error != null) {
      _showMessage(error);
      return;
    }

    if (_step < 5) {
      _changeStep(_step + 1);
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.onSave(_currentPlan());

      if (!mounted) return;

      if (!widget.onboarding) {
        _showMessage(
          'Rencana keuangan berhasil disimpan.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Gagal menyimpan rencana. Coba lagi.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ===================================================
  // KOMPONEN KARTU
  // ===================================================

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: scheme.primary,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          ...children,
        ],
      ),
    );
  }

  // ===================================================
  // INPUT NOMINAL
  // ===================================================

  Widget _moneyInput({
    required String fieldKey,
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
      key: ValueKey(fieldKey),
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
      ),
      onChanged: (text) {
        setState(() {
          onChanged(parseRupiah(text));
        });
      },
    );
  }

  // ===================================================
  // FREKUENSI
  // ===================================================

  Widget _frequencyInput({
    required BudgetFrequency value,
    required ValueChanged<BudgetFrequency> onChanged,
  }) {
    return DropdownButtonFormField<BudgetFrequency>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Frekuensi',
      ),
      items: const [
        DropdownMenuItem(
          value: BudgetFrequency.weekly,
          child: Text('Mingguan'),
        ),
        DropdownMenuItem(
          value: BudgetFrequency.monthly,
          child: Text('Bulanan'),
        ),
        DropdownMenuItem(
          value: BudgetFrequency.yearly,
          child: Text('Tahunan'),
        ),
      ],
      onChanged: (selected) {
        if (selected == null) return;

        setState(() {
          onChanged(selected);
        });
      },
    );
  }

  // ===================================================
  // KARTU METRIK
  // ===================================================

  Widget _metric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(
              alpha: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),

            const SizedBox(height: 10),

            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 5),

            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================
  // LANGKAH 1 - PEMASUKAN
  // ===================================================

  Widget _incomeStep() {
    final plan = _currentPlan();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: 'Penghasilan Utama',
          icon: Icons.account_balance_wallet_outlined,
          children: [
            TextFormField(
              key: const ValueKey('profile_name'),
              initialValue: _name,
              maxLength: 40,
              textCapitalization:
                  TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Panggilan',
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                ),
              ),
              onChanged: (value) {
                _name = value;
              },
            ),

            const SizedBox(height: 12),

            _moneyInput(
              fieldKey: 'main_salary',
              label: 'Gaji Bersih Bulanan',
              value: _salary,
              onChanged: (value) {
                _salary = value;
              },
            ),
          ],
        ),

        const SizedBox(height: 17),

        _sectionCard(
          title: 'Pemasukan Tambahan',
          icon: Icons.add_chart_rounded,
          children: [
            for (final income in _incomes)
              Container(
                key: ValueKey(
                  'income_card_${income.id}',
                ),
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sumber Pemasukan',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        IconButton(
                          tooltip: 'Hapus pemasukan',
                          onPressed: () {
                            setState(() {
                              _incomes.remove(income);
                            });
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                          ),
                        ),
                      ],
                    ),

                    TextFormField(
                      key: ValueKey(
                        'income_name_${income.id}',
                      ),
                      initialValue: income.name,
                      decoration: const InputDecoration(
                        labelText: 'Nama',
                        hintText: 'Freelance / Usaha',
                      ),
                      onChanged: (value) {
                        income.name = value;
                      },
                    ),

                    const SizedBox(height: 12),

                    _moneyInput(
                      fieldKey:
                          'income_amount_${income.id}',
                      label: 'Nominal',
                      value: income.amount,
                      onChanged: (value) {
                        income.amount = value;
                      },
                    ),

                    const SizedBox(height: 12),

                    _frequencyInput(
                      value: income.frequency,
                      onChanged: (value) {
                        income.frequency = value;
                      },
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _incomes.add(
                      _IncomeDraft(
                        id: _newId(),
                        name: '',
                        amount: 0,
                        frequency:
                            BudgetFrequency.monthly,
                      ),
                    );
                  });
                },
                icon: const Icon(
                  Icons.add_rounded,
                ),
                label: const Text('Tambah Pemasukan'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 17),

        Row(
          children: [
            _metric(
              label: 'Total Pemasukan',
              value: rupiah(plan.totalMonthlyIncome),
              icon: Icons.trending_up_rounded,
              color: _green,
            ),
          ],
        ),
      ],
    );
  }

  // ===================================================
  // LANGKAH 2 - MAKAN
  // ===================================================

  Widget _foodStep() {
    final plan = _currentPlan();

    return Column(
      children: [
        _sectionCard(
          title: 'Biaya Makan Harian',
          icon: Icons.restaurant_rounded,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final monday = _foodByDay[1] ?? 0;

                      setState(() {
                        for (var day = 1;
                            day <= 5;
                            day++) {
                          _foodByDay[day] = monday;
                        }

                        _foodFallback = 0;
                      });
                    },
                    child: const Text(
                      'Samakan Sen–Jum',
                      maxLines: 1,
                    ),
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final monday = _foodByDay[1] ?? 0;

                      setState(() {
                        for (var day = 1;
                            day <= 7;
                            day++) {
                          _foodByDay[day] = monday;
                        }

                        _foodFallback = 0;
                      });
                    },
                    child: const Text(
                      'Samakan Semua',
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            for (var day = 1; day <= 7; day++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _moneyInput(
                  fieldKey: 'food_day_$day',
                  label: _days[day - 1],
                  value: _foodByDay[day] ?? 0,
                  onChanged: (value) {
                    _foodByDay[day] = value;
                    _foodFallback = 0;
                  },
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            _metric(
              label: 'Per Minggu',
              value: rupiah(plan.weeklyFoodTotal),
              icon: Icons.calendar_view_week_outlined,
              color: _orange,
            ),

            const SizedBox(width: 10),

            _metric(
              label: 'Per Bulan',
              value: rupiah(plan.food),
              icon: Icons.calendar_month_outlined,
              color: _green,
            ),
          ],
        ),
      ],
    );
  }

  // ===================================================
  // KARTU TRANSPORTASI PER ARAH
  // ===================================================

  Widget _transportDirection({
    required String title,
    required List<_LegDraft> legs,
    required String direction,
    required IconData icon,
  }) {
    return _sectionCard(
      title: title,
      icon: icon,
      children: [
        for (final leg in legs)
          Container(
            key: ValueKey('leg_${leg.id}'),
            margin: const EdgeInsets.only(bottom: 13),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _transportModes.contains(
                          leg.mode,
                        )
                                ? leg.mode
                                : 'Lainnya',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Transportasi',
                        ),
                        items: [
                          for (final mode in _transportModes)
                            DropdownMenuItem(
                              value: mode,
                              child: Text(mode),
                            ),
                        ],
                        onChanged: (selected) {
                          if (selected == null) return;

                          setState(() {
                            leg.mode =
                                selected == 'Lainnya'
                                    ? ''
                                    : selected;

                            _transportFallback = 0;
                          });
                        },
                      ),
                    ),

                    IconButton(
                      tooltip: 'Hapus moda',
                      onPressed: () {
                        setState(() {
                          legs.remove(leg);
                          _transportFallback = 0;
                        });
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                      ),
                    ),
                  ],
                ),

                if (!_transportModes.contains(
                  leg.mode,
                )) ...[
                  const SizedBox(height: 11),

                  TextFormField(
                    key: ValueKey(
                      'custom_mode_${leg.id}',
                    ),
                    initialValue: leg.mode,
                    decoration: const InputDecoration(
                      labelText: 'Nama Transportasi',
                      hintText: 'Shuttle / Bus Kantor',
                    ),
                    onChanged: (value) {
                      leg.mode = value;
                    },
                  ),
                ],

                const SizedBox(height: 11),

                _moneyInput(
                  fieldKey: 'leg_cost_${leg.id}',
                  label: 'Biaya Perjalanan',
                  value: leg.cost,
                  onChanged: (value) {
                    leg.cost = value;
                    _transportFallback = 0;
                  },
                ),

                const SizedBox(height: 10),

                TextFormField(
                  key: ValueKey('leg_note_${leg.id}'),
                  initialValue: leg.note,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (Opsional)',
                  ),
                  onChanged: (value) {
                    leg.note = value;
                  },
                ),
              ],
            ),
          ),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                legs.add(
                  _LegDraft(
                    id: _newId(),
                    mode: 'KRL',
                    cost: 0,
                  ),
                );

                _transportFallback = 0;
              });
            },
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: Text('Tambah Moda $direction'),
          ),
        ),
      ],
    );
  }

  // ===================================================
  // LANGKAH 3 - TRANSPORTASI
  // ===================================================

  Widget _transportStep() {
    final route = _travelDays[_selectedDay]!;

    final dailyTotal = [
      ...route.outbound,
      ...route.inbound,
    ].fold<int>(
      0,
      (sum, leg) => sum + leg.cost,
    );

    final plan = _currentPlan();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PILIH HARI

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var day = 1; day <= 7; day++)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(_shortDays[day - 1]),
                    selected: _selectedDay == day,
                    showCheckmark: false,
                    selectedColor: _mint,
                    onSelected: (_) {
                      setState(() {
                        _selectedDay = day;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 17),

        _transportDirection(
          title: 'Perjalanan Pergi',
          icon: Icons.arrow_forward_rounded,
          legs: route.outbound,
          direction: 'Pergi',
        ),

        const SizedBox(height: 14),

        _transportDirection(
          title: 'Perjalanan Pulang',
          icon: Icons.arrow_back_rounded,
          legs: route.inbound,
          direction: 'Pulang',
        ),

        const SizedBox(height: 17),

        Row(
          children: [
            _metric(
              label: 'Hari Ini',
              value: rupiah(dailyTotal),
              icon: Icons.directions_transit_rounded,
              color: _blue,
            ),

            const SizedBox(width: 10),

            _metric(
              label: 'Per Bulan',
              value: rupiah(plan.transport),
              icon: Icons.calendar_month_outlined,
              color: _purple,
            ),
          ],
        ),
      ],
    );
  }

  // ===================================================
  // LANGKAH 4 - KEBUTUHAN
  // ===================================================

  Widget _needsStep() {
    final plan = _currentPlan();

    return Column(
      children: [
        _sectionCard(
          title: 'Kebutuhan Bulanan',
          icon: Icons.shopping_bag_outlined,
          children: [
            _moneyInput(
              fieldKey: 'housing',
              label: 'Tempat Tinggal',
              value: _housing,
              onChanged: (value) {
                _housing = value;
              },
            ),

            const SizedBox(height: 12),

            _moneyInput(
              fieldKey: 'bills',
              label: 'Tagihan',
              value: _bills,
              onChanged: (value) {
                _bills = value;
              },
            ),

            const SizedBox(height: 12),

            _moneyInput(
              fieldKey: 'personal',
              label: 'Kebutuhan Pribadi',
              value: _personal,
              onChanged: (value) {
                _personal = value;
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        _sectionCard(
          title: 'Kebutuhan Tambahan',
          icon: Icons.category_outlined,
          children: [
            for (final expense in _expenses)
              Container(
                key: ValueKey(
                  'expense_${expense.id}',
                ),
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Kebutuhan Custom',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        IconButton(
                          tooltip: 'Hapus kebutuhan',
                          onPressed: () {
                            setState(() {
                              _expenses.remove(expense);
                            });
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                          ),
                        ),
                      ],
                    ),

                    TextFormField(
                      key: ValueKey(
                        'expense_name_${expense.id}',
                      ),
                      initialValue: expense.name,
                      decoration: const InputDecoration(
                        labelText: 'Nama Kebutuhan',
                        hintText: 'Perpuluhan / Pendidikan',
                      ),
                      onChanged: (value) {
                        expense.name = value;
                      },
                    ),

                    const SizedBox(height: 11),

                    _moneyInput(
                      fieldKey:
                          'expense_amount_${expense.id}',
                      label: 'Nominal',
                      value: expense.amount,
                      onChanged: (value) {
                        expense.amount = value;
                      },
                    ),

                    const SizedBox(height: 11),

                    _frequencyInput(
                      value: expense.frequency,
                      onChanged: (value) {
                        expense.frequency = value;
                      },
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _expenses.add(
                      _ExpenseDraft(
                        id: _newId(),
                        name: '',
                        amount: 0,
                        frequency:
                            BudgetFrequency.monthly,
                      ),
                    );
                  });
                },
                icon: const Icon(
                  Icons.add_rounded,
                ),
                label: const Text('Tambah Kebutuhan'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            _metric(
              label: 'Total Kebutuhan',
              value: rupiah(plan.expenses),
              icon: Icons.receipt_long_outlined,
              color: _orange,
            ),
          ],
        ),
      ],
    );
  }

  // ===================================================
  // LANGKAH 5 - TABUNGAN
  // ===================================================

  Widget _savingsStep() {
    final plan = _currentPlan();

    return Column(
      children: [
        _sectionCard(
          title: 'Target Tabungan',
          icon: Icons.savings_outlined,
          children: [
            _moneyInput(
              fieldKey: 'savings',
              label: 'Tabungan Bulanan',
              value: _savings,
              onChanged: (value) {
                _savings = value;
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        _sectionCard(
          title: 'Dana Cadangan',
          icon: Icons.shield_outlined,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_bufferPercent%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Slider(
              value: _bufferPercent.toDouble(),
              min: 0,
              max: 30,
              divisions: 30,
              label: '$_bufferPercent%',
              onChanged: (value) {
                setState(() {
                  _bufferPercent = value.round();
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            _metric(
              label: 'Tabungan',
              value: rupiah(plan.savings),
              icon: Icons.savings_rounded,
              color: _green,
            ),

            const SizedBox(width: 10),

            _metric(
              label: 'Cadangan',
              value: rupiah(plan.buffer),
              icon: Icons.shield_outlined,
              color: _blue,
            ),
          ],
        ),
      ],
    );
  }

  // ===================================================
  // BARIS RINGKASAN
  // ===================================================

  Widget _summaryRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
          ),

          const SizedBox(width: 12),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // LANGKAH 6 - RINGKASAN
  // ===================================================

  Widget _summaryStep() {
    final plan = _currentPlan();
    final scheme = Theme.of(context).colorScheme;

    final income = plan.totalMonthlyIncome;
    final budget = plan.idealIncome;

    final utilization = income <= 0
        ? 0.0
        : (budget / income)
            .clamp(0.0, 1.0)
            .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KARTU RINGKASAN

        Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                _darkGreen,
                _green,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, ${plan.name}! 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Rekomendasi Penghasilan',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 6),

              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  rupiah(budget),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: utilization,
                  minHeight: 9,
                  backgroundColor: Colors.white24,
                  color: _mint,
                ),
              ),

              const SizedBox(height: 11),

              Text(
                plan.canFundPlan
                    ? '✅ Anggaran sesuai penghasilan'
                    : '⚠️ Anggaran perlu disesuaikan',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            _metric(
              label: 'Pemasukan',
              value: rupiah(income),
              icon: Icons.trending_up_rounded,
              color: _green,
            ),

            const SizedBox(width: 10),

            _metric(
              label: 'Selisih',
              value: rupiah(plan.plannedDifference),
              icon: Icons.balance_rounded,
              color: plan.canFundPlan
                  ? _green
                  : scheme.error,
            ),
          ],
        ),

        const SizedBox(height: 16),

        _sectionCard(
          title: 'Alokasi Bulanan',
          icon: Icons.pie_chart_outline_rounded,
          children: [
            _summaryRow(
              'Tempat Tinggal',
              rupiah(plan.housing),
            ),

            _summaryRow(
              'Makan',
              rupiah(plan.food),
            ),

            _summaryRow(
              'Transportasi',
              rupiah(plan.transport),
            ),

            _summaryRow(
              'Tagihan',
              rupiah(plan.bills),
            ),

            _summaryRow(
              'Pribadi',
              rupiah(plan.personal),
            ),

            _summaryRow(
              'Kebutuhan Custom',
              rupiah(plan.monthlyCustomExpenses),
            ),

            const Divider(),

            _summaryRow(
              'Total Kebutuhan',
              rupiah(plan.expenses),
            ),

            _summaryRow(
              'Tabungan',
              rupiah(plan.savings),
            ),

            _summaryRow(
              'Dana Cadangan',
              rupiah(plan.buffer),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: plan.canFundPlan
                ? scheme.primaryContainer
                : scheme.errorContainer,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              Icon(
                plan.canFundPlan
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: plan.canFundPlan
                    ? scheme.onPrimaryContainer
                    : scheme.onErrorContainer,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  plan.canFundPlan
                      ? 'Rencana siap digunakan.'
                      : 'Rencana tetap bisa disimpan '
                          'dan disesuaikan nanti.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: plan.canFundPlan
                        ? scheme.onPrimaryContainer
                        : scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===================================================
  // KONTEN PER LANGKAH
  // ===================================================

  Widget _stepContent() {
    switch (_step) {
      case 0:
        return _incomeStep();

      case 1:
        return _foodStep();

      case 2:
        return _transportStep();

      case 3:
        return _needsStep();

      case 4:
        return _savingsStep();

      case 5:
        return _summaryStep();

      default:
        return const SizedBox.shrink();
    }
  }

  // ===================================================
  // STEP HEADER
  // ===================================================

  Widget _stepHeader() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        14,
        18,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _stepIcons[_step],
                  color: scheme.onPrimaryContainer,
                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Langkah ${_step + 1} dari 6',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _stepTitles[_step],
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // INDIKATOR PROGRESS 6 TAHAP

          Row(
            children: List.generate(6, (index) {
              final active = index <= _step;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == 5 ? 0 : 5,
                  ),
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: active
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // TOMBOL NAVIGASI
  // ===================================================

  Widget _bottomNavigation() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        18,
        11,
        18,
        15,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _changeStep(_step - 1),
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(51),
                  ),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                  ),
                  label: const Text('Kembali'),
                ),
              ),

              const SizedBox(width: 11),
            ],

            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saving ? null : _next,
                style: FilledButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(51),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _step == 5
                            ? Icons.check_circle_outline_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(
                  _saving
                      ? 'Menyimpan...'
                      : _step == 5
                          ? 'Simpan Rencana'
                          : 'Selanjutnya',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================
  // BUILD
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _stepHeader(),

        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              25,
            ),
            children: [
              _stepContent(),
            ],
          ),
        ),

        _bottomNavigation(),
      ],
    );
  }
}