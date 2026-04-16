import 'package:iot_manager/features/auth/domain/entities/auth_credentials.dart';
import 'package:iot_manager/features/auth/domain/repositories/auth_repository.dart';

class SignIn {
  SignIn(this.repository);

  final AuthRepository repository;

  Future<void> call(AuthCredentials credentials) {
    return repository.signIn(credentials);
  }
}
