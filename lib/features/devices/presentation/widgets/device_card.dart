import 'package:flutter/material.dart';

import '../../domain/entities/device_item.dart';

class DeviceCard extends StatelessWidget {
  final DeviceItem device;
  final ValueChanged<bool>? onToggle;

  const DeviceCard({
    super.key,
    required this.device,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = device.deviceType == 'light';

    return Card(
      child: ListTile(
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