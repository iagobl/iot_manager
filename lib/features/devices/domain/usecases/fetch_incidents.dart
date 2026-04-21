import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class FetchIncidents {
  FetchIncidents(this.repository);

  final DevicesRepository repository;

  Future<List<Map<String, dynamic>>> call({required String deviceId, int limit = 100}) {
    return repository.fetchIncidents(deviceId: deviceId, limit: limit);
  }
}
