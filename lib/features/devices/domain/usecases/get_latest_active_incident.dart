import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class GetLatestActiveIncident {
  GetLatestActiveIncident(this.repository);

  final DevicesRepository repository;

  Future<Map<String, dynamic>?> call(String deviceId) {
    return repository.getLatestActiveIncident(deviceId);
  }
}
