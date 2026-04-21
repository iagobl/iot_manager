import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/domain/repositories/device_readings_repository.dart';

class DeviceReadingsRepositoryImpl implements DeviceReadingsRepository {
  DeviceReadingsRepositoryImpl(this.remoteDatasource);

  final DevicesRemoteDatasource remoteDatasource;

  @override
  Future<List<Map<String, dynamic>>> fetchReadingsRange({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    int limit = 10000,
  }) async {
    try {
      return await remoteDatasource.fetchReadingsRange(
        deviceId: deviceId,
        from: from,
        to: to,
        limit: limit,
      );
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }

  @override
  Future<void> insertReadingSample({
    required String deviceId,
    required DateTime timestamp,
    required double powerW,
    required double voltageV,
    required double energyWh,
  }) async {
    try {
      await remoteDatasource.insertReadingSample(
        deviceId: deviceId,
        timestamp: timestamp,
        powerW: powerW,
        voltageV: voltageV,
        energyWh: energyWh,
      );
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }
}
