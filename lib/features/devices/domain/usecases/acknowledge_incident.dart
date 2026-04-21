import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class AcknowledgeIncident {
  AcknowledgeIncident(this.repository);

  final DevicesRepository repository;

  Future<void> call(String incidentId) {
    return repository.acknowledgeIncident(incidentId);
  }
}
