import 'package:iot_manager/features/profile/domain/entities/profile_entity.dart';
import 'package:iot_manager/features/profile/domain/repositories/profile_repository.dart';

class GetCurrentProfile {
  const GetCurrentProfile(this.repository);

  final ProfileRepository repository;

  Future<ProfileEntity> call() {return repository.fetchCurrentProfile();}
}