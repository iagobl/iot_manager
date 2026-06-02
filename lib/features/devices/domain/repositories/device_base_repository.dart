import 'package:iot_manager/features/devices/domain/entities/device_item.dart';

abstract class DeviceBaseRepository {
  Future<List<DeviceItem>> getUserDevices();

  Future<DeviceItem> createManualDevice({
    required String name,
    required String deviceType,
    required String identifier,
    String protocol = 'http',
    String? homeId,
  });

  Future<void> updateDeviceState(String deviceId, bool isActive);

  Future<void> renameDevice({required String deviceId, required String name});

  Future<void> setDeviceUpdating({required String deviceId, required bool isUpdating});

  Future<void> unlinkDevice(String deviceId);

  Future<void> deleteDevice(String deviceId);

  Future<String?> getDeviceIdByIdentifier(String identifier);
}
