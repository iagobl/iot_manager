import 'package:flutter/material.dart';
import 'package:iot_manager/core/widgets/glass_card.dart';
import 'package:iot_manager/features/profile/presentation/widgets/preference_dropdown.dart';

class ProfilePreferencesCard extends StatelessWidget {
  const ProfilePreferencesCard({
    super.key,
    required this.unitPreferences,
    required this.onChanged,
  });

  final Map<String, String> unitPreferences;
  final Future<void> Function(String key, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unidades por defecto',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          PreferenceDropdown(
            title: 'Energía',
            subtitle: 'Unidad usada por defecto en consumos',
            value: unitPreferences['energy'] ?? 'kWh',
            items: const ['Wh', 'kWh'],
            onChanged: (value) {
              if (value == null) return;
              onChanged('energy', value);
            },
          ),
          const SizedBox(height: 12),
          PreferenceDropdown(
            title: 'Potencia',
            subtitle: 'Unidad usada por defecto en potencia',
            value: unitPreferences['power'] ?? 'W',
            items: const ['W', 'kW'],
            onChanged: (value) {
              if (value == null) return;
              onChanged('power', value);
            },
          ),
          const SizedBox(height: 12),
          PreferenceDropdown(
            title: 'Voltaje',
            subtitle: 'Unidad usada por defecto en voltaje',
            value: unitPreferences['voltage'] ?? 'V',
            items: const ['V'],
            onChanged: (value) {
              if (value == null) return;
              onChanged('voltage', value);
            },
          ),
        ],
      ),
    );
  }
}