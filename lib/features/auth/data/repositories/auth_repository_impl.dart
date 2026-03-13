import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource remoteDatasource;

  AuthRepositoryImpl(this.remoteDatasource);

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) {
    return remoteDatasource.signIn(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signUpCreateProfile({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) {
    return remoteDatasource.signUpCreateProfile(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
  }

  @override
  Future<void> resetPassword(String email) {
    return remoteDatasource.resetPassword(email);
  }

  @override
  Future<void> signOut() {
    return remoteDatasource.signOut();
  }
}