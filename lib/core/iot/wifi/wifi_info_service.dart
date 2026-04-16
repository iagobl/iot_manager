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
    return subnetPrefixFromIp(ip);
  }

  Future<List<String>> getCandidateSubnetPrefixes24({
    bool includeHotspotFallbacks = true,
  }) async {
    final prefixes = <String>[];

    final currentPrefix = await getSubnetPrefix24();
    if (currentPrefix != null) {
      prefixes.add(currentPrefix);
    }

    if (includeHotspotFallbacks) {
      for (final prefix in commonHotspotPrefixes24) {
        if (!prefixes.contains(prefix)) {
          prefixes.add(prefix);
        }
      }
    }

    return prefixes;
  }

  String? subnetPrefixFromIp(String? ip) {
    if (ip == null || ip.trim().isEmpty) return null;

    final parts = ip.trim().split('.');
    if (parts.length != 4) {
      throw const ValidationAppException(IoTStrings.notValidIP);
    }

    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) {
        throw const ValidationAppException(IoTStrings.notValidIP);
      }
    }

    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  static const List<String> commonHotspotPrefixes24 = <String>[
    '192.168.43',
    '192.168.232',
    '172.20.10',
    '192.168.137',
  ];
}