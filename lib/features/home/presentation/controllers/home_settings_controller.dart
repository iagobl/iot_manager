import 'package:iot_manager/features/home/data/repositories/home_safety_repository_impl.dart';
import 'package:iot_manager/features/home/data/repositories/home_share_repository_impl.dart';
import 'package:iot_manager/features/home/domain/entities/home_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeSettingsController {
  HomeSettingsController({
    required this.home,
  });

  final HomeSummary home;
  final SupabaseClient _client = Supabase.instance.client;
  final HomeSafetyRepositoryImpl safetyRepository = HomeSafetyRepositoryImpl();
  final HomeShareRepositoryImpl shareRepository = HomeShareRepositoryImpl();

  Map<String, dynamic>? securitySettings;
  Function()? onUpdate;

  Future<void> init({required Function() onUpdate,}) async {
    this.onUpdate = onUpdate;
    securitySettings = await safetyRepository.getSafetySettings(home.id);
    notify();
  }

  bool get isOwner {
    final currentUserId = _client.auth.currentUser?.id;
    return currentUserId != null && home.ownerId == currentUserId;
  }

  Future<void> updateHomeName(String newName) async {
    final trimmedName = newName.trim();

    if (trimmedName.isEmpty) {
      throw Exception('El nombre no puede estar vacío.');
    }

    await _client.from('homes').update({'name': trimmedName}).eq('id', home.id);
    home.name = trimmedName;
    notify();
  }

  Future<void> saveSafetySettings({double? maxTotalConsumptionWh}) async {
    await safetyRepository.upsertSafetySettings(homeId: home.id,
      maxTotalConsumptionWh: maxTotalConsumptionWh,
    );

    securitySettings = await safetyRepository.getSafetySettings(home.id);
    notify();
  }

  Future<void> shareHomeByEmail(String email) async {
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      throw Exception('Introduce un correo válido.');
    }

    await shareRepository.shareHomeByEmail(
      homeId: home.id,
      homeOwnerId: home.ownerId,
      email: trimmedEmail,
    );
  }

  Future<void> leaveSharedHome() async {
    await shareRepository.leaveSharedHome(homeId: home.id);
  }

  void notify() {
    onUpdate?.call();
  }
}