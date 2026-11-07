import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money.dart';
import '../../../../models/finance_plan.dart';

// =====================================================
// SECTION CARD
// =====================================================

class PlanEditorSectionCard extends StatelessWidget {
  const PlanEditorSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
}

// =====================================================
// INPUT NOMINAL
// =====================================================

/// TextEditingController hanya digunakan untuk
/// menangani teks dan posisi kursor.
///
/// State nominal keuangan tetap dikelola Riverpod.
/// Tidak menggunakan setState().
class PlanEditorMoneyField extends StatefulWidget {
  const PlanEditorMoneyField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<PlanEditorMoneyField> createState() {
    return _PlanEditorMoneyFieldState();
  }
}

class _PlanEditorMoneyFieldState
    extends State<PlanEditorMoneyField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.value.toString(),
    );
  }

  @override
  void didUpdateWidget(
    covariant PlanEditorMoneyField oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    // Sinkronkan teks jika nominal diubah
    // secara otomatis dari luar input.
    //
    // Jika pengguna sedang mengetik,
    // posisi kursor tetap dipertahankan.
    if (parseRupiah(_controller.text) != widget.value) {
      final text = widget.value.toString();

      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
          offset: text.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: 'Rp ',
      ),
      onChanged: (text) {
        widget.onChanged(
          parseRupiah(text),
        );
      },
    );
  }
}

// =====================================================
// INPUT FREKUENSI
// =====================================================

class PlanEditorFrequencyField extends StatelessWidget {
  const PlanEditorFrequencyField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final BudgetFrequency value;
  final ValueChanged<BudgetFrequency> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<BudgetFrequency>(
      key: ValueKey(value),
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
      onChanged: (frequency) {
        if (frequency != null) {
          onChanged(frequency);
        }
      },
    );
  }
}

// =====================================================
// METRIC CARD
// =====================================================

class PlanEditorMetricCard extends StatelessWidget {
  const PlanEditorMetricCard({
    super.key,
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final int amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rupiah(amount),
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
}