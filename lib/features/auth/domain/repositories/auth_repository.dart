abstract class AuthRepository {
  Future<void> signIn({
    required String email,
    required String password,
  });

  Future<void> signUpCreateProfile({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  });

  Future<void> resetPassword(String email);

  Future<void> signOut();
}