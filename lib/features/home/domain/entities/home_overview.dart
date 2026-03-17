import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:iot_manager/features/home/domain/entities/home_summary.dart';

class HomeOverview {

  const HomeOverview({
    required this.firstName,
    required this.homes,
    required this.devices,
  });
  final String firstName;
  final List<HomeSummary> homes;
  final List<DeviceItem> devices;

  int get totalHomes => homes.length;
  int get totalDevices => devices.length;
  int get activeDevices => devices.where((device) => device.isActive).length;

  double get totalTodayWh => devices.fold<double>(0,
        (sum, device) => sum + device.energyTodayWh,
  );
}
