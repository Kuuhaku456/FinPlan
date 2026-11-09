import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/plan_controller.dart';

import '../providers/app_settings_provider.dart';
import '../providers/settings_ui_provider.dart';

import 'widgets/settings_components.dart';
import 'widgets/transaction_export_card.dart';
import 'widgets/transaction_import_card.dart';

// ==========================================
// FINPLAN - SETTINGS PAGE
// ==========================================

const Color _darkGreen = Color(0xFF064E3B);
const Color _green = Color(0xFF059669);

// ==========================================
// MAIN SETTINGS PAGE
// ==========================================

class SettingsPage extends ConsumerWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.textScale,
    required this.onTextScaleChanged,
  });

  // Dipertahankan agar kompatibel dengan
  // pemanggilan SettingsPage pada FinanceShell.
  final PlanController controller;
  final double textScale;
  final ValueChanged<double> onTextScaleChanged;

  // ========================================
  // FONT SIZE PRESETS
  // ========================================

  static const _presets = <(String, double)>[
    ('Normal', 1.0),
    ('Sedang', 1.15),
    ('Besar', 1.3),
    ('Ekstra Besar', 1.5),
  ];

  // ========================================
  // 1. CHANGE THEME
  // ========================================

  Future<void> _changeTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
  ) async {
    if (ref.read(settingsUiProvider).isChangingTheme) {
      return;
    }

    try {
      await ref
          .read(settingsUiProvider.notifier)
          .changeTheme(mode);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal mengubah tema aplikasi.',
          ),
        ),
      );
    }
  }

  // ========================================
  // 2. RESET FINANCIAL PLAN
  // ========================================

  Future<void> _confirmResetPlan(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (ref.read(settingsUiProvider).isResettingPlan) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogScheme =
            Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          scrollable: true,

          title: const Text(
            'Reset Rencana Keuangan?',
          ),

          content: const Text(
            'Rencana keuangan dan pembagian gaji '
            'akan dihapus.\n\n'
            'Kamu perlu mengisi data perencanaan '
            'kembali setelah melakukan reset.\n\n'
            'Transaksi, kantong tabungan, dan profil '
            'tidak ikut dihapus.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Batal'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dialogScheme.error,
                foregroundColor: dialogScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(settingsUiProvider.notifier)
          .resetFinancialPlan();

      if (context.mounted &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal mereset rencana. Coba lagi.',
          ),
        ),
      );
    }
  }

  // ========================================
  // 3. SECTION TITLE
  // ========================================

  Widget _sectionTitle(
    BuildContext context,
    String title,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  // ========================================
  // 4. FONT SETTINGS
  // ========================================

  Widget _fontSettings(
    BuildContext context,
    WidgetRef ref,
    double selectedScale,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final percent = (selectedScale * 100).round();

    void changeFontSize(double value) {
      ref
          .read(appSettingsProvider.notifier)
          .setFontScale(value);
    }

    return SettingsSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================================
          // HEADER
          // ==================================

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              SettingsIconBox(
                icon: Icons.format_size_rounded,
                color: scheme.primary,
                background: scheme.primaryContainer,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ukuran Teks',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w800,
                          ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Perbesar tulisan agar '
                      'lebih mudah dibaca.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                            color:
                                scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ==================================
          // CURRENT FONT SIZE
          // ==================================

          Row(
            children: [
              const Icon(
                Icons.text_fields_rounded,
                size: 18,
              ),

              const Spacer(),

              Text(
                '$percent%',
                style: theme.textTheme.titleLarge
                    ?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),

          // ==================================
          // FONT SIZE SLIDER
          // ==================================

          Slider(
            value: selectedScale,
            min: 1.0,
            max: 1.5,
            divisions: 10,
            label: '$percent%',
            onChanged: changeFontSize,
            semanticFormatterCallback: (value) {
              return '${(value * 100).round()} persen';
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '100%',
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  '150%',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ==================================
          // FONT PRESETS
          // ==================================

          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final preset in _presets)
                ChoiceChip(
                  label: Text(preset.$1),
                  selected:
                      (selectedScale - preset.$2).abs() <
                          0.001,
                  onSelected: (_) {
                    changeFontSize(preset.$2);
                  },
                ),
            ],
          ),

          const SizedBox(height: 16),

          // ==================================
          // FONT PREVIEW
          // ==================================

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer
                  .withValues(alpha: 0.55),
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Pratinjau Tulisan',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Mengatur uang jadi lebih mudah.',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Catat pemasukan, pengeluaran, '
                  'dan target tabunganmu '
                  'dengan nyaman.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ==================================
          // RESET FONT SIZE
          // ==================================

          TextButton.icon(
            onPressed: selectedScale == 1.0
                ? null
                : () => changeFontSize(1.0),
            icon: const Icon(
              Icons.restart_alt_rounded,
            ),
            label: const Text(
              'Kembalikan ukuran normal',
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // 5. THEME SETTINGS
  // ========================================

  Widget _themeSettings(
    BuildContext context,
    WidgetRef ref,
    ThemeMode selectedMode,
    bool isChangingTheme,
  ) {
    final mediaScale =
        MediaQuery.textScalerOf(context).scale(16) /
            16;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackVertically =
            constraints.maxWidth < 350 ||
                mediaScale >= 1.4;

        final lightThemeCard =
            SettingsThemePreviewCard(
          dark: false,
          selected:
              selectedMode == ThemeMode.light,
          enabled: !isChangingTheme,
          onTap: () {
            _changeTheme(
              context,
              ref,
              ThemeMode.light,
            );
          },
        );

        final darkThemeCard =
            SettingsThemePreviewCard(
          dark: true,
          selected:
              selectedMode == ThemeMode.dark,
          enabled: !isChangingTheme,
          onTap: () {
            _changeTheme(
              context,
              ref,
              ThemeMode.dark,
            );
          },
        );

        return Column(
          children: [
            // ==================================
            // LIGHT / DARK MODE
            // ==================================

            if (stackVertically) ...[
              lightThemeCard,

              const SizedBox(height: 10),

              darkThemeCard,
            ] else
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: lightThemeCard,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: darkThemeCard,
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // ==================================
            // FOLLOW SYSTEM THEME
            // ==================================

            SettingsSystemThemeChoice(
              selected:
                  selectedMode == ThemeMode.system,
              enabled: !isChangingTheme,
              isDeviceDark:
                  MediaQuery.platformBrightnessOf(
                        context,
                      ) ==
                      Brightness.dark,
              onTap: () {
                _changeTheme(
                  context,
                  ref,
                  ThemeMode.system,
                );
              },
            ),

            const SizedBox(height: 9),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 3,
              ),
              child: Text(
                'Jika memilih Ikuti Sistem HP, '
                'FinPlan akan mengikuti tema '
                'yang digunakan perangkat.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
            ),

            if (isChangingTheme) ...[
              const SizedBox(height: 10),

              const LinearProgressIndicator(
                minHeight: 3,
              ),
            ],
          ],
        );
      },
    );
  }

  // ========================================
  // 6. FINPLAN HEADER
  // ========================================

  Widget _buildFinPlanHeader(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            _darkGreen,
            _green,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.16,
              ),
              borderRadius:
                  BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'FinPlan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Your Personal Finance Partner',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // 7. RESET PLAN CARD
  // ========================================

  Widget _buildResetPlanCard(
    BuildContext context,
    WidgetRef ref,
    bool isResetting,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return SettingsSurface(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),

        leading: SettingsIconBox(
          icon: Icons.restart_alt_rounded,
          color: scheme.onErrorContainer,
          background: scheme.errorContainer,
        ),

        title: const Text(
          'Reset Rencana',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),

        subtitle: const Text(
          'Mulai pembagian gaji dari awal',
        ),

        trailing: isResetting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.chevron_right_rounded,
              ),

        onTap: isResetting
            ? null
            : () {
                _confirmResetPlan(
                  context,
                  ref,
                );
              },
      ),
    );
  }

  // ========================================
  // 8. PRIVACY & SECURITY
  // ========================================

  Widget _buildPrivacySection(
    BuildContext context,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return SettingsSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),

            leading: SettingsIconBox(
              icon: Icons.lock_outline_rounded,
              color: scheme.onPrimaryContainer,
              background: scheme.primaryContainer,
            ),

            title: const Text(
              'Penyimpanan Lokal',
            ),

            subtitle: const Text(
              'Data disimpan di perangkat',
            ),
          ),

          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
          ),

          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),

            leading: SettingsIconBox(
              icon: Icons.verified_user_outlined,
              color: scheme.onPrimaryContainer,
              background: scheme.primaryContainer,
            ),

            title: const Text(
              'Keamanan Data',
            ),

            subtitle: const Text(
              'Hindari menyimpan PIN '
              'atau kata sandi',
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // 9. ABOUT FINPLAN
  // ========================================

  Widget _buildAboutSection(
    BuildContext context,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return SettingsSurface(
      child: Row(
        children: [
          SettingsIconBox(
            icon: Icons.favorite_outline_rounded,
            color: scheme.onPrimaryContainer,
            background: scheme.primaryContainer,
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Text(
              'FinPlan membantu merencanakan, '
              'mencatat, dan mencapai '
              'tujuan keuanganmu.',
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // 10. MAIN BUILD
  // ========================================

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final settings = ref.watch(
      appSettingsProvider,
    );

    final ui = ref.watch(
      settingsUiProvider,
    );

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        32,
      ),

      children: [
        // ==================================
        // PAGE HEADER
        // ==================================

        Text(
          'Pengaturan',
          style: theme.textTheme.headlineSmall
              ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),

        const SizedBox(height: 5),

        Text(
          'Atur tampilan, keamanan, '
          'dan data keuangan FinPlan.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),

        const SizedBox(height: 22),

        _buildFinPlanHeader(context),

        const SizedBox(height: 26),

        // ==================================
        // SECTION 1: THEME
        // ==================================

        _sectionTitle(
          context,
          'Tampilan Aplikasi',
        ),

        _themeSettings(
          context,
          ref,
          settings.themeMode,
          ui.isChangingTheme,
        ),

        const SizedBox(height: 25),

        // ==================================
        // SECTION 2: ACCESSIBILITY
        // ==================================

        _sectionTitle(
          context,
          'Aksesibilitas',
        ),

        _fontSettings(
          context,
          ref,
          settings.fontScale,
        ),

        const SizedBox(height: 25),

        // ==================================
        // SECTION 3: DATA MANAGEMENT
        // ==================================

        _sectionTitle(
          context,
          'Data & Perencanaan',
        ),

        // ==================================
        // EXPORT TRANSACTIONS
        // ==================================

        const TransactionExportCard(),

        const SizedBox(height: 12),

        // ==================================
        // IMPORT TRANSACTIONS
        // ==================================

        const TransactionImportCard(),

        const SizedBox(height: 12),

        // ==================================
        // RESET FINANCIAL PLAN
        // ==================================

        _buildResetPlanCard(
          context,
          ref,
          ui.isResettingPlan,
        ),

        const SizedBox(height: 25),

        // ==================================
        // SECTION 4: PRIVACY
        // ==================================

        _sectionTitle(
          context,
          'Privasi & Keamanan',
        ),

        _buildPrivacySection(context),

        const SizedBox(height: 25),

        // ==================================
        // SECTION 5: ABOUT
        // ==================================

        _sectionTitle(
          context,
          'Tentang FinPlan',
        ),

        _buildAboutSection(context),

        const SizedBox(height: 24),

        // ==================================
        // FOOTER
        // ==================================

        Center(
          child: Text(
            'FinPlan • Better financial habits',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}