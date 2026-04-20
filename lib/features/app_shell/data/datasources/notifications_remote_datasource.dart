import 'dart:async';

import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsRemoteDatasource {
  NotificationsRemoteDatasource({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  StreamController<void>? notificationsController;
  RealtimeChannel? deviceSharesChannel;
  RealtimeChannel? incidentsChannel;

  Future<List<Map<String, dynamic>>> getPendingInvitations() async {
    try {
      final userId = requireUserId();

      final response = await _client.from('device_shares').select(
        'id, device_id, owner_id, shared_with_email, shared_with_user_id, created_at, status',
      )
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
        final devicesResponse = await _client.from('devices')
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
        final ownersResponse = await _client.from('profiles')
            .select('id, first_name, last_name, email').inFilter('id', ownerIds);

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
        throw const ValidationAppException('No se ha encontrado una invitación válida.');
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
      final userId = requireUserId();
      final normalizedId = shareId.trim();

      if (normalizedId.isEmpty) {
        throw const ValidationAppException('No se ha encontrado una invitación válida.');
      }

      await _client.from('device_shares').update({'status': 'rejected',}).match({
        'id': normalizedId,
        'shared_with_user_id': userId,
      });
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> getUnreadIncidentNotifications() async {
    try {
      final userId = requireUserId();

      final ownedDevicesResponse = await _client.from('devices')
          .select('id, name, device_type, home_id').eq('owner_id', userId);

      final ownedDevices = (ownedDevicesResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();

      final sharedRowsResponse = await _client
          .from('device_shares')
          .select('device_id')
          .eq('shared_with_user_id', userId)
          .eq('status', 'accepted');

      final sharedRows = (sharedRowsResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();

      final sharedDeviceIds = sharedRows
          .map((row) => (row['device_id'] ?? '')
          .toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final List<Map<String, dynamic>> sharedDevices = [];
      if (sharedDeviceIds.isNotEmpty) {
        final sharedDevicesResponse = await _client
            .from('devices')
            .select('id, name, device_type, home_id')
            .inFilter('id', sharedDeviceIds);

        sharedDevices.addAll((sharedDevicesResponse as List)
            .map((item) => Map<String, dynamic>.from(item as Map)));
      }

      final allDevices = <Map<String, dynamic>>[
        ...ownedDevices,
        ...sharedDevices,
      ];

      if (allDevices.isEmpty) {
        return <Map<String, dynamic>>[];
      }

      final deviceById = <String, Map<String, dynamic>>{
        for (final row in allDevices) (row['id'] ?? '').toString(): row,
      };

      final deviceIds = deviceById.keys.where((id) => id.isNotEmpty).toList();

      if (deviceIds.isEmpty) {
        return <Map<String, dynamic>>[];
      }

      final incidentsResponse = await _client
          .from('incidents')
          .select(
        'id, device_id, home_id, ts, type, severity, message, is_acknowledged, is_resolved',
      )
          .inFilter('device_id', deviceIds)
          .eq('is_acknowledged', false)
          .order('ts', ascending: false);

      final rows = (incidentsResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();

      return rows.map((row) {
        final deviceId = (row['device_id'] ?? '').toString();
        final device = deviceById[deviceId];

        return {
          ...row,
          'device_name': (device?['name'] ?? 'Dispositivo').toString(),
          'device_type': (device?['device_type'] ?? '').toString(),
          'home_id': (row['home_id'] ?? device?['home_id'] ?? '').toString(),
        };
      }).toList();
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

      await _client.from('incidents').update({'is_acknowledged': true}).eq('id', normalizedId);
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Stream<void> watchNotificationEvents() {
    notificationsController ??= StreamController<void>.broadcast(
      onListen: () {
        unawaited(ensureRealtimeListeners());
      },
      onCancel: () {
        unawaited(disposeRealtimeListeners());
      },
    );

    return notificationsController!.stream;
  }

  Future<void> ensureRealtimeListeners() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return;
    }

    if (deviceSharesChannel != null || incidentsChannel != null) {
      return;
    }

    deviceSharesChannel = _client
        .channel('app-shell-device-shares-$userId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'device_shares',
      callback: (payload) {
        final newRecord = payload.newRecord;
        final oldRecord = payload.oldRecord;

        final sharedWithUserId = (newRecord['shared_with_user_id'] ??
            oldRecord['shared_with_user_id'] ?? '').toString();

        final ownerId = (newRecord['owner_id'] ?? oldRecord['owner_id'] ?? '')
            .toString();

        if (sharedWithUserId == userId || ownerId == userId) {
          emitNotificationEvent();
        }
      },
    )
        .subscribe();

    incidentsChannel = _client.channel('app-shell-incidents-$userId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'incidents',
      callback: (_) {emitNotificationEvent();},
    ).subscribe();
  }

  Future<void> disposeRealtimeListeners() async {
    final futures = <Future<dynamic>>[];

    if (deviceSharesChannel != null) {
      futures.add(_client.removeChannel(deviceSharesChannel!));
      deviceSharesChannel = null;
    }

    if (incidentsChannel != null) {
      futures.add(_client.removeChannel(incidentsChannel!));
      incidentsChannel = null;
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  void emitNotificationEvent() {
    final controller = notificationsController;
    if (controller == null || controller.isClosed) {
      return;
    }

    controller.add(null);
  }

  Future<void> disposeWatcher() async {
    await disposeRealtimeListeners();
    await notificationsController?.close();
    notificationsController = null;
  }

  String requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const ValidationAppException('Debes iniciar sesión para continuar.');
    }
    return userId;
  }
}
