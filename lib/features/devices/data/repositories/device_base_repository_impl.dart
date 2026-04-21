import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:iot_manager/features/devices/domain/repositories/device_base_repository.dart';

class DeviceBaseRepositoryImpl implements DeviceBaseRepository {
  DeviceBaseRepositoryImpl(this.remoteDatasource);

  final DevicesRemoteDatasource remoteDatasource;

  @override
  Future<List<DeviceItem>> getUserDevices() async {
    try {
      return await remoteDatasource.getUserDevices();
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<DeviceItem> createManualDevice({
    required String name,
    required String deviceType,
    required String identifier,
    String protocol = 'http',
    String? homeId,
    String? roomId,
  }) async {
    try {
      return await remoteDatasource.createManualDevice(
        name: name,
        deviceType: deviceType,
        identifier: identifier,
        protocol: protocol,
        homeId: homeId,
        roomId: roomId,
      );
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> updateDeviceState(String deviceId, bool isActive) async {
    try {
      await remoteDatasource.updateDeviceState(deviceId, isActive);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> renameDevice({
    required String deviceId,
    required String name,
  }) async {
    try {
      await remoteDatasource.renameDevice(deviceId: deviceId, name: name);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> setDeviceUpdating({
    required String deviceId,
    required bool isUpdating,
  }) async {
    try {
      await remoteDatasource.setDeviceUpdating(deviceId: deviceId, isUpdating: isUpdating);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> unlinkDevice(String deviceId) async {
    try {
      await remoteDatasource.unlinkDevice(deviceId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    try {
      await remoteDatasource.deleteDevice(deviceId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<String?> getDeviceIdByIdentifier(String identifier) async {
    try {
      return await remoteDatasource.getDeviceIdByIdentifier(identifier);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }
}
