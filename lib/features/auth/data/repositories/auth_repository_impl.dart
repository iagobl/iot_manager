import '../../../../core/error/app_failure.dart';
import '../../../../core/error/error_mapper.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource remoteDatasource;

  AuthRepositoryImpl(this.remoteDatasource);

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await remoteDatasource.signIn(
        email: email,
        password: password,
      );
    } catch (e) {
      throw ErrorMapper.mapFailure(e);
    }
  }

  @override
  Future<void> signUpCreateProfile({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      await remoteDatasource.signUpCreateProfile(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
    } catch (e) {
      throw ErrorMapper.mapFailure(e);
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await remoteDatasource.resetPassword(email);
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