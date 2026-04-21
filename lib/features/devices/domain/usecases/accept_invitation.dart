import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class AcceptInvitation {
  AcceptInvitation(this.repository);

  final DevicesRepository repository;

  Future<void> call(String shareId) {
    return repository.acceptInvitation(shareId);
  }
}
