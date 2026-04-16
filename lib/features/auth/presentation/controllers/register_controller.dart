import 'package:flutter/foundation.dart';

import 'package:iot_manager/core/error/app_failure.dart';
import 'package:iot_manager/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:iot_manager/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:iot_manager/features/auth/domain/entities/auth_registration.dart';
import 'package:iot_manager/features/auth/domain/usecases/sign_up_create_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterController extends ChangeNotifier {
  factory RegisterController.create() {
    final client = Supabase.instance.client;
    final datasource = AuthRemoteDatasource(client);
    final repository = AuthRepositoryImpl(datasource);
    final useCase = SignUpCreateProfile(repository);

    return RegisterController(useCase);
  }

  RegisterController(this.signUpAndCreateProfile);
  final SignUpCreateProfile signUpAndCreateProfile;

  bool isLoading = false;
  String? errorMessages;

  bool get loading => isLoading;
  String? get errorMessage => errorMessages;

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    setLoading(true);
    clearError();

    try {
      await signUpAndCreateProfile(
        AuthRegistration(
          email: email.trim(),
          password: password,
          firstName: firstName.trim(),
          lastName: lastName.trim(),
        ),
      );
      return true;
    } on AppFailure catch (e) {
      setError(e.message);
      return false;
    } catch (_) {
      setError('Error inesperado al registrarse.');
      return false;
    } finally {
      setLoading(false);
    }
  }

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void setError(String message) {
    errorMessages = message;
    notifyListeners();
  }

  void clearError() {
    errorMessages = null;
    notifyListeners();
  }
}
