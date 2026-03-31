import 'package:iot_manager/features/app_shell/domain/entities/app_notification.dart';
import 'package:iot_manager/features/app_shell/domain/repositories/notifications_repository.dart';

class GetNotifications {
  const GetNotifications(this.repository);

  final NotificationsRepository repository;

  Future<List<AppNotification>> call() {
    return repository.getNotifications();
  }
}