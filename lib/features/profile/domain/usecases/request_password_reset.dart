import 'package:iot_manager/features/profile/domain/repositories/profile_repository.dart';

class RequestPasswordReset {
  const RequestPasswordReset(this.repository);

  final ProfileRepository repository;

  Future<void> call({
    required String email,
    String? redirectTo,
  }) {
    return repository.requestPasswordReset(
      email: email,
      redirectTo: redirectTo,
    );
  }
}
