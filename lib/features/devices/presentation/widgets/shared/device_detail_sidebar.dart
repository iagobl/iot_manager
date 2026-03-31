import 'package:flutter/material.dart';
import 'package:iot_manager/core/constants/devices_panel_strings.dart';

import 'package:iot_manager/features/devices/presentation/pages/device_panel_page.dart';

class DeviceDetailSidebar extends StatelessWidget {
  const DeviceDetailSidebar({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final DevicePanelSection selectedSection;
  final ValueChanged<DevicePanelSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final item in _items)
                  SidebarButton(
                    icon: item.icon,
                    isSelected: selectedSection == item.section,
                    tooltip: item.label,
                    onTap: () => onSectionSelected(item.section),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SidebarButton extends StatelessWidget {
  const SidebarButton({
    super.key,
    required this.icon,
    required this.isSelected,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarItem {
  const SidebarItem({
    required this.section,
    required this.icon,
    required this.label,
  });

  final DevicePanelSection section;
  final IconData icon;
  final String label;
}

const List<SidebarItem> _items = [
  SidebarItem(section: DevicePanelSection.overview, icon: Icons.dashboard_outlined, label: DevicesPanelStrings.overview),
  SidebarItem(section: DevicePanelSection.light, icon: Icons.lightbulb_outline_rounded, label: DevicesPanelStrings.light),
  SidebarItem(section: DevicePanelSection.charts, icon: Icons.show_chart_rounded, label: DevicesPanelStrings.charts),
  SidebarItem(section: DevicePanelSection.schedules, icon: Icons.calendar_month_outlined, label: DevicesPanelStrings.schedules),
  SidebarItem(section: DevicePanelSection.timer, icon: Icons.timer_outlined, label: DevicesPanelStrings.timer),
  SidebarItem(section: DevicePanelSection.share, icon: Icons.group_outlined, label: DevicesPanelStrings.share),
  SidebarItem(section: DevicePanelSection.safety, icon: Icons.shield_outlined, label: DevicesPanelStrings.safety),
  SidebarItem(section: DevicePanelSection.incidents, icon: Icons.warning_amber_rounded, label: DevicesPanelStrings.incidents),
  SidebarItem(section: DevicePanelSection.info, icon: Icons.info_outline_rounded, label: DevicesPanelStrings.info),
  SidebarItem(section: DevicePanelSection.settings, icon: Icons.settings_outlined, label: DevicesPanelStrings.settings),
];