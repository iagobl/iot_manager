import 'dart:async';

import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemoteDatasource {

  AuthRemoteDatasource(this._client);
  final SupabaseClient _client;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TimeoutAppException(
        'La operación tardó demasiado. Revisa la conexión.',
      );
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<void> signUpCreateProfile({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 15));

      final userId = res.user?.id ?? _client.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthAppException(
          'No se pudo obtener el ID del usuario.',
        );
      }

      await _client.from('profiles').upsert({
        'id': userId,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
      }).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TimeoutAppException(
        'La operación tardó demasiado. Revisa la conexión.',
      );
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth
          .resetPasswordForEmail(email.trim())
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TimeoutAppException(
        'La operación tardó demasiado. Revisa la conexión.',
      );
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TimeoutAppException(
        'La operación tardó demasiado. Revisa la conexión.',
      );
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }
}