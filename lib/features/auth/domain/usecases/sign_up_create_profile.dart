import 'package:iot_manager/features/auth/domain/repositories/auth_repository.dart';

class SignUpCreateProfile {

  SignUpCreateProfile(this.repository);
  final AuthRepository repository;

  Future<void> call({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) {
    return repository.signUpCreateProfile(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
  }
}