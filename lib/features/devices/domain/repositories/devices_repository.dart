import '../entities/device_item.dart';

abstract class DevicesRepository {
  Future<List<DeviceItem>> getUserDevices();
}
