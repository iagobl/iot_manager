import 'package:iot_manager/core/constants/devices_panel_strings.dart';
import 'package:iot_manager/core/constants/devices_strings.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/device_datasource_shared.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';

class DeviceBaseRemoteDatasource with DeviceDatasourceShared {
  Future<List<DeviceItem>> getUserDevices() async {
    try {
      final userId = requireUserId();

      final ownedResponse = await client.from('devices').select()
          .eq('owner_id', userId).order('created_at', ascending: false);

      final ownedDevices = (ownedResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();

      final sharesResponse = await client.from('device_shares')
          .select('device_id, owner_id, status')
          .eq('shared_with_user_id', userId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      final acceptedShares = (sharesResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();

      final sharedDeviceIds = acceptedShares
          .map((row) => (row['device_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final sharedOwnerIds = acceptedShares
          .map((row) => (row['owner_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final ownerEmails = <String, String>{};
      if (sharedOwnerIds.isNotEmpty) {
        final ownersResponse = await client
            .from('profiles')
            .select('id, email')
            .inFilter('id', sharedOwnerIds);

        for (final raw in ownersResponse as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          ownerEmails[(row['id'] ?? '').toString()] =
              (row['email'] ?? '').toString();
        }
      }

      final sharedDevices = <Map<String, dynamic>>[];
      if (sharedDeviceIds.isNotEmpty) {
        final sharedResponse = await client
            .from('devices')
            .select()
            .inFilter('id', sharedDeviceIds);

        final shareByDeviceId = <String, Map<String, dynamic>>{};
        for (final row in acceptedShares) {
          final deviceId = (row['device_id'] ?? '').toString();
          if (deviceId.isNotEmpty) {
            shareByDeviceId[deviceId] = row;
          }
        }

        for (final raw in sharedResponse as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          final deviceId = (row['id'] ?? '').toString();
          final share = shareByDeviceId[deviceId];
          final ownerId =
          (share?['owner_id'] ?? row['owner_id'] ?? '').toString();

          sharedDevices.add({
            ...row,
            'is_shared': true,
            'share_status': share?['status']?.toString(),
            'owner_email': ownerEmails[ownerId],
          });
        }
      }

      final devices = <DeviceItem>[
        ...ownedDevices.map(
              (row) => DeviceItem.fromMap({
            ...row,
            'is_shared': false,
            'share_status': null,
            'owner_email': null,
          }),
        ),
        ...sharedDevices.map(DeviceItem.fromMap),
      ];

      final unique = <String, DeviceItem>{
        for (final device in devices) device.id: device,
      };

      return unique.values.toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<DeviceItem> createManualDevice({
    required String name,
    required String deviceType,
    required String identifier,
    String protocol = 'http',
    String? homeId,
    String? roomId,
  }) async {
    try {
      final userId = requireUserId();

      if (name.trim().isEmpty) {
        throw const ValidationAppException(DevicesStrings.notDeviceName);
      }

      if (identifier.trim().isEmpty) {
        throw const ValidationAppException(DevicesStrings.notDeviceIdentifier);
      }

      final response = await client.from('devices').insert({
        'name': name.trim(),
        'device_type': deviceType.trim(),
        'protocol': protocol.trim(),
        'identifier': identifier.trim(),
        'is_active': false,
        'owner_id': userId,
        'home_id': homeId,
        'room_id': roomId,
        'energy_today_wh': 0,
      }).select().single();

      return DeviceItem.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> updateDeviceState(String deviceId, bool isActive) async {
    try {
      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      await client.from('devices').update({'is_active': isActive}).eq('id', deviceId);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> renameDevice({
    required String deviceId,
    required String name,
  }) async {
    try {
      final userId = requireUserId();

      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      if (name.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.nameNotNull);
      }

      await client.from('devices').update({'name': name.trim()})
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
      final userId = requireUserId();

      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      await client.from('devices').update({
        'is_updating': isUpdating,
        'update_started_at':
        isUpdating ? DateTime.now().toUtc().toIso8601String() : null,
      }).match({'id': deviceId, 'owner_id': userId});
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> unlinkDevice(String deviceId) async {
    try {
      final userId = requireUserId();

      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      await client.from('devices').delete().match({'id': deviceId, 'owner_id': userId});
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> deleteDevice(String id) async {
    try {
      if (id.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      await client.from('devices').delete().eq('id', id);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<String?> getDeviceIdByIdentifier(String identifier) async {
    try {
      final normalizedIdentifier = identifier.trim();

      if (normalizedIdentifier.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un identificador válido del dispositivo.',
        );
      }

      final row = await client.from('devices').select('id')
          .eq('identifier', normalizedIdentifier).maybeSingle();

      if (row == null) return null;

      final id = (row['id'] ?? '').toString().trim();
      return id.isEmpty ? null : id;
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }
}
