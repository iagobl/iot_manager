import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class FetchAutomations {
  FetchAutomations(this.repository);

  final DevicesRepository repository;

  Future<List<Map<String, dynamic>>> call({required String deviceId, required String type}) {
    return repository.fetchAutomations(deviceId: deviceId, type: type);
  }
}
