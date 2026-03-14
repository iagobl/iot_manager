import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/usecases/reset_password.dart';

class ForgotPasswordController extends ChangeNotifier {
  final ResetPassword resetPassword;

  ForgotPasswordController(this.resetPassword);

  bool isLoading = false;
  String? errorMessages;

  bool get loading => isLoading;
  String? get errorMessage => errorMessages;

  factory ForgotPasswordController.create() {
    final client = Supabase.instance.client;
    final datasource = AuthRemoteDatasource(client);
    final repository = AuthRepositoryImpl(datasource);
    final useCase = ResetPassword(repository);

    return ForgotPasswordController(useCase);
  }

  Future<bool> sendRecoveryEmail({
    required String email,
  }) async {
    setLoading(true);
    clearError();

    try {
      await resetPassword(email.trim());
      return true;
    } on AppFailure catch (e) {
      setError(e.message);
      return false;
    } catch (_) {
      setError('Error inesperado al enviar el correo de recuperación.');
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