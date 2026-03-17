import 'package:iot_manager/features/auth/domain/repositories/auth_repository.dart';

class ResetPassword {

  ResetPassword(this.repository);
  final AuthRepository repository;

  Future<void> call(String email) {
    return repository.resetPassword(email);
  }
}