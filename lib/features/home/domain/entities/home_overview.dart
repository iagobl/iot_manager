import '../../../devices/domain/entities/device_item.dart';
import 'home_summary.dart';

class HomeOverview {
  final String firstName;
  final List<HomeSummary> homes;
  final List<DeviceItem> devices;

  const HomeOverview({
    required this.firstName,
    required this.homes,
    required this.devices,
  });

  int get totalHomes => homes.length;
  int get totalDevices => devices.length;
  int get activeDevices => devices.where((device) => device.isActive).length;

  double get totalTodayWh => devices.fold<double>(0,
        (sum, device) => sum + device.energyTodayWh,
  );
}
