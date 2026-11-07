import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/finance_plan_notifier.dart';
import 'app_settings_provider.dart';

// ============================================
// SETTINGS UI STATE
// ============================================

@immutable
class SettingsUiState {
  const SettingsUiState({
    this.isChangingTheme = false,
    this.isResettingPlan = false,
  });

  final bool isChangingTheme;
  final bool isResettingPlan;

  SettingsUiState copyWith({
    bool? isChangingTheme,
    bool? isResettingPlan,
  }) {
    return SettingsUiState(
      isChangingTheme:
          isChangingTheme ?? this.isChangingTheme,
      isResettingPlan:
          isResettingPlan ?? this.isResettingPlan,
    );
  }
}

// ============================================
// SETTINGS UI PROVIDER
// ============================================

final settingsUiProvider =
    NotifierProvider<
        SettingsUiNotifier,
        SettingsUiState>(
  SettingsUiNotifier.new,
);

// ============================================
// SETTINGS UI NOTIFIER
// ============================================

class SettingsUiNotifier
    extends Notifier<SettingsUiState> {
  @override
  SettingsUiState build() {
    return const SettingsUiState();
  }

  // ==========================================
  // CHANGE THEME
  // ==========================================

  Future<void> changeTheme(ThemeMode mode) async {
    if (state.isChangingTheme) return;

    if (ref.read(appSettingsProvider).themeMode == mode) {
      return;
    }

    state = state.copyWith(
      isChangingTheme: true,
    );

    try {
      await ref
          .read(appSettingsProvider.notifier)
          .setThemeMode(mode);
    } finally {
      state = state.copyWith(
        isChangingTheme: false,
      );
    }
  }

  // ==========================================
  // RESET FINANCIAL PLAN
  // ==========================================

  Future<void> resetFinancialPlan() async {
    if (state.isResettingPlan) return;

    state = state.copyWith(
      isResettingPlan: true,
    );

    try {
      // Hanya data Planner yang dihapus.
      // Transaksi, tabungan, dan profil tetap ada.
      await ref
          .read(financePlanProvider.notifier)
          .clearPlan();
    } finally {
      state = state.copyWith(
        isResettingPlan: false,
      );
    }
  }
}