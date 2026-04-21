import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class RejectInvitation {
  RejectInvitation(this.repository);

  final DevicesRepository repository;

  Future<void> call(String shareId) {
    return repository.rejectInvitation(shareId);
  }
}
