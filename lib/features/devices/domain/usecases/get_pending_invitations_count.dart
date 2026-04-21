import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class GetPendingInvitationsCount {
  GetPendingInvitationsCount(this.repository);

  final DevicesRepository repository;

  Future<int> call() {
    return repository.getPendingInvitationsCount();
  }
}
