import 'package:iot_manager/features/app_shell/domain/entities/app_notification.dart';

abstract class AppNotificationModel extends AppNotification {
  const AppNotificationModel({
    required super.id,
    required super.createdAt,
  });
}