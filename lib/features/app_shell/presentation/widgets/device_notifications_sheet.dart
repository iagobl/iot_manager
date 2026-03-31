import 'package:flutter/material.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/app_shell/domain/entities/app_notification.dart';
import 'package:iot_manager/features/app_shell/domain/entities/device_incident_notification.dart';
import 'package:iot_manager/features/app_shell/domain/entities/device_invitation_notification.dart';
import 'package:iot_manager/features/app_shell/presentation/controllers/notifications_controller.dart';

class DeviceNotificationsSheet extends StatefulWidget {
  const DeviceNotificationsSheet({
    super.key,
    required this.controller,
    this.onInvitationsChanged,
  });

  final NotificationsController controller;
  final VoidCallback? onInvitationsChanged;

  @override
  State<DeviceNotificationsSheet> createState() =>
      DeviceNotificationsSheetState();
}

class DeviceNotificationsSheetState extends State<DeviceNotificationsSheet> {
  NotificationsController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    ctrl.addListener(onControllerChanged);
    ctrl.load();
  }

  @override
  void dispose() {
    ctrl.removeListener(onControllerChanged);
    super.dispose();
  }

  void onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void showSnack(String text) {
    if (!mounted || text.trim().isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> accept(String shareId) async {
    try {
      await ctrl.accept(shareId);
      widget.onInvitationsChanged?.call();
    } catch (error) {
      showSnack(ctrl.errorMessage ?? ErrorMapper.mapFailure(error).message);
    }
  }

  Future<void> reject(String shareId) async {
    try {
      await ctrl.reject(shareId);
      widget.onInvitationsChanged?.call();
    } catch (error) {
      showSnack(ctrl.errorMessage ?? ErrorMapper.mapFailure(error).message);
    }
  }

  Future<void> acknowledgeIncident(String incidentId) async {
    try {
      await ctrl.acknowledgeIncident(incidentId);
    } catch (error) {
      showSnack(ctrl.errorMessage ?? ErrorMapper.mapFailure(error).message);
    }
  }

  String formatDeviceType(String? type) {
    if (type == null || type.trim().isEmpty) return '';

    switch (type.toLowerCase().trim()) {
      case 'plug':
      case 'switch':
      case 'socket':
        return 'Enchufe';
      case 'light':
      case 'bulb':
      case 'lamp':
        return 'Bombilla';
      default:
        return type;
    }
  }

  IconData deviceIcon(String? type) {
    if (type == null || type.trim().isEmpty) {
      return Icons.devices_other_outlined;
    }

    switch (type.toLowerCase().trim()) {
      case 'plug':
      case 'switch':
      case 'socket':
        return Icons.power_outlined;
      case 'light':
      case 'bulb':
      case 'lamp':
        return Icons.lightbulb_outline;
      default:
        return Icons.devices_other_outlined;
    }
  }

  String formatDate(DateTime? value) {
    if (value == null) return 'Sin fecha';

    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');

    return '$d/$m/$y — $h:$min';
  }

  String incidentTitle(String type, int severity) {
    final normalized = type.toLowerCase().trim();

    if (normalized.contains('voltage')) return 'Tensión máxima superada';
    if (normalized.contains('current')) return 'Corriente máxima superada';
    if (normalized.contains('power')) return 'Potencia máxima superada';
    if (normalized.contains('temperature')) return 'Temperatura elevada';
    if (normalized.contains('offline')) return 'Dispositivo desconectado';

    if (severity >= 3) return 'Alerta crítica de seguridad';
    if (severity == 2) return 'Alerta importante de seguridad';
    return 'Alerta de seguridad';
  }

  IconData incidentIcon(String type, int severity) {
    final normalized = type.toLowerCase().trim();

    if (normalized.contains('voltage')) return Icons.bolt;
    if (normalized.contains('current')) return Icons.electrical_services;
    if (normalized.contains('power')) return Icons.flash_on;
    if (normalized.contains('temperature')) return Icons.thermostat;
    if (normalized.contains('offline')) return Icons.wifi_off;

    if (severity >= 3) return Icons.warning_amber_rounded;
    return Icons.error_outline_rounded;
  }

  Color incidentAccentColor(
      String type,
      int severity,
      ColorScheme colorScheme,
      ) {
    final normalized = type.toLowerCase().trim();

    if (normalized.contains('voltage') ||
        normalized.contains('current') ||
        normalized.contains('power')) {
      return const Color(0xFFB45309);
    }

    if (normalized.contains('temperature')) {
      return colorScheme.error;
    }

    if (severity >= 3) return colorScheme.error;
    return const Color(0xFFB45309);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Notificaciones',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800,),
              ),
              const SizedBox(height: 6),
              Text(
                ctrl.items.isEmpty ? '' : 'Aquí verás invitaciones y alertas de seguridad recientes.',
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ctrl.loading
                    ? const Center(child: CircularProgressIndicator())
                    : ctrl.items.isEmpty
                    ? EmptyState(errorMessage: ctrl.errorMessage)
                    : ListView.separated(
                  itemCount: ctrl.items.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final AppNotification item = ctrl.items[index];

                    if (item is DeviceInvitationNotification) {
                      return InvitationCard(
                        item: item,
                        deviceTypeLabel:
                        formatDeviceType(item.deviceType),
                        deviceIcon: deviceIcon(item.deviceType),
                        onAccept: () => accept(item.id),
                        onReject: () => reject(item.id),
                      );
                    }

                    if (item is DeviceIncidentNotification) {
                      return IncidentNotificationCard(
                        item: item,
                        deviceTypeLabel:
                        formatDeviceType(item.deviceType),
                        deviceIcon: deviceIcon(item.deviceType),
                        incidentTitle:
                        incidentTitle(item.type, item.severity),
                        incidentIcon:
                        incidentIcon(item.type, item.severity),
                        incidentAccentColor: incidentAccentColor(item.type, item.severity, cs),
                        formattedDate: formatDate(item.createdAt),
                        onAcknowledge: () =>
                            acknowledgeIncident(item.id),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InvitationCard extends StatelessWidget {
  const InvitationCard({
    super.key,
    required this.item,
    required this.deviceTypeLabel,
    required this.deviceIcon,
    required this.onAccept,
    required this.onReject,
  });

  final DeviceInvitationNotification item;
  final String deviceTypeLabel;
  final IconData deviceIcon;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.10),
                ), child: Icon(deviceIcon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.deviceName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (deviceTypeLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(deviceTypeLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Te ha invitado: ${item.ownerName}',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          if (item.sharedWithEmail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.sharedWithEmail,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close),
                  label: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check),
                  label: const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class IncidentNotificationCard extends StatelessWidget {
  const IncidentNotificationCard({
    super.key,
    required this.item,
    required this.deviceTypeLabel,
    required this.deviceIcon,
    required this.incidentTitle,
    required this.incidentIcon,
    required this.incidentAccentColor,
    required this.formattedDate,
    required this.onAcknowledge,
  });

  final DeviceIncidentNotification item;
  final String deviceTypeLabel;
  final IconData deviceIcon;
  final String incidentTitle;
  final IconData incidentIcon;
  final Color incidentAccentColor;
  final String formattedDate;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: incidentAccentColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  incidentIcon,
                  color: incidentAccentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incidentTitle,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.deviceName,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (deviceTypeLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        deviceTypeLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: incidentAccentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formattedDate,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Text(
            item.message.trim().isEmpty ? 'Se ha registrado una incidencia de seguridad en el dispositivo.' : item.message,
            style: TextStyle(color: cs.onSurface),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAcknowledge,
              icon: const Icon(Icons.done_all),
              label: const Text('Marcar como revisada'),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          errorMessage?.isNotEmpty == true ? errorMessage! : 'No tienes notificaciones pendientes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}