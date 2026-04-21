import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class ResolveIncidents {
  ResolveIncidents(this.repository);

  final DevicesRepository repository;

  Future<void> call(List<String> incidentIds) {
    return repository.resolveIncidents(incidentIds);
  }
}
