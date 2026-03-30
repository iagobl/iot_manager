import 'dart:typed_data';

import 'package:iot_manager/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<ProfileEntity> fetchCurrentProfile();

  Future<void> updateBasicProfile({
    required String firstName,
    required String lastName,
    required String email,
  });

  Future<void> updateUnitPreferences(Map<String, dynamic> preferences);

  Future<void> updateNotificationPreferences(Map<String, dynamic> preferences);

  Future<String> uploadAvatar({required Uint8List bytes, required String extension});

  Future<String?> createAvatarSignedUrl(String? path);

  Future<void> changePassword({required String currentPassword, required String newPassword});
}