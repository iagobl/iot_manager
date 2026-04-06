import 'package:supabase_flutter/supabase_flutter.dart';

class HomeShareRemoteDataSource {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> getProfileByEmail(String email) async {
    final response = await _client.from('profiles')
        .select()
        .ilike('email', email).maybeSingle();

    if (response == null) return null;
    return Map<String, dynamic>.from(response);
  }

  Future<void> createHomeShareInvitation({
    required String homeId,
    required String ownerId,
    required String sharedWithUserId,
    required String sharedWithEmail,
  }) async {
    final existing = await _client.from('home_shares')
        .select()
        .eq('home_id', homeId)
        .eq('shared_with_user_id', sharedWithUserId)
        .maybeSingle();

    if (existing != null) {
      final existingStatus = existing['status']?.toString();

      if (existingStatus == 'accepted') {
        throw Exception('Ese usuario ya tiene acceso a este hogar.');
      }

      await _client.from('home_shares').update({
        'status': 'pending',
        'revoked_at': null,
        'accepted_at': null,
        'shared_with_email': sharedWithEmail,
      }).eq('id', existing['id']);
      return;
    }

    await _client.from('home_shares').insert({
      'home_id': homeId,
      'owner_id': ownerId,
      'shared_with_user_id': sharedWithUserId,
      'shared_with_email': sharedWithEmail,
      'status': 'pending',
    });
  }

  Future<void> leaveSharedHome({required String homeId, required String userId}) async {
    final existing = await _client
        .from('home_shares')
        .select()
        .eq('home_id', homeId)
        .eq('shared_with_user_id', userId)
        .eq('status', 'accepted')
        .maybeSingle();

    if (existing == null) {
      throw Exception('No tienes acceso compartido a este hogar.');
    }

    await _client.from('home_shares').update({
      'status': 'revoked',
      'revoked_at': DateTime.now().toIso8601String(),
    }).eq('id', existing['id']);
  }
}