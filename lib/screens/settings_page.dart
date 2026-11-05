import 'package:flutter/material.dart';

import '../state/plan_controller.dart';

const _darkGreen = Color(0xFF064E3B);
const _green = Color(0xFF059669);

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.textScale,
    required this.onTextScaleChanged,
  });

  final PlanController controller;
  final double textScale;
  final ValueChanged<double> onTextScaleChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late double _selectedScale;
  bool _changingTheme = false;
  bool _deleting = false;

  static const _presets = <(String, double)>[
    ('Normal', 1.0),
    ('Sedang', 1.15),
    ('Besar', 1.3),
    ('Ekstra Besar', 1.5),
  ];

  @override
  void initState() {
    super.initState();
    _selectedScale = widget.textScale.clamp(1.0, 1.5).toDouble();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textScale != widget.textScale &&
        widget.textScale != _selectedScale) {
      _selectedScale = widget.textScale.clamp(1.0, 1.5).toDouble();
    }
  }

  void _changeFontSize(double value) {
    final scale = (value * 20).round() / 20.0;
    if (_selectedScale == scale) return;
    setState(() => _selectedScale = scale);
    widget.onTextScaleChanged(scale);
  }

  Future<void> _changeTheme(ThemeMode mode) async {
    if (_changingTheme || widget.controller.themeMode == mode) return;
    setState(() => _changingTheme = true);
    try {
      await widget.controller.changeThemeMode(mode);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengubah tema aplikasi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _changingTheme = false);
    }
  }

  Future<void> _confirmResetPlan() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Reset rencana keuangan?'),
        content: const Text(
          'Rencana dan pembagian gaji akan dihapus, lalu kamu perlu '
          'mengisi data perencanaan kembali.\n\n'
          'Transaksi, kantong tabungan, dan profil tidak ikut dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.controller.clearPlan();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mereset rencana. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _fontSettings(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final percent = (_selectedScale * 100).round();

    return _SettingsSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBox(
                icon: Icons.format_size_rounded,
                color: scheme.primary,
                background: scheme.primaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ukuran Teks',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Perbesar tulisan agar lebih mudah dibaca.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.text_fields_rounded, size: 18),
              const Spacer(),
              Text(
                '$percent%',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: _selectedScale,
            min: 1.0,
            max: 1.5,
            divisions: 10,
            label: '$percent%',
            onChanged: _changeFontSize,
            semanticFormatterCallback: (value) =>
                '${(value * 100).round()} persen',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('100%', style: theme.textTheme.labelSmall),
                Text('150%', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final preset in _presets)
                ChoiceChip(
                  label: Text(preset.$1),
                  selected: (_selectedScale - preset.$2).abs() < 0.001,
                  onSelected: (_) => _changeFontSize(preset.$2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pratinjau Tulisan',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mengatur uang jadi lebih mudah.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Catat pemasukan, pengeluaran, dan target tabunganmu '
                  'dengan nyaman.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _selectedScale == 1.0
                ? null
                : () => _changeFontSize(1.0),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Kembalikan ukuran normal'),
          ),
        ],
      ),
    );
  }

  Widget _themeSettings(BuildContext context, ThemeMode selectedMode) {
    final mediaScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackVertically =
            constraints.maxWidth < 350 || mediaScale >= 1.4;
        final light = _ThemePreviewCard(
          dark: false,
          selected: selectedMode == ThemeMode.light,
          enabled: !_changingTheme,
          onTap: () => _changeTheme(ThemeMode.light),
        );
        final dark = _ThemePreviewCard(
          dark: true,
          selected: selectedMode == ThemeMode.dark,
          enabled: !_changingTheme,
          onTap: () => _changeTheme(ThemeMode.dark),
        );

        return Column(
          children: [
            if (stackVertically) ...[
              light,
              const SizedBox(height: 10),
              dark,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: light),
                  const SizedBox(width: 10),
                  Expanded(child: dark),
                ],
              ),
            const SizedBox(height: 12),
            _SystemThemeChoice(
              selected: selectedMode == ThemeMode.system,
              enabled: !_changingTheme,
              isDeviceDark:
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark,
              onTap: () => _changeTheme(ThemeMode.system),
            ),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                'Jika memilih Ikuti Sistem HP, FinPlan langsung memakai '
                'tema perangkat saat dibuka dan ikut berubah saat tema HP berubah.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (_changingTheme) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              'Pengaturan',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Atur tampilan yang paling nyaman untukmu.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [_darkGreen, _green],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(17),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            _sectionTitle(context, 'Tampilan Aplikasi'),
            _themeSettings(context, widget.controller.themeMode),
            const SizedBox(height: 25),
            _sectionTitle(context, 'Aksesibilitas'),
            _fontSettings(context),
            const SizedBox(height: 25),
            _sectionTitle(context, 'Data & Perencanaan'),
            _SettingsSurface(
              padding: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                leading: _IconBox(
                  icon: Icons.restart_alt_rounded,
                  color: scheme.onErrorContainer,
                  background: scheme.errorContainer,
                ),
                title: const Text(
                  'Reset Rencana',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Mulai pembagian gaji dari awal'),
                trailing: _deleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: _deleting ? null : _confirmResetPlan,
              ),
            ),
            const SizedBox(height: 25),
            _sectionTitle(context, 'Privasi & Keamanan'),
            _SettingsSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: _IconBox(
                      icon: Icons.lock_outline_rounded,
                      color: scheme.onPrimaryContainer,
                      background: scheme.primaryContainer,
                    ),
                    title: const Text('Penyimpanan Lokal'),
                    subtitle: const Text('Data disimpan di perangkat'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: _IconBox(
                      icon: Icons.verified_user_outlined,
                      color: scheme.onPrimaryContainer,
                      background: scheme.primaryContainer,
                    ),
                    title: const Text('Keamanan Data'),
                    subtitle: const Text('Hindari menyimpan PIN atau kata sandi'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            _sectionTitle(context, 'Tentang FinPlan'),
            _SettingsSurface(
              child: Row(
                children: [
                  _IconBox(
                    icon: Icons.favorite_outline_rounded,
                    color: scheme.onPrimaryContainer,
                    background: scheme.primaryContainer,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'FinPlan membantu merencanakan, mencatat, '
                      'dan mencapai tujuan keuanganmu.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'FinPlan • Better financial habits',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color),
      );
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.dark,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final bool dark;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = dark ? 'Dark Mode' : 'Light Mode';
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, ${selected ? 'dipilih' : 'ketuk untuk memilih'}',
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                width: selected ? 2.5 : 1.2,
                color: selected ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1.55,
                  child: _MiniThemePreview(dark: dark),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Icon(
                      dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      size: 23,
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        title,
                        softWrap: true,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: selected ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 22,
                        color: scheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  dark ? 'Gelap' : 'Terang',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniThemePreview extends StatelessWidget {
  const _MiniThemePreview({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF059669);
    final pageColor = dark ? const Color(0xFF15231E) : const Color(0xFFF0FBF6);
    final panelColor = dark ? const Color(0xFF29473B) : Colors.white;
    final lineColor = dark ? const Color(0xFF536A60) : const Color(0xFFB6D8CA);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pageColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  color: green,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 9,
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const Spacer(),
                Expanded(
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF116D57)
                          : const Color(0xFFA9DFCA),
                      borderRadius: BorderRadius.circular(8),
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
}

class _SystemThemeChoice extends StatelessWidget {
  const _SystemThemeChoice({
    required this.selected,
    required this.enabled,
    required this.isDeviceDark,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final bool isDeviceDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Ikuti sistem HP, ${selected ? 'dipilih' : 'ketuk untuk memilih'}',
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                width: selected ? 2.5 : 1.2,
                color: selected ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.phone_android_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ikuti Sistem HP',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: selected ? scheme.primary : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Otomatis mengikuti mode HP. '
                        'Perangkatmu sekarang: ${isDeviceDark ? 'Gelap' : 'Terang'}.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 7),
                  Icon(Icons.check_circle_rounded, color: scheme.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
