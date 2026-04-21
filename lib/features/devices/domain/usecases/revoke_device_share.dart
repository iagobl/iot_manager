import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class RevokeDeviceShare {
  RevokeDeviceShare(this.repository);

  final DevicesRepository repository;

  Future<void> call(String shareId) {
    return repository.revokeDeviceShare(shareId);
  }
}
