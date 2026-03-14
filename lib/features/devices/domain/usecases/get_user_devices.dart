import '../entities/device_item.dart';
import '../repositories/devices_repository.dart';

class GetUserDevices {
  final DevicesRepository repository;

  GetUserDevices(this.repository);

  Future<List<DeviceItem>> call() {
    return repository.getUserDevices();
  }
}
