import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class GetUserDevices {

  GetUserDevices(this.repository);
  final DevicesRepository repository;

  Future<List<DeviceItem>> call() {
    return repository.getUserDevices();
  }
}
