import 'package:iot_manager/features/app_shell/domain/repositories/notifications_repository.dart';

class RejectInvitationNotification {
  const RejectInvitationNotification(this.repository);

  final NotificationsRepository repository;

  Future<void> call(String shareId) {
    return repository.rejectInvitation(shareId);
  }
}