import 'package:flutter/material.dart';
import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';

class AnalyticsSummary extends StatelessWidget {
  const AnalyticsSummary({
    super.key,
    required this.series,
    required this.currentPowerW,
    required this.totalConsumptionWh,
    required this.isOn,
  });

  final AnalyticsSeries series;
  final double currentPowerW;
  final double totalConsumptionWh;
  final bool isOn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(
          'Marcadores sobre el consumo eléctrico, en el periodo de tiempo seleccionado.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final spacing = 12.0;
            final itemWidth = (constraints.maxWidth - spacing) / 2;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _SummaryCard(
                  width: itemWidth,
                  title: 'Potencia actual',
                  value: '${currentPowerW.toStringAsFixed(1)} W',
                  subtitle: 'Última lectura',
                  icon: Icons.flash_on_rounded,
                  accentColor: const Color(0xFF2563EB),
                ),
                _SummaryCard(
                  width: itemWidth,
                  title: 'Consumo rango',
                  value: _formatWh(totalConsumptionWh),
                  subtitle: 'Consumo del periodo',
                  icon: Icons.bolt_rounded,
                  accentColor: const Color(0xFF7C3AED),
                ),
                _SummaryCard(
                  width: itemWidth,
                  title: 'Potencia media',
                  value: '${series.averagePowerW.toStringAsFixed(1)} W',
                  subtitle: 'Promedio del periodo',
                  icon: Icons.analytics_rounded,
                  accentColor: const Color(0xFF0F766E),
                ),
                _SummaryCard(
                  width: itemWidth,
                  title: 'Pico máximo',
                  value: '${series.maxPowerW.toStringAsFixed(1)} W',
                  subtitle: 'Valor más alto',
                  icon: Icons.trending_up_rounded,
                  accentColor: const Color(0xFFEA580C),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _formatWh(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)} kWh';
    }
    return '${value.toStringAsFixed(1)} Wh';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}