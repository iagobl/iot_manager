import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:iot_manager/features/auth/domain/entities/auth_credentials.dart';
import 'package:iot_manager/features/auth/domain/entities/auth_email_request.dart';
import 'package:iot_manager/features/auth/domain/entities/auth_registration.dart';
import 'package:iot_manager/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this.remoteDatasource);

  final AuthRemoteDatasource remoteDatasource;

  @override
  Future<void> signIn(AuthCredentials credentials) async {
    try {
      await remoteDatasource.signIn(credentials);
    } catch (e) {
      throw ErrorMapper.mapFailure(e);
    }
  }

  @override
  Future<void> signUpCreateProfile(AuthRegistration registration) async {
    try {
      await remoteDatasource.signUpCreateProfile(registration);
    } catch (e) {
      throw ErrorMapper.mapFailure(e);
    }
  }

  @override
  Future<void> resetPassword(AuthEmailRequest request) async {
    try {
      await remoteDatasource.resetPassword(request);
    } catch (e) {
      throw ErrorMapper.mapFailure(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await remoteDatasource.signOut();
    } catch (e) {
      throw ErrorMapper.mapFailure(e);
    }
  }
}
