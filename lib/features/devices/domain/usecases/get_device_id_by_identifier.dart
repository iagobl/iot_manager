import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class GetDeviceIdByIdentifier {
  GetDeviceIdByIdentifier(this.repository);

  final DevicesRepository repository;

  Future<String?> call(String identifier) {
    return repository.getDeviceIdByIdentifier(identifier);
  }
}
