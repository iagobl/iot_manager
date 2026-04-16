import 'package:iot_manager/features/auth/domain/entities/auth_credentials.dart';
import 'package:iot_manager/features/auth/domain/entities/auth_email_request.dart';
import 'package:iot_manager/features/auth/domain/entities/auth_registration.dart';

abstract class AuthRepository {
  Future<void> signIn(AuthCredentials credentials);

  Future<void> signUpCreateProfile(AuthRegistration registration);

  Future<void> resetPassword(AuthEmailRequest request);

  Future<void> signOut();
}
