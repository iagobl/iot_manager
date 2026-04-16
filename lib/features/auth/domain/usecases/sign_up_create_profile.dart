import 'package:iot_manager/features/auth/domain/entities/auth_registration.dart';
import 'package:iot_manager/features/auth/domain/repositories/auth_repository.dart';

class SignUpCreateProfile {
  SignUpCreateProfile(this.repository);

  final AuthRepository repository;

  Future<void> call(AuthRegistration registration) {
    return repository.signUpCreateProfile(registration);
  }
}
