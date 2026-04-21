import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/device_datasource_shared.dart';

class DeviceReadingsRemoteDatasource with DeviceDatasourceShared {
  Future<List<Map<String, dynamic>>> fetchReadingsRange({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    int limit = 10000,
  }) async {
    try {
      final normalizedDeviceId = deviceId.trim();

      if (normalizedDeviceId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un identificador válido del dispositivo.',
        );
      }

      final response = await client.from('readings')
          .select('ts, power_w, voltage_v, energy_wh')
          .eq('device_id', normalizedDeviceId)
          .gte('ts', from.toUtc().toIso8601String())
          .lte('ts', to.toUtc().toIso8601String())
          .order('ts', ascending: true)
          .limit(limit);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> insertReadingSample({
    required String deviceId,
    required DateTime timestamp,
    required double powerW,
    required double voltageV,
    required double energyWh,
  }) async {
    try {
      final normalizedDeviceId = deviceId.trim();

      if (normalizedDeviceId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un identificador válido del dispositivo.',
        );
      }

      await client.from('readings').insert({
        'device_id': normalizedDeviceId,
        'ts': timestamp.toUtc().toIso8601String(),
        'power_w': powerW,
        'voltage_v': voltageV,
        'energy_wh': energyWh,
      });
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }
}
