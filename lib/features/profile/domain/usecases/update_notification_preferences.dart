import 'package:iot_manager/features/profile/domain/repositories/profile_repository.dart';

class UpdateNotificationPreferences {
  const UpdateNotificationPreferences(this.repository);

  final ProfileRepository repository;

  Future<void> call(Map<String, dynamic> preferences) {
    return repository.updateNotificationPreferences(preferences);
  }
}