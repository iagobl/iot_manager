import 'package:iot_manager/features/app_shell/domain/entities/app_notification.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> getNotifications();

  Future<void> acceptInvitation(String shareId);

  Future<void> rejectInvitation(String shareId);

  Future<void> acknowledgeIncident(String incidentId);
}