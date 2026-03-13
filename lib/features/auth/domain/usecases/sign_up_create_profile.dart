import '../repositories/auth_repository.dart';

class SignUpCreateProfile {
  final AuthRepository repository;

  SignUpCreateProfile(this.repository);

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