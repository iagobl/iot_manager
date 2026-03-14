import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/error_mapper.dart';

class DevicesRemoteDatasource {
  final SupabaseClient _client;

  DevicesRemoteDatasource(this._client);

  Future<List<dynamic>> getUserDevices() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthAppException('No hay una sesión activa.');
      }

      final response = await _client
          .from('devices')
          .select(
            'id, home_id, room_id, name, device_type, protocol, identifier, '
            'is_active, energy_today_wh, created_at',
          )
          .eq('owner_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      return response;
    } on TimeoutException {
      throw const TimeoutAppException(
        'La operación tardó demasiado. Revisa la conexión.',
      );
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }
}
