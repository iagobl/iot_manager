import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class InsertIncident {
  InsertIncident(this.repository);

  final DevicesRepository repository;

  Future<void> call({
    required String deviceId,
    required String type,
    required String message,
    int severity = 3,
  }) {
    return repository.insertIncident(
        deviceId: deviceId,
        type: type,
        message: message,
        severity: severity
    );
  }
}
