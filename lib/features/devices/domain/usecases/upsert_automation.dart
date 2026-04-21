import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class UpsertAutomation {
  UpsertAutomation(this.repository);

  final DevicesRepository repository;

  Future<void> call({
    String? id,
    required String deviceId,
    required String type,
    required bool enabled,
    required Map<String, dynamic> config,
  }) {
    return repository.upsertAutomation(
      id: id,
      deviceId: deviceId,
      type: type,
      enabled: enabled,
      config: config,
    );
  }
}
