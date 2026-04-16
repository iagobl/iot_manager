import 'package:iot_manager/features/auth/domain/entities/auth_email_request.dart';
import 'package:iot_manager/features/auth/domain/repositories/auth_repository.dart';

class ResetPassword {
  ResetPassword(this.repository);
  final AuthRepository repository;

  Future<void> call(AuthEmailRequest request) {
    return repository.resetPassword(request);
  }
}
