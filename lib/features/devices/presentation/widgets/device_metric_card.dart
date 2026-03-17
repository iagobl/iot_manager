import 'package:flutter/material.dart';
import 'package:iot_manager/core/constants/devices_panel_strings.dart';

class DeviceMetricCard extends StatelessWidget {
  const DeviceMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.accentOverride,
    this.gradientOverride,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color? accentOverride;
  final List<Color>? gradientOverride;

  Color _accentColor() {
    if (accentOverride != null) return accentOverride!;

    switch (title) {
      case DevicesPanelStrings.voltage:
        return const Color(0xFF3D6EA8);
      case DevicesPanelStrings.currentConsumption:
        return const Color(0xFFE58E26);
      case DevicesPanelStrings.current:
        return const Color(0xFF4C7CBF);
      case DevicesPanelStrings.temperature:
        return const Color(0xFFCC6B5A);
      case DevicesPanelStrings.energyToday:
        return const Color(0xFF4E9B6E);
      case DevicesPanelStrings.hz:
        return const Color(0xFF7A67C7);
      default:
        return const Color(0xFF3D6EA8);
    }
  }

  List<Color> _gradientColors() {
    if (gradientOverride != null) return gradientOverride!;

    return [
      Colors.white.withValues(alpha: 0.92),
      const Color(0xFFF3F5F9).withValues(alpha: 0.92),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientColors(),
        ),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: accent, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E2430),
                  ),
                  children: [
                    TextSpan(text: value),
                    if (unit.isNotEmpty)
                      TextSpan(text: ' $unit',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF1E2430),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}