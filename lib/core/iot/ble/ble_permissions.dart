import 'package:iot_manager/core/constants/iot_strings.dart';
import 'package:permission_handler/permission_handler.dart';

class BlePermissions {
  static Future<void> ensure() async {
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();

    final scanOk = scan.isGranted;
    final connectOk = connect.isGranted;
    final locationOk = location.isGranted;

    if (scanOk && connectOk && locationOk) {
      return;
    }

    final blocked = scan.isPermanentlyDenied ||
        connect.isPermanentlyDenied ||
        location.isPermanentlyDenied;

    if (blocked) {
      throw Exception(IoTStrings.blockPermissions);
    }

    throw Exception(IoTStrings.permissionsError,);
  }
}