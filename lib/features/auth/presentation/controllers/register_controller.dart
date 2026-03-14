import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/usecases/sign_up_create_profile.dart';

class RegisterController extends ChangeNotifier {
  final SignUpCreateProfile signUpAndCreateProfile;

  RegisterController(this.signUpAndCreateProfile);

  bool isLoading = false;
  String? errorMessages;

  bool get loading => isLoading;
  String? get errorMessage => errorMessages;

  factory RegisterController.create() {
    final client = Supabase.instance.client;
    final datasource = AuthRemoteDatasource(client);
    final repository = AuthRepositoryImpl(datasource);
    final useCase = SignUpCreateProfile(repository);

    return RegisterController(useCase);
  }

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
        email: email.trim(),
        password: password,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
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