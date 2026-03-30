import 'package:iot_manager/features/profile/domain/repositories/profile_repository.dart';

class UpdateBasicProfile {
  const UpdateBasicProfile(this.repository);

  final ProfileRepository repository;

  Future<void> call({
    required String firstName,
    required String lastName,
    required String email,
  }) {
    return repository.updateBasicProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
    );
  }
}