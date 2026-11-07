import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../screens/profile_page.dart';
import '../../settings/providers/app_settings_provider.dart';

// =====================================================
// FINANCE SHELL UI STATE
// =====================================================

class FinanceShellUiState {
  const FinanceShellUiState({
    this.selectedIndex = 0,
    this.isChangingTheme = false,
  });

  final int selectedIndex;
  final bool isChangingTheme;

  FinanceShellUiState copyWith({
    int? selectedIndex,
    bool? isChangingTheme,
  }) {
    return FinanceShellUiState(
      selectedIndex:
          selectedIndex ?? this.selectedIndex,
      isChangingTheme:
          isChangingTheme ?? this.isChangingTheme,
    );
  }
}

// =====================================================
// FINANCE SHELL PROVIDER
// =====================================================

final financeShellUiProvider =
    NotifierProvider<
      FinanceShellUiNotifier,
      FinanceShellUiState
    >(
      FinanceShellUiNotifier.new,
    );

// =====================================================
// FINANCE SHELL NOTIFIER
// =====================================================

class FinanceShellUiNotifier
    extends Notifier<FinanceShellUiState> {
  @override
  FinanceShellUiState build() {
    return const FinanceShellUiState();
  }

  // Mengubah tab aktif
  void selectTab(int index) {
    if (index < 0 || index > 3) return;

    if (index == state.selectedIndex) return;

    state = state.copyWith(
      selectedIndex: index,
    );
  }

  // Status mengganti tema
  void setChangingTheme(bool value) {
    if (state.isChangingTheme == value) return;

    state = state.copyWith(
      isChangingTheme: value,
    );
  }
}

// =====================================================
// PROFILE STORE PROVIDER
// =====================================================

final finPlanProfileStoreProvider =
    Provider<ProfileStore>((ref) {
  final preferences =
      ref.watch(settingsPreferencesProvider);

  return ProfileStore(preferences);
});

// =====================================================
// PROFILE PROVIDER
// =====================================================

final finPlanProfileProvider =
    FutureProvider<FinPlanProfile>((ref) {
  final store = ref.watch(
    finPlanProfileStoreProvider,
  );

  return store.load();
});