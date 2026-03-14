import 'package:flutter/material.dart';

import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/device_item.dart';

class DeviceCard extends StatelessWidget {
  final DeviceItem device;

  const DeviceCard({
    super.key,
    required this.device,
  });

  IconData resolveIcon() {
    final type = device.deviceType.toLowerCase();
    if (type.contains('plug') || type.contains('enchufe')) {
      return Icons.power_rounded;
    }
    if (type.contains('light') || type.contains('luz')) {
      return Icons.lightbulb_outline_rounded;
    }
    if (type.contains('sensor')) {
      return Icons.sensors_outlined;
    }
    return Icons.memory_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final energyText = device.energyTodayWh <= 0
        ? 'Sin consumo hoy'
        : '${device.energyTodayWh.toStringAsFixed(0)} Wh hoy';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: (device.isActive ? cs.primary : cs.outlineVariant)
                      .withValues(alpha: 0.14),
                ),
                child: Icon(
                  resolveIcon(),
                  color: device.isActive ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${device.deviceType} · ${device.protocol}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(isActive: device.isActive),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              InfoChip(label: 'ID', value: device.identifier),
              InfoChip(
                label: 'Hogar',
                value: device.homeId == null ? 'Sin asignar' : 'Asignado',
              ),
              InfoChip(label: 'Consumo', value: energyText),
            ],
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final bool isActive;

  const StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: (isActive ? Colors.green : cs.outlineVariant)
            .withValues(alpha: 0.14),
      ),
      child: Text(
        isActive ? 'Activo' : 'Inactivo',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.green.shade700 : cs.onSurfaceVariant,
            ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cs.surface.withValues(alpha: 0.7),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
