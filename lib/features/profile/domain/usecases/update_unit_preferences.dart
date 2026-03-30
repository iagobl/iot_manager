import 'package:iot_manager/features/profile/domain/repositories/profile_repository.dart';

class UpdateUnitPreferences {
  const UpdateUnitPreferences(this.repository);

  final ProfileRepository repository;

  Future<void> call(Map<String, dynamic> preferences) {
    return repository.updateUnitPreferences(preferences);
  }
}