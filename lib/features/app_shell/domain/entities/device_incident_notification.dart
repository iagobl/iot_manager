import 'package:iot_manager/features/app_shell/domain/entities/app_notification.dart';

class DeviceIncidentNotification extends AppNotification {
  const DeviceIncidentNotification({
    required super.id,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.homeId,
    required super.createdAt,
    required this.type,
    required this.severity,
    required this.message,
    required this.isAcknowledged,
  });

  final String deviceId;
  final String deviceName;
  final String? deviceType;
  final String homeId;
  final String type;
  final int severity;
  final String message;
  final bool isAcknowledged;

  @override
  bool get isResolved => isAcknowledged;
}