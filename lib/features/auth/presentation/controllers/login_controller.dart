import 'package:flutter/foundation.dart';

import 'package:iot_manager/core/error/app_failure.dart';
import 'package:iot_manager/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:iot_manager/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:iot_manager/features/auth/domain/entities/auth_credentials.dart';
import 'package:iot_manager/features/auth/domain/usecases/sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginController extends ChangeNotifier {
  factory LoginController.create() {
    final client = Supabase.instance.client;
    final datasource = AuthRemoteDatasource(client);
    final repository = AuthRepositoryImpl(datasource);
    final signInUseCase = SignIn(repository);

    return LoginController(signInUseCase);
  }

  LoginController(this.signIn);
  final SignIn signIn;

  bool isLoading = false;
  String? errorMessages;

  bool get loading => isLoading;
  String? get errorMessage => errorMessages;

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    setLoading(true);
    clearError();

    try {
      await signIn(
        AuthCredentials(
          email: email.trim(),
          password: password,
        ),
      );
      return true;
    } on AppFailure catch (e) {
      setError(e.message);
      return false;
    } catch (_) {
      setError('Error inesperado al iniciar sesión.');
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
