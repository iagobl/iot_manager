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
      final userId = _requireUserId();

      final ownedResponse = await _client
          .from('devices')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      final ownedDevices = (ownedResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final sharesResponse = await _client
          .from('device_shares')
          .select('device_id, owner_id, status')
          .eq('shared_with_user_id', userId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      final acceptedShares = (sharesResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

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

      final Map<String, String> ownerEmails = {};
      if (sharedOwnerIds.isNotEmpty) {
        final ownersResponse = await _client
            .from('profiles')
            .select('id, email')
            .inFilter('id', sharedOwnerIds);

        for (final raw in ownersResponse as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          ownerEmails[(row['id'] ?? '').toString()] =
              (row['email'] ?? '').toString();
        }
      }

      final List<Map<String, dynamic>> sharedDevices = [];
      if (sharedDeviceIds.isNotEmpty) {
        final sharedResponse = await _client
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

  Future<int> getPendingInvitationsCount() async {
    try {
      final userId = _requireUserId();
      final response = await _client
          .from('device_shares')
          .select('id')
          .eq('shared_with_user_id', userId)
          .eq('status', 'pending');

      return (response as List).length;
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> getPendingInvitations() async {
    try {
      final userId = _requireUserId();

      final response = await _client
          .from('device_shares')
          .select(
        'id, device_id, owner_id, shared_with_email, created_at, status',
      )
          .eq('shared_with_user_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final rows = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (rows.isEmpty) return rows;

      final deviceIds = rows
          .map((e) => (e['device_id'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      final ownerIds = rows
          .map((e) => (e['owner_id'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      final deviceNames = <String, String>{};
      final deviceTypes = <String, String>{};
      final ownerNames = <String, String>{};

      if (deviceIds.isNotEmpty) {
        final devicesResponse = await _client
            .from('devices')
            .select('id, name, device_type')
            .inFilter('id', deviceIds);

        for (final raw in devicesResponse as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = (row['id'] ?? '').toString();

          deviceNames[id] = (row['name'] ?? 'Dispositivo').toString();
          deviceTypes[id] = (row['device_type'] ?? '').toString();
        }
      }

      if (ownerIds.isNotEmpty) {
        final ownersResponse = await _client
            .from('profiles')
            .select('id, first_name, last_name, email')
            .inFilter('id', ownerIds);

        for (final raw in ownersResponse as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          final first = (row['first_name'] ?? '').toString().trim();
          final last = (row['last_name'] ?? '').toString().trim();
          final email = (row['email'] ?? '').toString().trim();
          final fullName = '$first $last'.trim();

          ownerNames[(row['id'] ?? '').toString()] =
          fullName.isNotEmpty ? fullName : email;
        }
      }

      return rows.map((row) {
        final deviceId = (row['device_id'] ?? '').toString();

        return {
          ...row,
          'device_name': deviceNames[deviceId] ?? 'Dispositivo',
          'device_type': deviceTypes[deviceId],
          'owner_name':
          ownerNames[(row['owner_id'] ?? '').toString()] ?? 'Usuario',
        };
      }).toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> acceptInvitation(String shareId) async {
    try {
      final userId = _requireUserId();
      final normalizedId = shareId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado una invitación válida.',
        );
      }

      await _client.from('device_shares').update({
        'status': 'accepted',
        'accepted_at': DateTime.now().toUtc().toIso8601String(),
        'revoked_at': null,
      }).match({
        'id': normalizedId,
        'shared_with_user_id': userId,
      });
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> rejectInvitation(String shareId) async {
    try {
      final userId = _requireUserId();
      final normalizedId = shareId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado una invitación válida.',
        );
      }

      await _client.from('device_shares').update({
        'status': 'rejected',
      }).match({
        'id': normalizedId,
        'shared_with_user_id': userId,
      });
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<Map<String, dynamic>?> fetchDeviceOwnership(String deviceId) async {
    try {
      final normalizedId = deviceId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un identificador válido del dispositivo.',
        );
      }

      return await _client
          .from('devices')
          .select('id, owner_id, name')
          .eq('id', normalizedId)
          .maybeSingle();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> getDeviceShares(String deviceId) async {
    try {
      final normalizedId = deviceId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un identificador válido del dispositivo.',
        );
      }

      final response = await _client
          .from('device_shares')
          .select()
          .eq('device_id', normalizedId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> getProfilesByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return <Map<String, dynamic>>[];

      final cleanIds = ids
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      if (cleanIds.isEmpty) return <Map<String, dynamic>>[];

      final response = await _client
          .from('profiles')
          .select('id, first_name, last_name, email')
          .inFilter('id', cleanIds);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> inviteDeviceShareByEmail({
    required String deviceId,
    required String email,
  }) async {
    try {
      final userId = _requireUserId();
      final normalizedDeviceId = deviceId.trim();
      final normalizedEmail = email.trim().toLowerCase();

      if (normalizedDeviceId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un identificador válido del dispositivo.',
        );
      }

      if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
        throw const ValidationAppException(
          'Introduce un correo válido.',
        );
      }

      final deviceRow = await _client
          .from('devices')
          .select('id, owner_id')
          .eq('id', normalizedDeviceId)
          .maybeSingle();

      if (deviceRow == null) {
        throw const ValidationAppException('No se encontró el dispositivo.');
      }

      final ownerId = (deviceRow['owner_id'] ?? '').toString();
      if (ownerId != userId) {
        throw const ValidationAppException(
          'Solo el propietario puede compartir este dispositivo.',
        );
      }

      final profileResponse = await _client
          .from('profiles')
          .select('id, email')
          .eq('email', normalizedEmail);

      final profiles = (profileResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (profiles.isEmpty) {
        throw const ValidationAppException(
          'No existe ningún usuario registrado con ese correo.',
        );
      }

      final sharedUserId = (profiles.first['id'] ?? '').toString();
      if (sharedUserId.isEmpty) {
        throw const ValidationAppException('No existe ningún usuario registrado con ese correo.',);
      }

      if (sharedUserId == userId) {
        throw const ValidationAppException(
          'No puedes compartir el dispositivo contigo mismo.',
        );
      }

      final existingResponse = await _client
          .from('device_shares')
          .select('id, status')
          .eq('device_id', normalizedDeviceId)
          .eq('shared_with_user_id', sharedUserId);

      final existingRows = (existingResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      for (final row in existingRows) {
        final status = (row['status'] ?? '').toString();

        if (status == 'pending' || status == 'accepted') {
          throw const ValidationAppException(
            'Ese usuario ya tiene acceso o ya fue invitado.',
          );
        }
      }

      Map<String, dynamic>? reusableRow;
      for (final row in existingRows) {
        final status = (row['status'] ?? '').toString();
        if (status == 'revoked' || status == 'rejected') {
          reusableRow = row;
          break;
        }
      }

      if (reusableRow != null) {
        await _client
            .from('device_shares')
            .update({
          'owner_id': userId,
          'shared_with_email': normalizedEmail,
          'status': 'pending',
          'accepted_at': null,
          'revoked_at': null,
        })
            .eq('id', (reusableRow['id'] ?? '').toString());
        return;
      }

      await _client.from('device_shares').insert({
        'device_id': normalizedDeviceId,
        'owner_id': userId,
        'shared_with_user_id': sharedUserId,
        'shared_with_email': normalizedEmail,
        'status': 'pending',
      });
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> revokeDeviceShare(String shareId) async {
    try {
      final userId = _requireUserId();
      final normalizedId = shareId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un acceso compartido válido.',
        );
      }

      await _client
          .from('device_shares')
          .update({
        'status': 'revoked',
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
      })
          .match({
        'id': normalizedId,
        'owner_id': userId,
      });
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> leaveSharedDevice(String shareId) async {
    try {
      final userId = _requireUserId();
      final normalizedId = shareId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un acceso compartido válido.',
        );
      }

      await _client
          .from('device_shares')
          .update({
        'status': 'revoked',
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
      })
          .match({
        'id': normalizedId,
        'shared_with_user_id': userId,
      });
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
      final normalizedId = deviceId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un identificador válido del dispositivo.',
        );
      }

      final response = await _client
          .from('incidents')
          .select('id')
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
        throw const ValidationAppException('No se ha encontrado un identificador válido del dispositivo.');
      }

      final response = await _client
          .from('incidents')
          .select()
          .eq('device_id', normalizedId)
          .eq('is_resolved', false)
          .order('ts', ascending: false);

      final rows = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

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

      final cleanTypes = types
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      if (cleanTypes.isEmpty) {
        return <Map<String, dynamic>>[];
      }

      final response = await _client
          .from('incidents')
          .select()
          .eq('device_id', normalizedId)
          .eq('is_resolved', false)
          .inFilter('type', cleanTypes)
          .order('ts', ascending: false);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> acknowledgeIncident(String incidentId) async {
    try {
      final normalizedId = incidentId.trim();
      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado una incidencia válida.',
        );
      }

      await _client
          .from('incidents')
          .update({'is_acknowledged': true})
          .eq('id', normalizedId);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> resolveIncident(String incidentId) async {
    try {
      final normalizedId = incidentId.trim();
      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado una incidencia válida.',
        );
      }

      await _client
          .from('incidents')
          .update({'is_resolved': true})
          .eq('id', normalizedId);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> resolveIncidents(List<String> incidentIds) async {
    try {
      final ids = incidentIds
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      if (ids.isEmpty) return;

      await _client
          .from('incidents')
          .update({'is_resolved': true})
          .inFilter('id', ids);
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

      final row = await _client
          .from('devices')
          .select('id')
          .eq('identifier', normalizedIdentifier)
          .maybeSingle();

      if (row == null) return null;
      return (row['id'] ?? '').toString().trim().isEmpty
          ? null
          : (row['id'] ?? '').toString();
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
        throw const ValidationAppException('No se ha encontrado un identificador válido del dispositivo.');
      }

      await _client.from('incidents').insert({
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

  Future<void> deleteAutomation(String automationId) async {
    try {
      final userId = _requireUserId();
      final normalizedId = automationId.trim();

      if (automationId.trim().isEmpty) {
        throw const ValidationAppException(DevicesPanelStrings.notValidIndentifier);
      }

      await _client
          .from('device_automations')
          .delete()
          .match({'id': normalizedId, 'owner_id': userId});
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> fetchReadingsRange({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    int limit = 10000,
  }) async {
    try {
      final normalizedDeviceId = deviceId.trim();

      if (normalizedDeviceId.isEmpty) {
        throw const ValidationAppException('No se ha encontrado un identificador válido del dispositivo.');
      }

      final response = await _client
          .from('readings')
          .select('ts, power_w, voltage_v, energy_wh')
          .eq('device_id', normalizedDeviceId)
          .gte('ts', from.toUtc().toIso8601String())
          .lte('ts', to.toUtc().toIso8601String())
          .order('ts', ascending: true)
          .limit(limit);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const ValidationAppException(AuthStrings.notAutenticated);
    }
    return userId;
  }
}