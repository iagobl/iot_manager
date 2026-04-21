import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class CreateManualDevice {
  CreateManualDevice(this.repository);

  final DevicesRepository repository;

  Future<DeviceItem> call({
    required String name,
    required String deviceType,
    required String identifier,
    String protocol = 'http',
    String? homeId,
    String? roomId,
  }) {
    return repository.createManualDevice(
      name: name,
      deviceType: deviceType,
      identifier: identifier,
      protocol: protocol,
      homeId: homeId,
      roomId: roomId,
    );
  }
}
