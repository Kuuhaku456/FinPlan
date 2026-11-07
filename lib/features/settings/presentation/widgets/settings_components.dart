import 'package:flutter/material.dart';

// ============================================
// SETTINGS SURFACE
// ============================================

class SettingsSurface extends StatelessWidget {
  const SettingsSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: child,
    );
  }
}

// ============================================
// SETTINGS ICON BOX
// ============================================

class SettingsIconBox extends StatelessWidget {
  const SettingsIconBox({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}

// ============================================
// LIGHT / DARK THEME PREVIEW CARD
// ============================================

class SettingsThemePreviewCard extends StatelessWidget {
  const SettingsThemePreviewCard({
    super.key,
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
    final colors = Theme.of(context).colorScheme;
    final title = dark ? 'Dark Mode' : 'Light Mode';

    return Semantics(
      button: true,
      selected: selected,
      label: '$title, '
          '${selected ? 'dipilih' : 'ketuk untuk memilih'}',
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 200,
            ),
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(24),
              border: Border.all(
                width: selected ? 2.5 : 1.2,
                color: selected
                    ? colors.primary
                    : colors.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1.55,
                  child: _MiniThemePreview(
                    dark: dark,
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Icon(
                      dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: 23,
                      color: selected
                          ? colors.primary
                          : colors.onSurface,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        title,
                        softWrap: true,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: selected
                              ? colors.primary
                              : colors.onSurface,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 22,
                        color: colors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  dark ? 'Gelap' : 'Terang',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: colors.onSurfaceVariant,
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

// ============================================
// MINI THEME PREVIEW
// ============================================

class _MiniThemePreview extends StatelessWidget {
  const _MiniThemePreview({
    required this.dark,
  });

  final bool dark;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF059669);

    final pageColor = dark
        ? const Color(0xFF15231E)
        : const Color(0xFFF0FBF6);

    final panelColor = dark
        ? const Color(0xFF29473B)
        : Colors.white;

    final lineColor = dark
        ? const Color(0xFF536A60)
        : const Color(0xFFB6D8CA);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pageColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  color: green,
                  borderRadius:
                      BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 9,
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: green,
                      borderRadius:
                          BorderRadius.circular(8),
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
                      borderRadius:
                          BorderRadius.circular(8),
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

// ============================================
// FOLLOW SYSTEM THEME
// ============================================

class SettingsSystemThemeChoice extends StatelessWidget {
  const SettingsSystemThemeChoice({
    super.key,
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
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Ikuti sistem HP, '
          '${selected ? 'dipilih' : 'ketuk untuk memilih'}',
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 200,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(22),
              border: Border.all(
                width: selected ? 2.5 : 1.2,
                color: selected
                    ? colors.primary
                    : colors.outlineVariant,
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.phone_android_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ikuti Sistem HP',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: selected
                                  ? colors.primary
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Otomatis mengikuti mode HP. '
                        'Perangkatmu sekarang: '
                        '${isDeviceDark ? 'Gelap' : 'Terang'}.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 7),
                  Icon(
                    Icons.check_circle_rounded,
                    color: colors.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}