import 'package:iot_manager/core/constants/auth_strings.dart';
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
        'device_type': deviceType,
        'protocol': protocol,
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

  Future<void> updateDeviceState(
      String deviceId,
      bool isActive,
      ) async {
    try {
      await _client
          .from('devices')
          .update({'is_active': isActive})
          .eq('id', deviceId);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> deleteDevice(String id) async {
    try {
      await _client.from('devices').delete().eq('id', id);
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