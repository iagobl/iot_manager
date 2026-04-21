import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class GetProfilesByIds {
  GetProfilesByIds(this.repository);

  final DevicesRepository repository;

  Future<List<Map<String, dynamic>>> call(List<String> ids) {
    return repository.getProfilesByIds(ids);
  }
}
