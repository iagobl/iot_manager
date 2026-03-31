import 'package:iot_manager/features/app_shell/data/models/app_notification_model.dart';
import 'package:iot_manager/features/app_shell/domain/entities/device_incident_notification.dart';

class DeviceIncidentNotificationModel extends DeviceIncidentNotification
    implements AppNotificationModel {
  const DeviceIncidentNotificationModel({
    required super.id,
    required super.deviceId,
    required super.deviceName,
    required super.deviceType,
    required super.homeId,
    required super.createdAt,
    required super.type,
    required super.severity,
    required super.message,
    required super.isAcknowledged,
  });

  factory DeviceIncidentNotificationModel.fromMap(Map<String, dynamic> map) {
    return DeviceIncidentNotificationModel(
      id: (map['id'] ?? '').toString(),
      deviceId: (map['device_id'] ?? '').toString(),
      deviceName: (map['device_name'] ?? 'Dispositivo').toString(),
      deviceType: (map['device_type'] ?? '').toString(),
      homeId: (map['home_id'] ?? '').toString(),
      createdAt: DateTime.tryParse((map['ts'] ?? '').toString())?.toLocal(),
      type: (map['type'] ?? '').toString(),
      severity: toInt(map['severity']),
      message: (map['message'] ?? '').toString(),
      isAcknowledged: map['is_acknowledged'] == true,
    );
  }

  static int toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}