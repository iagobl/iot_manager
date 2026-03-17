import 'package:iot_manager/features/auth/domain/repositories/auth_repository.dart';

class SignIn {

  SignIn(this.repository);
  final AuthRepository repository;

  Future<void> call({
    required String email,
    required String password,
  }) {
    return repository.signIn(
      email: email,
      password: password,
    );
  }
}