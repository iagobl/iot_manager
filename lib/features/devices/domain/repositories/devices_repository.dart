import 'package:iot_manager/features/devices/domain/entities/device_item.dart';

abstract class DevicesRepository {
  Future<List<DeviceItem>> getUserDevices();
}
