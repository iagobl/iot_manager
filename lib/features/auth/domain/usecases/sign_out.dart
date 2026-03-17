import 'package:iot_manager/features/auth/domain/repositories/auth_repository.dart';

class SignOut {

  SignOut(this.repository);
  final AuthRepository repository;

  Future<void> call() {
    return repository.signOut();
  }
}