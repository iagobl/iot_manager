import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class UnlinkDevice {
  UnlinkDevice(this.repository);

  final DevicesRepository repository;

  Future<void> call(String deviceId) {
    return repository.unlinkDevice(deviceId);
  }
}
