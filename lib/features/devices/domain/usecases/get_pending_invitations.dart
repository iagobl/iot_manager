import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class GetPendingInvitations {
  GetPendingInvitations(this.repository);

  final DevicesRepository repository;

  Future<List<Map<String, dynamic>>> call() {
    return repository.getPendingInvitations();
  }
}
