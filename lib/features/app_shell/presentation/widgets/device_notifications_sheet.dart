import 'package:flutter/material.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
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
    if (mounted) setState(() {});
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
      showSnack('Invitación aceptada correctamente.');

    } catch (error) {
      showSnack(ctrl.errorMessage ?? ErrorMapper.mapFailure(error).message);
    }
  }

  Future<void> reject(String shareId) async {
    try {
      await ctrl.reject(shareId);
      widget.onInvitationsChanged?.call();
      showSnack('Invitación rechazada.');

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
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text('', style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              Expanded(
                child: ctrl.loading
                    ? const Center(child: CircularProgressIndicator())
                    : ctrl.items.isEmpty
                    ? EmptyState(
                  errorMessage: ctrl.errorMessage,
                ) : ListView.separated(
                  itemCount: ctrl.items.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = ctrl.items[index];
                    return InvitationCard(
                      item: item,
                      deviceTypeLabel:
                      formatDeviceType(item.deviceType),
                      deviceIcon: deviceIcon(item.deviceType),
                      onAccept: () => accept(item.id),
                      onReject: () => reject(item.id),
                    );
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
  const InvitationCard({super.key,
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
                ),
                child: Icon(deviceIcon, color: cs.primary,),
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
        child: Text(errorMessage?.isNotEmpty == true
              ? errorMessage!
              : 'No tienes invitaciones pendientes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}