import 'package:iot_manager/features/profile/domain/repositories/profile_repository.dart';

class ChangePassword {
  const ChangePassword(this.repository);

  final ProfileRepository repository;

  Future<void> call({required String currentPassword, required String newPassword}) {
    return repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}