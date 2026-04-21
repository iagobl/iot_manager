import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class DeleteDevice {
  DeleteDevice(this.repository);

  final DevicesRepository repository;

  Future<void> call(String deviceId) {
    return repository.deleteDevice(deviceId);
  }
}
