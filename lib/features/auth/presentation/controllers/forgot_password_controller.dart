import 'package:flutter/foundation.dart';

import 'package:iot_manager/core/error/app_failure.dart';
import 'package:iot_manager/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:iot_manager/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:iot_manager/features/auth/domain/entities/auth_email_request.dart';
import 'package:iot_manager/features/auth/domain/usecases/reset_password.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordController extends ChangeNotifier {
  ForgotPasswordController(this.resetPassword);

  factory ForgotPasswordController.create() {
    final client = Supabase.instance.client;
    final datasource = AuthRemoteDatasource(client);
    final repository = AuthRepositoryImpl(datasource);
    final useCase = ResetPassword(repository);

    return ForgotPasswordController(useCase);
  }

  final ResetPassword resetPassword;

  bool isLoading = false;
  String? errorMessages;

  bool get loading => isLoading;
  String? get errorMessage => errorMessages;

  Future<bool> sendRecoveryEmail({
    required String email,
  }) async {
    setLoading(true);
    clearError();

    try {
      await resetPassword(
        AuthEmailRequest(
          email: email.trim(),
        ),
      );
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
