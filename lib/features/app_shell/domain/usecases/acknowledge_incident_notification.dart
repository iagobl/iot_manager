import 'package:iot_manager/features/app_shell/domain/repositories/notifications_repository.dart';

class AcknowledgeIncidentNotification {
  const AcknowledgeIncidentNotification(this.repository);

  final NotificationsRepository repository;

  Future<void> call(String incidentId) {
    return repository.acknowledgeIncident(incidentId);
  }
}