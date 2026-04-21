import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/domain/repositories/device_live_state_repository.dart';

class DeviceLiveStateRepositoryImpl implements DeviceLiveStateRepository {
  DeviceLiveStateRepositoryImpl(this.remoteDatasource);

  final DevicesRemoteDatasource remoteDatasource;

  @override
  Future<bool> isDeviceActive(dynamic device) async {
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
