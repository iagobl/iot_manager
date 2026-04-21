import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class SetDeviceUpdating {
  SetDeviceUpdating(this.repository);

  final DevicesRepository repository;

  Future<void> call({required String deviceId, required bool isUpdating}) {
    return repository.setDeviceUpdating(deviceId: deviceId, isUpdating: isUpdating);
  }
}
