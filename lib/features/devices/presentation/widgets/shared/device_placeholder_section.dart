import 'package:flutter/material.dart';
import 'package:iot_manager/core/constants/devices_panel_strings.dart';

import 'package:iot_manager/features/devices/presentation/pages/device_panel_page.dart';

class DevicePlaceholderSection extends StatelessWidget {
  const DevicePlaceholderSection({
    super.key,
    required this.section,
  });

  final DevicePanelSection section;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final label = switch (section) {
      DevicePanelSection.overview => DevicesPanelStrings.overview,
      DevicePanelSection.charts => DevicesPanelStrings.charts,
      DevicePanelSection.incidents => DevicesPanelStrings.incidents,
      DevicePanelSection.info => DevicesPanelStrings.info,
      DevicePanelSection.light => DevicesPanelStrings.light,
      DevicePanelSection.safety => DevicesPanelStrings.safety,
      DevicePanelSection.schedules => DevicesPanelStrings.schedules,
      DevicePanelSection.settings => DevicesPanelStrings.settings,
      DevicePanelSection.share => DevicesPanelStrings.share,
      DevicePanelSection.timer => DevicesPanelStrings.timer,
    };

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_rounded,
              size: 38,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(label + DevicesPanelStrings.preparation,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}