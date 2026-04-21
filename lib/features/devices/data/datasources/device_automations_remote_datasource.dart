import 'package:iot_manager/core/constants/devices_panel_strings.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/device_datasource_shared.dart';

class DeviceAutomationsRemoteDatasource with DeviceDatasourceShared {
  Future<List<Map<String, dynamic>>> fetchAutomations({
    required String deviceId,
    required String type,
  }) async {
    try {
      final userId = requireUserId();

      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      if (type.trim().isEmpty) {
        throw const ValidationAppException('El tipo de automatización no es válido.');
      }

      final response = await client.from('device_automations').select()
          .eq('device_id', deviceId)
          .eq('type', type)
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> upsertAutomation({
    String? id,
    required String deviceId,
    required String type,
    required bool enabled,
    required Map<String, dynamic> config,
  }) async {
    try {
      final userId = requireUserId();

      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      if (type.trim().isEmpty) {
        throw const ValidationAppException('El tipo de automatización no es válido.');
      }

      final payload = <String, dynamic>{
        if (id != null && id.trim().isNotEmpty) 'id': id.trim(),
        'device_id': deviceId,
        'owner_id': userId,
        'type': type.trim(),
        'enabled': enabled,
        'config': config,
      };

      await client.from('device_automations').upsert(payload);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> deleteAutomation(String automationId) async {
    try {
      final userId = requireUserId();
      final normalizedId = automationId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      await client.from('device_automations').delete()
          .match({'id': normalizedId, 'owner_id': userId});
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }
}
