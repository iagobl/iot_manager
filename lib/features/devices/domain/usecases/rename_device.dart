import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class RenameDevice {
  RenameDevice(this.repository);

  final DevicesRepository repository;

  Future<void> call({
    required String deviceId,
    required String name,
  }) {
    return repository.renameDevice(deviceId: deviceId, name: name);
  }
}
