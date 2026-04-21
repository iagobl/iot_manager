import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class FetchReadingsRange {
  FetchReadingsRange(this.repository);

  final DevicesRepository repository;

  Future<List<Map<String, dynamic>>> call({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    int limit = 10000,
  }) {
    return repository.fetchReadingsRange(
      deviceId: deviceId,
      from: from,
      to: to,
      limit: limit,
    );
  }
}
