import 'package:flutter/material.dart';
import 'package:iot_manager/core/widgets/glass_card.dart';

class ProfileNotificationsCard extends StatelessWidget {
  const ProfileNotificationsCard({
    super.key,
    required this.notificationPreferences,
    required this.onChanged,
  });

  final Map<String, bool> notificationPreferences;
  final Future<void> Function(String key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preferencias de notificaciones',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: notificationPreferences['incidents'] ?? true,
            title: const Text('Incidencias'),
            subtitle: const Text('Avisos sobre límites de seguridad y eventos importantes'),
            onChanged: (value) {onChanged('incidents', value);},
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: notificationPreferences['device_status'] ?? true,
            title: const Text('Estado de dispositivos'),
            subtitle: const Text('Notificaciones cuando cambie el estado de los dispositivos'),
            onChanged: (value) {onChanged('device_status', value);},
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: notificationPreferences['sharing'] ?? true,
            title: const Text('Compartición'),
            subtitle: const Text('Avisos sobre invitaciones y cambios de acceso'),
            onChanged: (value) {onChanged('sharing', value);},
          ),
        ],
      ),
    );
  }
}