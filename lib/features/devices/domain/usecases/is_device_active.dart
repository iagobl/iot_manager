import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class IsDeviceActive {
  IsDeviceActive(this.repository);

  final DevicesRepository repository;

  Future<bool> call(dynamic device) {
    return repository.isDeviceActive(device);
  }
}
