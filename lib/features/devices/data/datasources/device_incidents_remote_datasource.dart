import 'package:iot_manager/core/constants/devices_panel_strings.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/device_datasource_shared.dart';

class DeviceIncidentsRemoteDatasource with DeviceDatasourceShared {
  Future<bool> hasActiveIncidents(String deviceId) async {
    try {
      final normalizedId = deviceId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un identificador válido del dispositivo.',
        );
      }

      final response = await client.from('incidents').select('id')
          .eq('device_id', normalizedId)
          .eq('is_resolved', false)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<Map<String, dynamic>?> getLatestActiveIncident(String deviceId) async {
    try {
      final normalizedId = deviceId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un identificador válido del dispositivo.',
        );
      }

      final response = await client.from('incidents').select()
          .eq('device_id', normalizedId)
          .eq('is_resolved', false)
          .order('ts', ascending: false);

      final rows = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();

      if (rows.isEmpty) return null;

      for (final row in rows) {
        final type = (row['type'] ?? '').toString().toLowerCase().trim();
        if (type.contains('overvoltage') ||
            type.contains('overpower') ||
            type.contains('overcurrent') ||
            type.contains('overtemperature') ||
            type.contains('temperature')) {
          return row;
        }
      }

      return rows.first;
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> getActiveIncidentsByTypes({
    required String deviceId,
    required List<String> types,
  }) async {
    try {
      final normalizedId = deviceId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un identificador válido del dispositivo.',
        );
      }

      final cleanTypes = types.map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty).toSet().toList();

      if (cleanTypes.isEmpty) return <Map<String, dynamic>>[];

      final response = await client.from('incidents').select()
          .eq('device_id', normalizedId)
          .eq('is_resolved', false)
          .inFilter('type', cleanTypes)
          .order('ts', ascending: false);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> acknowledgeIncident(String incidentId) async {
    try {
      final normalizedId = incidentId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException('No se ha encontrado una incidencia válida.');
      }

      await client.from('incidents').update({'is_acknowledged': true})
          .eq('id', normalizedId);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> resolveIncident(String incidentId) async {
    try {
      final normalizedId = incidentId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException('No se ha encontrado una incidencia válida.');
      }

      await client
          .from('incidents')
          .update({'is_resolved': true})
          .eq('id', normalizedId);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> resolveIncidents(List<String> incidentIds) async {
    try {
      final ids = incidentIds.map((e) => e.trim())
          .where((e) => e.isNotEmpty).toSet().toList();

      if (ids.isEmpty) return;

      await client
          .from('incidents')
          .update({'is_resolved': true})
          .inFilter('id', ids);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> insertIncident({
    required String deviceId,
    required String type,
    required String message,
    int severity = 3,
  }) async {
    try {
      final normalizedDeviceId = deviceId.trim();

      if (normalizedDeviceId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un identificador válido del dispositivo.',
        );
      }

      await client.from('incidents').insert({
        'device_id': normalizedDeviceId,
        'type': type.trim(),
        'message': message.trim(),
        'severity': severity,
        'is_acknowledged': false,
        'is_resolved': false,
        'ts': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> fetchIncidents({
    required String deviceId,
    int limit = 100,
  }) async {
    try {
      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      final response = await client.from('incidents').select()
          .eq('device_id', deviceId)
          .order('ts', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }
}
