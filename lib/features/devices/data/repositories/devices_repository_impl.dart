import 'dart:convert';

import 'package:http/http.dart' as http;
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

  Future<bool> isDeviceActive(device) async {
    try {
      final response = await http.post(
        Uri.parse('http://${device.identifier}/rpc/Switch.GetStatus'),
        body: jsonEncode({'id': 0}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['output'] == true;
      }
    } catch (_) {}

    return false;
  }
}