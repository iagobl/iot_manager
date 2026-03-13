import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemoteDatasource {
  final SupabaseClient _client;

  AuthRemoteDatasource(this._client);

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUpCreateProfile({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final userId = res.user?.id ?? _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No se pudo obtener el ID del usuario.');
    }

    await _client.from('profiles').upsert({
      'id': userId,
      'email': email.trim().toLowerCase(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
    });
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}