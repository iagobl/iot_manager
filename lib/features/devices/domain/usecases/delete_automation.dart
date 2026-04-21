import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class DeleteAutomation {
  DeleteAutomation(this.repository);

  final DevicesRepository repository;

  Future<void> call(String automationId) {
    return repository.deleteAutomation(automationId);
  }
}
