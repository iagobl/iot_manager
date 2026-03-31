import 'package:iot_manager/features/app_shell/domain/entities/app_notification.dart';

class DeviceInvitationNotification extends AppNotification {
  const DeviceInvitationNotification({
    required super.id,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.ownerId,
    required this.ownerName,
    required this.sharedWithEmail,
    required super.createdAt,
    required this.status,
  });

  final String deviceId;
  final String deviceName;
  final String? deviceType;
  final String ownerId;
  final String ownerName;
  final String sharedWithEmail;
  final String status;

  @override
  bool get isResolved => status != 'pending';
}