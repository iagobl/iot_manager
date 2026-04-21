import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class GetActiveIncidentsByTypes {
  GetActiveIncidentsByTypes(this.repository);

  final DevicesRepository repository;

  Future<List<Map<String, dynamic>>> call({required String deviceId, required List<String> types}) {
    return repository.getActiveIncidentsByTypes(deviceId: deviceId, types: types);
  }
}
