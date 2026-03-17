import 'package:iot_manager/core/error/error_mapper.dart';

import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:iot_manager/features/devices/domain/repositories/devices_repository.dart';

class DevicesRepositoryImpl implements DevicesRepository {

  DevicesRepositoryImpl(this.remoteDatasource);
  final DevicesRemoteDatasource remoteDatasource;

  @override
  Future<List<DeviceItem>> getUserDevices() async {
    try {
      return await remoteDatasource.getUserDevices();
    } catch (error) {
      throw ErrorMapper.mapFailure(error);
    }
  }
}