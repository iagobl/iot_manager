import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/device_datasource_shared.dart';

class DeviceSharesRemoteDatasource with DeviceDatasourceShared {
  Future<int> getPendingInvitationsCount() async {
    try {
      final userId = requireUserId();

      final response = await client.from('device_shares').select('id')
          .eq('shared_with_user_id', userId)
          .eq('status', 'pending');

      return (response as List).length;
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> getPendingInvitations() async {
    try {
      final userId = requireUserId();

      final response = await client.from('device_shares')
          .select('id, device_id, owner_id, shared_with_email, created_at, status')
          .eq('shared_with_user_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final rows = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();

      if (rows.isEmpty) return rows;

      final deviceIds = rows.map((e) => (e['device_id'] ?? '').toString())
          .where((e) => e.isNotEmpty).toSet().toList();

      final ownerIds = rows.map((e) => (e['owner_id'] ?? '').toString())
          .where((e) => e.isNotEmpty).toSet().toList();

      final deviceNames = <String, String>{};
      final deviceTypes = <String, String>{};
      final ownerNames = <String, String>{};

      if (deviceIds.isNotEmpty) {
        final devicesResponse = await client.from('devices')
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
        final ownersResponse = await client.from('profiles')
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
      final userId = requireUserId();
      final normalizedId = shareId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException('No se ha encontrado una invitación válida');
      }

      await client.from('device_shares').update({
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
      final userId = requireUserId();
      final normalizedId = shareId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException('No se ha encontrado una invitación válida');
      }

      await client.from('device_shares').update({
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

      return await client.from('devices').select('id, owner_id, name')
          .eq('id', normalizedId).maybeSingle();
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

      final response = await client.from('device_shares').select()
          .eq('device_id', normalizedId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> getProfilesByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return <Map<String, dynamic>>[];

      final cleanIds = ids.map((e) => e.trim())
          .where((e) => e.isNotEmpty).toSet().toList();

      if (cleanIds.isEmpty) return <Map<String, dynamic>>[];

      final response = await client.from('profiles')
          .select('id, first_name, last_name, email')
          .inFilter('id', cleanIds);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> inviteDeviceShareByEmail({
    required String deviceId,
    required String email,
  }) async {
    try {
      final userId = requireUserId();
      final normalizedDeviceId = deviceId.trim();
      final normalizedEmail = email.trim().toLowerCase();

      if (normalizedDeviceId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un identificador válido del dispositivo.',
        );
      }

      if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
        throw const ValidationAppException('Introduce un correo válido.');
      }

      final deviceRow = await client.from('devices').select('id, owner_id')
          .eq('id', normalizedDeviceId).maybeSingle();

      if (deviceRow == null) {
        throw const ValidationAppException('No se encontró el dispositivo.');
      }

      final ownerId = (deviceRow['owner_id'] ?? '').toString();
      if (ownerId != userId) {
        throw const ValidationAppException(
          'Solo el propietario puede compartir este dispositivo.',
        );
      }

      final profileResponse = await client.from('profiles').select('id, email')
          .eq('email', normalizedEmail);

      final profiles = (profileResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();

      if (profiles.isEmpty) {
        throw const ValidationAppException(
          'No existe ningún usuario registrado con ese correo.',
        );
      }

      final sharedUserId = (profiles.first['id'] ?? '').toString();
      if (sharedUserId.isEmpty) {
        throw const ValidationAppException(
          'No existe ningún usuario registrado con ese correo.',
        );
      }

      if (sharedUserId == userId) {
        throw const ValidationAppException(
          'No puedes compartir el dispositivo contigo mismo.',
        );
      }

      final existingResponse = await client.from('device_shares')
          .select('id, status')
          .eq('device_id', normalizedDeviceId)
          .eq('shared_with_user_id', sharedUserId);

      final existingRows = (existingResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();

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
        await client.from('device_shares').update({
          'owner_id': userId,
          'shared_with_email': normalizedEmail,
          'status': 'pending',
          'accepted_at': null,
          'revoked_at': null,
        }).eq('id', (reusableRow['id'] ?? '').toString());
        return;
      }

      await client.from('device_shares').insert({
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
      final userId = requireUserId();
      final normalizedId = shareId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un acceso compartido válido.',
        );
      }

      await client.from('device_shares').update({
        'status': 'revoked',
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
      }).match({
        'id': normalizedId,
        'owner_id': userId,
      });
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<void> leaveSharedDevice(String shareId) async {
    try {
      final userId = requireUserId();
      final normalizedId = shareId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException(
          'No se ha encontrado un acceso compartido válido.',
        );
      }

      await client.from('device_shares').update({
        'status': 'revoked',
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
      }).match({
        'id': normalizedId,
        'shared_with_user_id': userId,
      });
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }
}
