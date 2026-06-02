import 'dart:async';

import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeRemoteDatasource {
  HomeRemoteDatasource(this._client);
  final SupabaseClient _client;

  SupabaseClient get client => _client;

  Future<Map<String, dynamic>> getOverview() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthAppException('No hay una sesión activa.');
      }

      final profileFuture = _client
          .from('profiles')
          .select('first_name')
          .eq('id', userId)
          .maybeSingle();

      final homesFuture = _client
          .from('homes')
          .select('id, name, owner_id, created_at')
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      final devicesFuture = _client
          .from('devices')
          .select(
        'id, home_id, name, device_type, protocol, identifier, '
            'is_active, energy_today_wh, created_at',
      )
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      final results = await Future.wait([
        profileFuture,
        homesFuture,
        devicesFuture,
      ]).timeout(const Duration(seconds: 15));

      return {
        'profile': results[0],
        'homes': results[1],
        'devices': results[2],
      };
    } on TimeoutException {
      throw const TimeoutAppException(
        'La operación tardó demasiado. Revisa la conexión.',
      );
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<void> createHome({
    required String name,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthAppException('No hay una sesión activa.');
      }

      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        throw const ValidationAppException('Introduce un nombre para el hogar.');
      }

      await _client.from('homes').insert({
        'owner_id': userId,
        'name': trimmedName,
      }).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TimeoutAppException(
        'La operación tardó demasiado. Revisa la conexión.',
      );
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<void> deleteHome({
    required String homeId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthAppException('No hay una sesión activa.');
      }

      if (homeId.trim().isEmpty) {
        throw const ValidationAppException('Identificador de hogar no válido.');
      }

      await _client
          .from('homes')
          .delete()
          .eq('id', homeId)
          .eq('owner_id', userId)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TimeoutAppException(
        'La operación tardó demasiado. Revisa la conexión.',
      );
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }
}
