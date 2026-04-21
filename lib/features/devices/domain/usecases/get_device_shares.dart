import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class GetDeviceShares {
  GetDeviceShares(this.repository);

  final DevicesRepository repository;

  Future<List<Map<String, dynamic>>> call(String deviceId) {
    return repository.getDeviceShares(deviceId);
  }
}
