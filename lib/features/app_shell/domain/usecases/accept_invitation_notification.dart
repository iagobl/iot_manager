import 'package:iot_manager/features/app_shell/domain/repositories/notifications_repository.dart';

class AcceptInvitationNotification {
  const AcceptInvitationNotification(this.repository);

  final NotificationsRepository repository;

  Future<void> call(String shareId) {
    return repository.acceptInvitation(shareId);
  }
}