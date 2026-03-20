import 'package:iot_manager/core/constants/auth_strings.dart';
import 'package:iot_manager/core/constants/devices_panel_strings.dart';
import 'package:iot_manager/core/constants/devices_strings.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DevicesRemoteDatasource {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<DeviceItem>> getUserDevices() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const ValidationAppException(AuthStrings.notAutenticated);
      }

      final response = await _client
          .from('devices')
          .select()
          .eq('owner_id', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => DeviceItem.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> createManualDevice({
    required String name,
    required String deviceType,
    required String identifier,
    String protocol = 'http',
    String? homeId,
    String? roomId,
  }) async {
    try {
      final userId = _requireUserId();

      if (name.trim().isEmpty) {
        throw const ValidationAppException(DevicesStrings.notDeviceName);
      }

      if (identifier.trim().isEmpty) {
        throw const ValidationAppException(DevicesStrings.notDeviceIdentifier);
      }

      await _client.from('devices').insert({
        'name': name.trim(),
        'device_type': deviceType.trim(),
        'protocol': protocol.trim(),
        'identifier': identifier.trim(),
        'is_active': false,
        'owner_id': userId,
        'home_id': homeId,
        'room_id': roomId,
        'energy_today_wh': 0,
      });
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> updateDeviceState(String deviceId, bool isActive) async {
    try {
      if (deviceId.trim().isEmpty) {throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      await _client
          .from('devices')
          .update({'is_active': isActive})
          .eq('id', deviceId);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> renameDevice({
    required String deviceId,
    required String name,
  }) async {
    try {
      final userId = _requireUserId();

      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException(
          DevicesPanelStrings.notValidIndentifier,
        );
      }

      if (name.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.nameNotNull);
      }

      await _client
          .from('devices')
          .update({'name': name.trim()})
          .match({'id': deviceId, 'owner_id': userId});
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> setDeviceUpdating({
    required String deviceId,
    required bool isUpdating,
  }) async {
    try {
      final userId = _requireUserId();

      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier,);
      }

      await _client
          .from('devices')
          .update({
        'is_updating': isUpdating,
        'update_started_at':
        isUpdating ? DateTime.now().toUtc().toIso8601String() : null,
      })
          .match({'id': deviceId, 'owner_id': userId});
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> unlinkDevice(String deviceId) async {
    try {
      final userId = _requireUserId();

      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException(
          DevicesPanelStrings.notValidIndentifier,
        );
      }

      await _client
          .from('devices')
          .delete()
          .match({'id': deviceId, 'owner_id': userId});
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> deleteDevice(String id) async {
    try {
      if (id.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      await _client.from('devices').delete().eq('id', id);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<bool> hasActiveIncidents(String deviceId) async {
    try {
      final response = await _client
          .from('incidents')
          .select('id')
          .eq('device_id', deviceId)
          .eq('is_acknowledged', false)
          .limit(1);

      return (response as List).isNotEmpty;
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

      final response = await _client
          .from('incidents')
          .select()
          .eq('device_id', deviceId)
          .order('ts', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> fetchAutomations({
    required String deviceId,
    required String type,
  }) async {
    try {
      final userId = _requireUserId();

      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      if (type.trim().isEmpty) {
        throw const ValidationAppException('El tipo de automatización no es válido.');
      }

      final response = await _client
          .from('device_automations')
          .select()
          .eq('device_id', deviceId)
          .eq('type', type)
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
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
      final userId = _requireUserId();

      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException(
          DevicesPanelStrings.notValidIndentifier,
        );
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

      await _client.from('device_automations').upsert(payload);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> deleteAutomation({
    required String automationId,
  }) async {
    try {
      final userId = _requireUserId();

      if (automationId.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      await _client
          .from('device_automations')
          .delete()
          .match({
        'id': automationId,
        'owner_id': userId,
      });
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ValidationAppException(AuthStrings.notAutenticated);
    }
    return user.id;
  }
}