import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/finance_plan.dart';

// =====================================================
// ENUM
// =====================================================

enum TravelDirection {
  outbound,
  inbound,
}

// =====================================================
// KONFIGURASI EDITOR
// =====================================================

/// Konfigurasi untuk setiap sesi PlanEditor.
///
/// Provider ini nantinya di-override melalui ProviderScope
/// lokal agar state onboarding dan edit plan tidak bercampur.
class PlanEditorConfig {
  const PlanEditorConfig({
    required this.initial,
    required this.onboarding,
  });

  final FinancePlan initial;
  final bool onboarding;
}

final planEditorConfigProvider = Provider<PlanEditorConfig>(
  (ref) {
    throw StateError(
      'PlanEditorConfig belum diberikan oleh ProviderScope.',
    );
  },
  dependencies: const [],
);

// =====================================================
// MODEL DRAFT TRANSPORTASI
// =====================================================

class EditorTransportLeg {
  const EditorTransportLeg({
    required this.id,
    required this.mode,
    required this.cost,
    this.note = '',
  });

  final String id;
  final String mode;
  final int cost;
  final String note;

  EditorTransportLeg copyWith({
    String? mode,
    int? cost,
    String? note,
  }) {
    return EditorTransportLeg(
      id: id,
      mode: mode ?? this.mode,
      cost: cost ?? this.cost,
      note: note ?? this.note,
    );
  }
}

class EditorDayRoute {
  EditorDayRoute({
    List<EditorTransportLeg> outbound = const [],
    List<EditorTransportLeg> inbound = const [],
  })  : outbound = List.unmodifiable(outbound),
        inbound = List.unmodifiable(inbound);

  final List<EditorTransportLeg> outbound;
  final List<EditorTransportLeg> inbound;

  EditorDayRoute copyWith({
    List<EditorTransportLeg>? outbound,
    List<EditorTransportLeg>? inbound,
  }) {
    return EditorDayRoute(
      outbound: outbound ?? this.outbound,
      inbound: inbound ?? this.inbound,
    );
  }
}

// =====================================================
// STATE PLAN EDITOR
// =====================================================

/// Seluruh data formulir disimpan secara immutable.
///
/// Jangan mengubah isi List atau Map secara langsung.
/// Semua perubahan dilakukan melalui PlanEditorNotifier.
class PlanEditorDraftState {
  PlanEditorDraftState({
    required this.step,
    required this.selectedDay,
    required this.nextDraftId,
    required this.isSaving,
    required this.name,
    required this.salary,
    required this.housing,
    required this.bills,
    required this.personal,
    required this.savings,
    required this.bufferPercent,
    required this.foodFallback,
    required this.transportFallback,
    required List<IncomeSource> additionalIncomes,
    required List<CustomExpense> customExpenses,
    required Map<int, int> foodByDay,
    required Map<int, EditorDayRoute> travelDays,
  })  : additionalIncomes =
            List.unmodifiable(additionalIncomes),
        customExpenses =
            List.unmodifiable(customExpenses),
        foodByDay = Map.unmodifiable(foodByDay),
        travelDays = Map.unmodifiable(travelDays);

  // ===================================================
  // STATE NAVIGASI
  // ===================================================

  final int step;
  final int selectedDay;
  final int nextDraftId;
  final bool isSaving;

  // ===================================================
  // STATE PROFIL DAN KEUANGAN
  // ===================================================

  final String name;
  final int salary;
  final int housing;
  final int bills;
  final int personal;
  final int savings;
  final int bufferPercent;

  // Nilai fallback untuk kompatibilitas data lama.
  final int foodFallback;
  final int transportFallback;

  // ===================================================
  // STATE DATA TAMBAHAN
  // ===================================================

  final List<IncomeSource> additionalIncomes;
  final List<CustomExpense> customExpenses;

  final Map<int, int> foodByDay;
  final Map<int, EditorDayRoute> travelDays;

  // ===================================================
  // INITIAL STATE
  // ===================================================

  static PlanEditorDraftState fromPlan(
    FinancePlan initial, {
    required bool onboarding,
  }) {
    var nextId = 0;

    String id() => 'draft_${nextId++}';

    // -----------------------------------------------
    // DATA MAKAN
    // -----------------------------------------------

    final foods = Map<int, int>.from(
      initial.foodByWeekday,
    );

    // Estimasi awal jika sedang onboarding.
    if (foods.isEmpty && onboarding) {
      final estimate =
          (initial.food * 12) ~/ (52 * 7);

      for (var day = 1; day <= 7; day++) {
        foods[day] = estimate;
      }
    }

    // -----------------------------------------------
    // DATA TRANSPORTASI
    // -----------------------------------------------

    final routes = <int, EditorDayRoute>{
      for (var day = 1; day <= 7; day++)
        day: EditorDayRoute(),
    };

    for (final route in initial.transportByWeekday) {
      if (route.weekday < 1 || route.weekday > 7) {
        continue;
      }

      routes[route.weekday] = EditorDayRoute(
        outbound: [
          for (final leg in route.outbound)
            EditorTransportLeg(
              id: id(),
              mode: leg.mode,
              cost: leg.cost,
              note: leg.note,
            ),
        ],
        inbound: [
          for (final leg in route.returnTrip)
            EditorTransportLeg(
              id: id(),
              mode: leg.mode,
              cost: leg.cost,
              note: leg.note,
            ),
        ],
      );
    }

    // -----------------------------------------------
    // MEMBUAT STATE AWAL
    // -----------------------------------------------

    return PlanEditorDraftState(
      step: 0,
      selectedDay: 1,
      nextDraftId: nextId +
          initial.additionalIncomes.length +
          initial.customExpenses.length,
      isSaving: false,

      // Profil
      name: initial.name,
      salary: initial.actualIncome,

      // Kebutuhan
      housing: initial.housing,
      bills: initial.bills,
      personal: initial.personal,

      // Tabungan
      savings: initial.savings,
      bufferPercent: initial.bufferPercent,

      // Kompatibilitas data lama
      foodFallback:
          initial.foodByWeekday.isEmpty
              ? initial.food
              : 0,

      transportFallback:
          onboarding ||
                  initial.transportByWeekday.isNotEmpty
              ? 0
              : initial.transport,

      // Pemasukan tambahan
      additionalIncomes: [
        for (
          var i = 0;
          i < initial.additionalIncomes.length;
          i++
        )
          IncomeSource(
            id: 'draft_${nextId + i}',
            name: initial.additionalIncomes[i].name,
            amount: initial.additionalIncomes[i].amount,
            frequency:
                initial.additionalIncomes[i].frequency,
          ),
      ],

      // Kebutuhan tambahan
      customExpenses: [
        for (
          var i = 0;
          i < initial.customExpenses.length;
          i++
        )
          CustomExpense(
            id: 'draft_${nextId + initial.additionalIncomes.length + i}',
            name: initial.customExpenses[i].name,
            amount: initial.customExpenses[i].amount,
            frequency:
                initial.customExpenses[i].frequency,
          ),
      ],

      foodByDay: foods,
      travelDays: routes,
    );
  }

  // ===================================================
  // COPY WITH
  // ===================================================

  PlanEditorDraftState copyWith({
    int? step,
    int? selectedDay,
    int? nextDraftId,
    bool? isSaving,
    String? name,
    int? salary,
    int? housing,
    int? bills,
    int? personal,
    int? savings,
    int? bufferPercent,
    int? foodFallback,
    int? transportFallback,
    List<IncomeSource>? additionalIncomes,
    List<CustomExpense>? customExpenses,
    Map<int, int>? foodByDay,
    Map<int, EditorDayRoute>? travelDays,
  }) {
    return PlanEditorDraftState(
      step: step ?? this.step,
      selectedDay: selectedDay ?? this.selectedDay,
      nextDraftId:
          nextDraftId ?? this.nextDraftId,
      isSaving: isSaving ?? this.isSaving,
      name: name ?? this.name,
      salary: salary ?? this.salary,
      housing: housing ?? this.housing,
      bills: bills ?? this.bills,
      personal: personal ?? this.personal,
      savings: savings ?? this.savings,
      bufferPercent:
          bufferPercent ?? this.bufferPercent,
      foodFallback:
          foodFallback ?? this.foodFallback,
      transportFallback:
          transportFallback ?? this.transportFallback,
      additionalIncomes:
          additionalIncomes ?? this.additionalIncomes,
      customExpenses:
          customExpenses ?? this.customExpenses,
      foodByDay: foodByDay ?? this.foodByDay,
      travelDays: travelDays ?? this.travelDays,
    );
  }

  // ===================================================
  // HELPER TRANSPORTASI
  // ===================================================

  EditorDayRoute routeFor(int day) {
    return travelDays[day] ?? EditorDayRoute();
  }

  int dailyTransportTotal(int day) {
    final route = routeFor(day);

    return [
      ...route.outbound,
      ...route.inbound,
    ].fold<int>(
      0,
      (sum, leg) => sum + leg.cost,
    );
  }

  // ===================================================
  // KONVERSI KE FINANCE PLAN
  // ===================================================

  FinancePlan toFinancePlan() {
    final routes = <DailyTransport>[];

    for (var day = 1; day <= 7; day++) {
      final route = routeFor(day);

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
      name: name.trim(),
      actualIncome: salary,
      housing: housing,
      food: foodFallback,
      transport: transportFallback,
      bills: bills,
      personal: personal,
      savings: savings,
      bufferPercent: bufferPercent,

      additionalIncomes: [
        for (final income in additionalIncomes)
          IncomeSource(
            id: income.id,
            name: income.name.trim(),
            amount: income.amount,
            frequency: income.frequency,
          ),
      ],

      foodByWeekday:
          Map<int, int>.from(foodByDay),

      transportByWeekday: routes,

      customExpenses: [
        for (final expense in customExpenses)
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

  String? validationError() {
    // Langkah 1: Profil dan pemasukan
    if (step == 0) {
      if (name.trim().isEmpty) {
        return 'Nama panggilan wajib diisi.';
      }

      if (additionalIncomes.any(
        (income) => income.name.trim().isEmpty,
      )) {
        return 'Nama pemasukan tambahan wajib diisi.';
      }
    }

    // Langkah 3: Transportasi
    if (step == 2) {
      for (final route in travelDays.values) {
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

    // Langkah 4: Kebutuhan
    if (step == 3) {
      if (customExpenses.any(
        (expense) => expense.name.trim().isEmpty,
      )) {
        return 'Nama kebutuhan tambahan wajib diisi.';
      }
    }

    // Langkah 6: Ringkasan
    if (step == 5) {
      if (toFinancePlan().minimumIncome <= 0) {
        return 'Isi setidaknya satu kebutuhan atau target tabungan.';
      }
    }

    return null;
  }
}

// =====================================================
// RIVERPOD PROVIDER
// =====================================================

final planEditorProvider =
    NotifierProvider<
        PlanEditorNotifier,
        PlanEditorDraftState>(
  PlanEditorNotifier.new,
  dependencies: [planEditorConfigProvider],
);

// =====================================================
// PLAN EDITOR NOTIFIER
// =====================================================

class PlanEditorNotifier
    extends Notifier<PlanEditorDraftState> {
  bool _disposed = false;

  // ===================================================
  // INITIAL BUILD
  // ===================================================

  @override
  PlanEditorDraftState build() {
    ref.onDispose(() {
      _disposed = true;
    });

    final config = ref.watch(
      planEditorConfigProvider,
    );

    return PlanEditorDraftState.fromPlan(
      config.initial,
      onboarding: config.onboarding,
    );
  }

  // ===================================================
  // UPDATE PROFIL
  // ===================================================

  void updateName(String value) {
    state = state.copyWith(name: value);
  }

  void updateSalary(int value) {
    state = state.copyWith(salary: value);
  }

  // ===================================================
  // UPDATE KEBUTUHAN
  // ===================================================

  void updateHousing(int value) {
    state = state.copyWith(housing: value);
  }

  void updateBills(int value) {
    state = state.copyWith(bills: value);
  }

  void updatePersonal(int value) {
    state = state.copyWith(personal: value);
  }

  // ===================================================
  // UPDATE TABUNGAN
  // ===================================================

  void updateSavings(int value) {
    state = state.copyWith(savings: value);
  }

  void updateBufferPercent(int value) {
    state = state.copyWith(
      bufferPercent: value.clamp(0, 30).toInt(),
    );
  }

  // ===================================================
  // GENERATE ID
  // ===================================================

  String _newId() {
    var n = state.nextDraftId;

    final usedIds = <String>{
      for (final income in state.additionalIncomes)
        income.id,
      for (final expense in state.customExpenses)
        expense.id,
      for (final route in state.travelDays.values)
        for (final leg in [
          ...route.outbound,
          ...route.inbound,
        ])
          leg.id,
    };

    while (usedIds.contains('draft_$n')) {
      n++;
    }

    final result = 'draft_$n';

    state = state.copyWith(
      nextDraftId: n + 1,
    );

    return result;
  }

  // ===================================================
  // PEMASUKAN TAMBAHAN
  // ===================================================

  void addIncome() {
    final id = _newId();

    state = state.copyWith(
      additionalIncomes: [
        ...state.additionalIncomes,
        IncomeSource(
          id: id,
          name: '',
          amount: 0,
        ),
      ],
    );
  }

  void removeIncome(String id) {
    state = state.copyWith(
      additionalIncomes: [
        for (final item in state.additionalIncomes)
          if (item.id != id) item,
      ],
    );
  }

  void updateIncome(
    String id, {
    String? name,
    int? amount,
    BudgetFrequency? frequency,
  }) {
    state = state.copyWith(
      additionalIncomes: [
        for (final item in state.additionalIncomes)
          if (item.id == id)
            IncomeSource(
              id: item.id,
              name: name ?? item.name,
              amount: amount ?? item.amount,
              frequency:
                  frequency ?? item.frequency,
            )
          else
            item,
      ],
    );
  }

  // ===================================================
  // KEBUTUHAN TAMBAHAN
  // ===================================================

  void addExpense() {
    final id = _newId();

    state = state.copyWith(
      customExpenses: [
        ...state.customExpenses,
        CustomExpense(
          id: id,
          name: '',
          amount: 0,
        ),
      ],
    );
  }

  void removeExpense(String id) {
    state = state.copyWith(
      customExpenses: [
        for (final item in state.customExpenses)
          if (item.id != id) item,
      ],
    );
  }

  void updateExpense(
    String id, {
    String? name,
    int? amount,
    BudgetFrequency? frequency,
  }) {
    state = state.copyWith(
      customExpenses: [
        for (final item in state.customExpenses)
          if (item.id == id)
            CustomExpense(
              id: item.id,
              name: name ?? item.name,
              amount: amount ?? item.amount,
              frequency:
                  frequency ?? item.frequency,
            )
          else
            item,
      ],
    );
  }

  // ===================================================
  // ANGGARAN MAKAN
  // ===================================================

  void updateFoodDay(
    int day,
    int amount,
  ) {
    if (day < 1 || day > 7) return;

    state = state.copyWith(
      foodByDay: {
        ...state.foodByDay,
        day: amount,
      },
      foodFallback: 0,
    );
  }

  /// Salin anggaran Senin ke hari lainnya.
  ///
  /// allDays = false -> Senin sampai Jumat
  /// allDays = true  -> Senin sampai Minggu
  void copyMondayFood({
    required bool allDays,
  }) {
    final monday =
        state.foodByDay[1] ?? 0;

    final foods = Map<int, int>.from(
      state.foodByDay,
    );

    for (
      var day = 1;
      day <= (allDays ? 7 : 5);
      day++
    ) {
      foods[day] = monday;
    }

    state = state.copyWith(
      foodByDay: foods,
      foodFallback: 0,
    );
  }

  // ===================================================
  // TRANSPORTASI
  // ===================================================

  void selectDay(int day) {
    if (day < 1 || day > 7) return;

    state = state.copyWith(
      selectedDay: day,
    );
  }

  void _setRoute(
    int day,
    EditorDayRoute route,
  ) {
    state = state.copyWith(
      travelDays: {
        ...state.travelDays,
        day: route,
      },
      transportFallback: 0,
    );
  }

  // ===================================================
  // TAMBAH RUTE
  // ===================================================

  void addLeg(
    int day,
    TravelDirection direction,
  ) {
    if (day < 1 || day > 7) return;

    final id = _newId();
    final route = state.routeFor(day);

    final leg = EditorTransportLeg(
      id: id,
      mode: 'KRL',
      cost: 0,
    );

    _setRoute(
      day,
      direction == TravelDirection.outbound
          ? route.copyWith(
              outbound: [
                ...route.outbound,
                leg,
              ],
            )
          : route.copyWith(
              inbound: [
                ...route.inbound,
                leg,
              ],
            ),
    );
  }

  // ===================================================
  // HAPUS RUTE
  // ===================================================

  void removeLeg(
    int day,
    TravelDirection direction,
    String id,
  ) {
    if (day < 1 || day > 7) return;

    final route = state.routeFor(day);

    _setRoute(
      day,
      direction == TravelDirection.outbound
          ? route.copyWith(
              outbound: [
                for (final leg in route.outbound)
                  if (leg.id != id) leg,
              ],
            )
          : route.copyWith(
              inbound: [
                for (final leg in route.inbound)
                  if (leg.id != id) leg,
              ],
            ),
    );
  }

  // ===================================================
  // UPDATE RUTE
  // ===================================================

  void updateLeg(
    int day,
    TravelDirection direction,
    String id, {
    String? mode,
    int? cost,
    String? note,
  }) {
    if (day < 1 || day > 7) return;

    final route = state.routeFor(day);

    List<EditorTransportLeg> updated(
      List<EditorTransportLeg> legs,
    ) {
      return [
        for (final leg in legs)
          if (leg.id == id)
            leg.copyWith(
              mode: mode,
              cost: cost,
              note: note,
            )
          else
            leg,
      ];
    }

    _setRoute(
      day,
      direction == TravelDirection.outbound
          ? route.copyWith(
              outbound: updated(route.outbound),
            )
          : route.copyWith(
              inbound: updated(route.inbound),
            ),
    );
  }

  // ===================================================
  // NAVIGASI ONBOARDING
  // ===================================================

  void goBack() {
    if (state.isSaving || state.step == 0) {
      return;
    }

    state = state.copyWith(
      step: state.step - 1,
    );
  }

  /// Mengembalikan null jika valid.
  /// Mengembalikan pesan jika validasi gagal.
  String? nextStep() {
    if (state.isSaving) return null;

    final error = state.validationError();

    if (error != null) {
      return error;
    }

    if (state.step < 5) {
      state = state.copyWith(
        step: state.step + 1,
      );
    }

    return null;
  }

  // ===================================================
  // SIMPAN FINANCE PLAN
  // ===================================================

  Future<void> save(
    Future<void> Function(FinancePlan) onSave,
  ) async {
    if (state.isSaving) return;

    final error = state.validationError();

    if (error != null) {
      throw FormatException(error);
    }

    final draft = state.toFinancePlan();

    state = state.copyWith(
      isSaving: true,
    );

    try {
      await onSave(draft);
    } finally {
      if (!_disposed) {
        state = state.copyWith(
          isSaving: false,
        );
      }
    }
  }
}