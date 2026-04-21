import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class UpdateDeviceState {
  UpdateDeviceState(this.repository);

  final DevicesRepository repository;

  Future<void> call(String deviceId, bool isActive) {
    return repository.updateDeviceState(deviceId, isActive);
  }
}
