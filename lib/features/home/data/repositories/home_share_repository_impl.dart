import 'package:iot_manager/features/home/data/datasources/home_share_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class HomeShareRepositoryImpl {
  final HomeShareRemoteDataSource remote = HomeShareRemoteDataSource();
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> shareHomeByEmail({
    required String homeId,
    required String homeOwnerId,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw Exception('El correo introducido no es válido.');
    }

    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('No hay una sesión activa.');
    }

    final profile = await remote.getProfileByEmail(normalizedEmail);

    if (profile == null) {
      throw Exception('No existe ningún usuario con ese correo.');
    }

    final targetUserId = profile['id'] as String;

    if (targetUserId == currentUser.id) {
      throw Exception('No puedes compartir el hogar contigo mismo.');
    }

    await remote.createHomeShareInvitation(
      homeId: homeId,
      ownerId: homeOwnerId,
      sharedWithUserId: targetUserId,
      sharedWithEmail: normalizedEmail,
    );
  }

  Future<void> leaveSharedHome({
    required String homeId,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('No hay una sesión activa.');
    }

    await remote.leaveSharedHome(
      homeId: homeId,
      userId: currentUser.id,
    );
  }
}