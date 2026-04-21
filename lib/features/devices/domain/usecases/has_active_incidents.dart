import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class HasActiveIncidents {
  HasActiveIncidents(this.repository);

  final DevicesRepository repository;

  Future<bool> call(String deviceId) {
    return repository.hasActiveIncidents(deviceId);
  }
}
