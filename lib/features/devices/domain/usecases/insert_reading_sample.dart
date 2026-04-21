import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class InsertReadingSample {
  InsertReadingSample(this.repository);

  final DevicesRepository repository;

  Future<void> call({
    required String deviceId,
    required DateTime timestamp,
    required double powerW,
    required double voltageV,
    required double energyWh,
  }) {
    return repository.insertReadingSample(
      deviceId: deviceId,
      timestamp: timestamp,
      powerW: powerW,
      voltageV: voltageV,
      energyWh: energyWh,
    );
  }
}
