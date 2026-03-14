import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/device_item.dart';
import '../../domain/repositories/devices_repository.dart';
import '../datasources/devices_remote_datasource.dart';

class DevicesRepositoryImpl implements DevicesRepository {
  final DevicesRemoteDatasource remoteDatasource;

  DevicesRepositoryImpl(this.remoteDatasource);

  @override
  Future<List<DeviceItem>> getUserDevices() async {
    try {
      final raw = await remoteDatasource.getUserDevices();
      return raw
          .cast<Map<String, dynamic>>()
          .map(DeviceItem.fromMap)
          .toList();
    } catch (e) {
      throw ErrorMapper.mapFailure(e);
    }
  }
}
