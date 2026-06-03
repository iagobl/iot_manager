import 'dart:typed_data';

import 'package:iot_manager/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:iot_manager/features/profile/data/models/profile_model.dart';
import 'package:iot_manager/features/profile/domain/entities/profile_entity.dart';
import 'package:iot_manager/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({ProfileRemoteDatasource? remoteDatasource})
      : remoteDatasource = remoteDatasource ?? ProfileRemoteDatasource();

  final ProfileRemoteDatasource remoteDatasource;

  @override
  Future<ProfileEntity> fetchCurrentProfile() async {
    final row = await remoteDatasource.fetchCurrentProfile();
    final model = ProfileModel.fromMap(row);

    final avatarSignedUrl = model.avatarPath == null ? null
        : await remoteDatasource.createAvatarSignedUrl(model.avatarPath);

    return model.copyWithModel(avatarSignedUrl: avatarSignedUrl);
  }

  @override
  Future<void> updateBasicProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) {
    return remoteDatasource.updateBasicProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
    );
  }

  @override
  Future<void> updateUnitPreferences(Map<String, dynamic> preferences) {
    return remoteDatasource.updateUnitPreferences(preferences);
  }

  @override
  Future<String> uploadAvatar({required Uint8List bytes, required String extension}) {
    return remoteDatasource.uploadAvatar(bytes: bytes, extension: extension);
  }

  @override
  Future<String?> createAvatarSignedUrl(String? path) {
    return remoteDatasource.createAvatarSignedUrl(path);
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    return remoteDatasource.changePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  @override
  Future<void> requestPasswordReset({required String email, String? redirectTo}) {
    return remoteDatasource.requestPasswordReset(email: email, redirectTo: redirectTo);
  }
}
