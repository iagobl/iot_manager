import 'package:iot_manager/core/constants/iot_strings.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiInfoService {
  final NetworkInfo info = NetworkInfo();

  Future<String?> getCurrentSsid() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      throw const ValidationAppException(IoTStrings.permissionWiFi);
    }

    final ssid = await info.getWifiName();
    if (ssid == null) return null;
    return ssid.replaceAll('"', '').trim();
  }

  Future<String?> getWifiIp() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      throw const ValidationAppException(IoTStrings.permissionLocation);
    }
    return info.getWifiIP();
  }

  Future<String?> getSubnetPrefix24() async {
    final ip = await getWifiIp();
    if (ip == null) return null;

    final parts = ip.split('.');
    if (parts.length != 4) {
      throw const ValidationAppException(IoTStrings.notValidIP,);
    }

    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }
}