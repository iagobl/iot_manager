import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class LeaveSharedDevice {
  LeaveSharedDevice(this.repository);

  final DevicesRepository repository;

  Future<void> call(String shareId) {
    return repository.leaveSharedDevice(shareId);
  }
}
