import 'package:iot_manager/features/profile/domain/repositories/profile_repository.dart';

class CreateAvatarSignedUrl {
  const CreateAvatarSignedUrl(this.repository);

  final ProfileRepository repository;

  Future<String?> call(String? path) {
    return repository.createAvatarSignedUrl(path);
  }
}