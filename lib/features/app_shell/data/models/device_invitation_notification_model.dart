import 'package:iot_manager/features/app_shell/data/models/app_notification_model.dart';
import 'package:iot_manager/features/app_shell/domain/entities/device_invitation_notification.dart';

class DeviceInvitationNotificationModel extends DeviceInvitationNotification
    implements AppNotificationModel {
  const DeviceInvitationNotificationModel({
    required super.id,
    required super.deviceId,
    required super.deviceName,
    required super.deviceType,
    required super.ownerId,
    required super.ownerName,
    required super.sharedWithEmail,
    required super.createdAt,
    required super.status,
  });

  factory DeviceInvitationNotificationModel.fromMap(Map<String, dynamic> map) {
    return DeviceInvitationNotificationModel(
      id: (map['id'] ?? '').toString(),
      deviceId: (map['device_id'] ?? '').toString(),
      deviceName: (map['device_name'] ?? 'Dispositivo').toString(),
      deviceType: (map['device_type'] ?? '').toString(),
      ownerId: (map['owner_id'] ?? '').toString(),
      ownerName: (map['owner_name'] ?? '').toString(),
      sharedWithEmail: (map['shared_with_email'] ?? '').toString(),
      createdAt:
      DateTime.tryParse((map['created_at'] ?? '').toString())?.toLocal(),
      status: (map['status'] ?? 'pending').toString(),
    );
  }
}