import 'package:flutter/material.dart';

class AnalyticsStats extends StatelessWidget {
  const AnalyticsStats({
    super.key,
    required this.unit,
    required this.color,
    required this.min,
    required this.max,
    required this.avg,
  });

  final String unit;
  final Color color;
  final double min;
  final double max;
  final double avg;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            label: 'Mínimo',
            value: _formatValue(min),
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatItem(
            label: 'Máximo',
            value: _formatValue(max),
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatItem(
            label: 'Media',
            value: _formatValue(avg),
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatValue(double value) {
    final decimals = unit == 'A' ? 3 : 1;
    return '${value.toStringAsFixed(decimals)} $unit';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}