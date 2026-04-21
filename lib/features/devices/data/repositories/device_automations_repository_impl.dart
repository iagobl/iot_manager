import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/domain/repositories/device_automations_repository.dart';

class DeviceAutomationsRepositoryImpl implements DeviceAutomationsRepository {
  DeviceAutomationsRepositoryImpl(this.remoteDatasource);

  final DevicesRemoteDatasource remoteDatasource;

  @override
  Future<List<Map<String, dynamic>>> fetchAutomations({
    required String deviceId,
    required String type,
  }) async {
    try {
      return await remoteDatasource.fetchAutomations(
        deviceId: deviceId,
        type: type,
      );
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> upsertAutomation({
    String? id,
    required String deviceId,
    required String type,
    required bool enabled,
    required Map<String, dynamic> config,
  }) async {
    try {
      await remoteDatasource.upsertAutomation(
        id: id,
        deviceId: deviceId,
        type: type,
        enabled: enabled,
        config: config,
      );
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> deleteAutomation(String automationId) async {
    try {
      await remoteDatasource.deleteAutomation(automationId);
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }
}
