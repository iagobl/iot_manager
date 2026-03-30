import 'dart:typed_data';

import 'package:iot_manager/features/profile/domain/repositories/profile_repository.dart';

class UploadAvatar {
  const UploadAvatar(this.repository);

  final ProfileRepository repository;

  Future<String> call({
    required Uint8List bytes,
    required String extension,
  }) {
    return repository.uploadAvatar(
      bytes: bytes,
      extension: extension,
    );
  }
}