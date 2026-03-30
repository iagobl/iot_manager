import 'dart:async';
import 'dart:typed_data';

import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRemoteDatasource {
  ProfileRemoteDatasource([SupabaseClient? client]) : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  User? get currentUser => client.auth.currentUser;

  Future<Map<String, dynamic>> fetchCurrentProfile() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw const AuthAppException('No hay ninguna sesión activa.');
      }

      final row = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));

      final merged = <String, dynamic>{
        'id': user.id,
        'first_name': row?['first_name'] ?? '',
        'last_name': row?['last_name'] ?? '',
        'email': row?['email'] ?? user.email ?? '',
        'avatar_url': row?['avatar_url'],
        'unit_preferences': row?['unit_preferences'] ??
            {
              'energy': 'kWh',
              'power': 'W',
              'voltage': 'V',
            },
        'notification_preferences': row?['notification_preferences'] ??
            {
              'incidents': true,
              'device_status': true,
              'sharing': true,
            },
      };

      return merged;
    } on TimeoutException {
      throw const TimeoutAppException('La operación tardó demasiado. Revisa la conexión.');
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<void> updateBasicProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw const AuthAppException('No hay ninguna sesión activa.');
      }

      final previousEmail = (user.email ?? '').trim();

      await client.from('profiles').update({
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': email.trim(),
      })
          .eq('id', user.id)
          .timeout(const Duration(seconds: 15));

      if (previousEmail.toLowerCase() != email.trim().toLowerCase()) {
        await client.auth.updateUser(
          UserAttributes(email: email.trim()),
        ).timeout(const Duration(seconds: 15));
      }
    } on TimeoutException {
      throw const TimeoutAppException('La operación tardó demasiado. Revisa la conexión.');
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<void> updateUnitPreferences(Map<String, dynamic> preferences) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw const AuthAppException('No hay ninguna sesión activa.');
      }

      await client.from('profiles').update({
        'unit_preferences': preferences,
      })
          .eq('id', user.id)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TimeoutAppException('La operación tardó demasiado. Revisa la conexión.');
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<void> updateNotificationPreferences(Map<String, dynamic> preferences) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw const AuthAppException('No hay ninguna sesión activa.');
      }

      await client.from('profiles').update({
        'notification_preferences': preferences,
      })
          .eq('id', user.id)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TimeoutAppException('La operación tardó demasiado. Revisa la conexión.');
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<String> uploadAvatar({required Uint8List bytes, required String extension}) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw const AuthAppException('No hay ninguna sesión activa.');
      }

      final safeExtension = extension.toLowerCase().replaceAll('.', '');
      final path = '${user.id}/avatar.$safeExtension';

      await client.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: contentTypeForExtension(safeExtension),
        ),
      );

      await client.from('profiles').update({'avatar_url': path})
          .eq('id', user.id)
          .timeout(const Duration(seconds: 15));

      return path;
    } on TimeoutException {
      throw const TimeoutAppException('La operación tardó demasiado. Revisa la conexión.');
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<String?> createAvatarSignedUrl(String? path) async {
    try {
      if (path == null || path.trim().isEmpty) {
        return null;
      }

      final signedUrl = await client.storage.from('avatars')
          .createSignedUrl(path, 3600)
          .timeout(const Duration(seconds: 15));

      return signedUrl;
    } on TimeoutException {
      throw const TimeoutAppException('La operación tardó demasiado. Revisa la conexión.');
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      final email = user?.email?.trim();

      if (user == null || email == null || email.isEmpty) {
        throw const AuthAppException('No se pudo verificar la sesión actual.');
      }

      await client.auth.signInWithPassword(email: email, password: currentPassword)
          .timeout(const Duration(seconds: 15));

      await client.auth.updateUser(UserAttributes(password: newPassword),)
          .timeout(const Duration(seconds: 15));

    } on TimeoutException {
      throw const TimeoutAppException('La operación tardó demasiado. Revisa la conexión.');
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }

  String contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}