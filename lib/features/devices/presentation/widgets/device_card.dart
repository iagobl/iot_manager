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
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isLight ? Icons.lightbulb_outline_rounded : Icons.power_rounded,
        ),
        title: Row(
          children: [
            Expanded(child: Text(device.name)),
            if (device.isShared)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: cs.primary.withValues(alpha: 0.12),
                ),
                child: Text(
                  'Compartido',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(device.identifier),
            if (device.isShared && (device.ownerEmail ?? '').isNotEmpty)
              Text(
                'Propietario: ${device.ownerEmail}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
          ],
        ),
        trailing: Switch(
          value: device.isActive,
          onChanged: onToggle,
        ),
      ),
    );
  }
}
