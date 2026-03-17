import 'package:flutter/material.dart';

import 'package:iot_manager/features/devices/domain/entities/device_item.dart';

class DeviceCard extends StatelessWidget {

  const DeviceCard({
    super.key,
    required this.device,
    this.onToggle,
    this.onTap,
  });
  final DeviceItem device;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = device.deviceType == 'light';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isLight ? Icons.lightbulb_outline_rounded : Icons.power_rounded,
        ),
        title: Text(device.name),
        subtitle: Text(device.identifier),
        trailing: Switch(
          value: device.isActive,
          onChanged: onToggle,
        ),
      ),
    );
  }
}