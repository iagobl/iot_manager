import 'package:flutter/material.dart';

enum AnalyticsMetricView {
  power,
  voltage,
  current,
}

class AnalyticsSelector extends StatelessWidget {
  const AnalyticsSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AnalyticsMetricView selected;
  final ValueChanged<AnalyticsMetricView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SelectorChip(
          label: 'Potencia',
          color: const Color(0xFF2563EB),
          selected: selected == AnalyticsMetricView.power,
          onTap: () => onChanged(AnalyticsMetricView.power),
        ),
        SelectorChip(
          label: 'Voltaje',
          color: const Color(0xFF8B5CF6),
          selected: selected == AnalyticsMetricView.voltage,
          onTap: () => onChanged(AnalyticsMetricView.voltage),
        ),
        SelectorChip(
          label: 'Corriente',
          color: const Color(0xFF14B8A6),
          selected: selected == AnalyticsMetricView.current,
          onTap: () => onChanged(AnalyticsMetricView.current),
        ),
      ],
    );
  }
}

class SelectorChip extends StatelessWidget {
  const SelectorChip({super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : scheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.35)
                : scheme.outlineVariant.withValues(alpha: 0.7),
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_rounded : Icons.circle,
              size: selected ? 16 : 10,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? color : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}