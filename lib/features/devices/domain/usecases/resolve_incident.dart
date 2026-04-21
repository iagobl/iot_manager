import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class ResolveIncident {
  ResolveIncident(this.repository);

  final DevicesRepository repository;

  Future<void> call(String incidentId) {
    return repository.resolveIncident(incidentId);
  }
}
