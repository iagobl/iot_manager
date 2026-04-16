import 'dart:async';

import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/auth/data/models/auth_profile_model.dart';
import 'package:iot_manager/features/auth/domain/entities/auth_credentials.dart';
import 'package:iot_manager/features/auth/domain/entities/auth_email_request.dart';
import 'package:iot_manager/features/auth/domain/entities/auth_registration.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemoteDatasource {
  AuthRemoteDatasource(this._client);

  final SupabaseClient _client;

  Future<void> signIn(AuthCredentials credentials) async {
    try {
      await _client.auth.signInWithPassword(
        email: credentials.email.trim(),
        password: credentials.password,
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TimeoutAppException(
        'La operación tardó demasiado. Revisa la conexión.',
      );
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<void> signUpCreateProfile(AuthRegistration registration) async {
    try {
      final res = await _client.auth.signUp(
        email: registration.email.trim(),
        password: registration.password,
      ).timeout(const Duration(seconds: 15));

      final userId = res.user?.id ?? _client.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthAppException(
          'No se pudo obtener el ID del usuario.',
        );
      }

      final profileModel = AuthProfileModel(
        id: userId,
        firstName: registration.firstName,
        lastName: registration.lastName,
        email: registration.email,
      );

      await _client
          .from('profiles')
          .upsert(profileModel.toMap())
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TimeoutAppException(
        'La operación tardó demasiado. Revisa la conexión.',
      );
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<void> resetPassword(AuthEmailRequest request) async {
    try {
      await _client.auth
          .resetPasswordForEmail(request.email.trim())
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
