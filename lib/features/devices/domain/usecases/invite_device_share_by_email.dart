import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class InviteDeviceShareByEmail {
  InviteDeviceShareByEmail(this.repository);

  final DevicesRepository repository;

  Future<void> call({required String deviceId, required String email}) {
    return repository.inviteDeviceShareByEmail(deviceId: deviceId, email: email);
  }
}
